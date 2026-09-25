require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "json"
require "open3"
require "rbconfig"

class SetupPilotTest < Minitest::Test
  def test_setup_requires_model_preserves_secrets_and_can_expand
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(["#{root}/scripts", "#{root}/config"])
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
    end
  end
end
