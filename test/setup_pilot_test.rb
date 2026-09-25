require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require_relative "../lib/radar/http"
require_relative "../lib/radar/config"

class SetupPilotTest < Minitest::Test
  def test_setup_requires_model_preserves_secrets_and_can_expand
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(["#{root}/scripts", "#{root}/config", "#{root}/arastirma"])
      FileUtils.cp(File.expand_path("../arastirma/erp_50_kaynak.json", __dir__), "#{root}/arastirma/")
      FileUtils.cp(File.expand_path("../scripts/setup_pilot.rb", __dir__), "#{root}/scripts/")
      FileUtils.cp(File.expand_path("../config/settings.pilot.json", __dir__), "#{root}/config/")
      File.write("#{root}/.env", "PRIVATE_SENTINEL=unchanged\n")
      script = "#{root}/scripts/setup_pilot.rb"
      _, _, status = Open3.capture3(RbConfig.ruby, script)
      refute status.success?
      refute File.exist?("#{root}/config/settings.json")
      _, _, status = Open3.capture3(RbConfig.ruby, script, "--model", "test-model")
      assert status.success?
      first = File.read("#{root}/config/settings.json")
      config = JSON.parse(first)
      assert_equal 3, config["profiles"].count { |p| p["enabled"] }
      assert config["profiles"].all? { |p| p["search_queries"].empty? && p["notify_initial"] }
      _, _, status = Open3.capture3(RbConfig.ruby, script, "--all")
      assert status.success?
      config = JSON.parse(File.read("#{root}/config/settings.json"))
      assert_equal "test-model", config.dig("llm", "model")
      assert_equal 10, config["profiles"].count { |p| p["enabled"] && p["max_pages"] == 3 }
      backup = Dir.children("#{root}/config").find { |name| name.start_with?("settings.json.backup-") }
      refute_nil backup
      assert_equal first, File.read("#{root}/config/#{backup}")
      assert_equal "PRIVATE_SENTINEL=unchanged\n", File.read("#{root}/.env")
      _, _, status = Open3.capture3(RbConfig.ruby, script, "--provider", "mistral", "--sources", "50", "--daily-calls", "200")
      assert status.success?
      config = JSON.parse(File.read("#{root}/config/settings.json"))
      assert_equal "mistral", config.dig("llm", "provider")
      assert_equal "MISTRAL_API_KEY", config.dig("llm", "api_key_env")
      assert_equal "mistral-small-2603", config.dig("llm", "model")
      assert_equal 50, config["profiles"].size
      assert_equal 50, Radar::Config.new("#{root}/config/settings.json").profiles.size
      assert config["profiles"].all? { |p| p["enabled"] && p["interval_seconds"] == 1800 && p["search_queries"].empty? }
      assert_equal 200, config.dig("llm", "max_calls_per_day")
      assert_equal 60, config.dig("llm", "min_interval_seconds")
      assert_equal 4096, config.dig("llm", "max_output_tokens")
      assert config["profiles"].all? { |p| p["max_pages"] == 12 && p["max_depth"] == 2 }
      prior = File.read("#{root}/config/settings.json")
      _, _, status = Open3.capture3(RbConfig.ruby, script, "--interval", "0")
      refute status.success?
      assert_equal prior, File.read("#{root}/config/settings.json")
      _, _, status = Open3.capture3(RbConfig.ruby, script, "--sources", "50")
      assert status.success?
      assert_equal "mistral", JSON.parse(File.read("#{root}/config/settings.json")).dig("llm", "provider")
      _, _, status = Open3.capture3(RbConfig.ruby, script, "--sources", "50", "--google")
      assert status.success?
      google = Radar::Config.new("#{root}/config/settings.json").profiles.select { |p| p["id"].start_with?("google_") }
      assert_equal 8, google.size
      assert google.all? { |p| p["search_interval_seconds"] == 86400 && p["interval_seconds"] == 1800 && p["discover_new_domains"] }
      _, _, status = Open3.capture3(RbConfig.ruby, script, "--sources", "50")
      assert status.success?
      assert_equal 58, Radar::Config.new("#{root}/config/settings.json").profiles.size
      _, _, status = Open3.capture3(RbConfig.ruby, script, "--sources", "50", "--no-google")
      assert status.success?
      assert_equal 50, Radar::Config.new("#{root}/config/settings.json").profiles.size
    end
  end
end
