#!/usr/bin/env ruby
# Only configuration is changed; credentials stay in the existing environment.
require "json"
require "optparse"
require "fileutils"
require "securerandom"

options = {}
OptionParser.new do |parser|
  parser.banner = "ruby scripts/setup_pilot.rb [--model MODEL] [--all]"
  parser.on("--model MODEL", "Gemini model ID") { |v| options[:model] = v }
  parser.on("--all", "Enable ten sources, three pages each") { options[:all] = true }
end.parse!
root = File.expand_path("..", __dir__)
path = File.join(root, "config/settings.json")
config = JSON.parse(File.read(File.join(root, "config/settings.pilot.json"), encoding: "UTF-8"))
existing = File.file?(path) ? JSON.parse(File.read(path, encoding: "UTF-8")) : {}
model = options[:model] || (existing.dig("llm", "model") if existing.dig("llm", "provider") == "gemini")
abort "Gemini modelini belirtin: --model MODEL_ID (API anahtarı değil)." if model.to_s.empty? || model == "SET_MODEL_ID"
abort "Geçersiz model kimliği." unless model.match?(/\A[a-zA-Z0-9._-]+\z/)
config["llm"]["model"] = model
if options[:all]
  config["profiles"].each do |profile|
    profile["enabled"] = true
    profile["max_pages"] = 3
    profile["max_depth"] = 1
  end
end
if File.file?(path)
  backup = "#{path}.backup-#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}-#{SecureRandom.hex(3)}"
  FileUtils.cp(path, backup)
  puts "Önceki ayarlar yedeklendi: #{File.basename(backup)}"
end
temp = "#{path}.tmp-#{SecureRandom.hex(6)}"
begin
  File.write(temp, JSON.pretty_generate(config) + "\n", mode: "wx", encoding: "UTF-8")
  File.rename(temp, path)
ensure
  File.delete(temp) if File.exist?(temp)
end
puts "Pilot hazır: #{config['profiles'].count { |p| p['enabled'] }} aktif kaynak; ilk tarama bildirimi açık."
puts "SerpAPI ve sosyal medya kapalı. .env değiştirilmedi. Günlük LLM sınırı: 40 çağrı."
