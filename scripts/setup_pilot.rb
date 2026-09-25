#!/usr/bin/env ruby
# Only configuration is changed; credentials stay in the existing environment.
require "json"
require "optparse"
require "fileutils"
require "securerandom"

options = {}
OptionParser.new do |parser|
  parser.banner = "ruby scripts/setup_pilot.rb [--provider gemini|mistral] [--model MODEL] [--sources 50] [--interval SECONDS] [--daily-calls N] [--all]"
  parser.on("--provider PROVIDER", %w[gemini mistral]) { |v| options[:provider] = v }
  parser.on("--model MODEL", "Model ID") { |v| options[:model] = v }
  parser.on("--sources N", Integer) { |v| options[:sources] = v }
  parser.on("--interval N", Integer) { |v| options[:interval] = v }
  parser.on("--daily-calls N", Integer) { |v| options[:daily_calls] = v }
  parser.on("--pages N", Integer) { |v| options[:pages] = v }
  parser.on("--depth N", Integer) { |v| options[:depth] = v }
  parser.on("--[no-]google", "Daily Google discovery via SerpAPI") { |v| options[:google] = v }
  parser.on("--all", "Enable ten sources, three pages each") { options[:all] = true }
end.parse!
root = File.expand_path("..", __dir__)
path = File.join(root, "config/settings.json")
config = JSON.parse(File.read(File.join(root, "config/settings.pilot.json"), encoding: "UTF-8"))
existing = File.file?(path) ? JSON.parse(File.read(path, encoding: "UTF-8")) : {}
provider = options[:provider] || existing.dig("llm", "provider") || "gemini"
model = options[:model] || (existing.dig("llm", "model") if existing.dig("llm", "provider") == provider)
model ||= "mistral-small-2603" if provider == "mistral"
abort "Modeli belirtin: --model MODEL_ID (API anahtarı değil)." if model.to_s.empty? || model == "SET_MODEL_ID"
abort "Geçersiz model kimliği." unless model.match?(/\A[a-zA-Z0-9._-]+\z/)
abort "--sources yalnızca 50 olabilir." if options[:sources] && options[:sources] != 50
abort "--interval 60..604800 olmalı." if options[:interval] && !(60..604800).cover?(options[:interval])
abort "--daily-calls 1..100000 olmalı." if options[:daily_calls] && !(1..100000).cover?(options[:daily_calls])
abort "--pages 1..500 olmalı." if options[:pages] && !(1..500).cover?(options[:pages])
abort "--depth 0..5 olmalı." if options[:depth] && !(0..5).cover?(options[:depth])
config["llm"]["provider"] = provider
config["llm"]["api_key_env"] = provider == "mistral" ? "MISTRAL_API_KEY" : "GEMINI_API_KEY"
config["llm"]["model"] = model
if options[:sources] == 50
  sources = JSON.parse(File.read(File.join(root, "arastirma/erp_50_kaynak.json"), encoding: "UTF-8")).fetch("sources")
  abort "50 benzersiz kaynak gerekli." unless sources.size == 50 && sources.map { |s| s["id"] }.uniq.size == 50
  base = config["profiles"].first
  config["profiles"] = sources.map do |source|
    profile = Marshal.load(Marshal.dump(base))
    profile.merge!("id" => "erp50_#{source.fetch('id').downcase}", "enabled" => true,
      "seed_urls" => [source.fetch("url")], "allowed_domains" => [source.fetch("host").sub(/\Awww\./, "")],
      "interval_seconds" => 1800, "max_pages" => 12, "max_depth" => 2)
    profile["description"] = base["description"].sub(/ MAKTEK Avrasya\z/, "") + " Kaynak: #{source.fetch('name')}."
    profile
  end
  config["llm"]["min_interval_seconds"] = 60
  config["llm"]["chunk_chars"] = 6000
  config["llm"]["max_chunks"] = 12
  config["llm"]["max_output_tokens"] = 4096
elsif options[:all]
  config["profiles"].each do |profile|
    profile["enabled"] = true
    profile["max_pages"] = 3
    profile["max_depth"] = 1
  end
end
config["profiles"].each { |p| p["interval_seconds"] = options[:interval] } if options[:interval]
config["profiles"].each { |p| p["max_pages"] = options[:pages] } if options[:pages]
config["profiles"].each { |p| p["max_depth"] = options[:depth] } if options[:depth]
google_enabled = options.fetch(:google) { existing.fetch("profiles", []).any? { |p| p["id"].start_with?("google_") && p["enabled"] } }
if google_enabled
  year = Time.now.year
  queries = [
    %(Türkiye (fuar OR zirve OR kongre) (sanayi OR üretim) #{year}),
    %(Türkiye ("B2B" OR "iş ortaklığı" OR "tedarikçi günü") #{year}),
    %(Türkiye ("yapay zeka" OR yazılım OR "siber güvenlik") (buluşma OR konferans OR zirve) #{year}),
    %(site:org.tr ("etkinlik takvimi" OR "iş forumu" OR "sanayici buluşması") #{year}),
    %(Türkiye (lojistik OR ambalaj OR tekstil OR mobilya) (fuar OR zirve) #{year}),
    %(Türkiye (tarım OR gıda OR enerji OR sağlık) (fuar OR kongre) #{year}),
    %(Türkiye (girişimcilik OR yatırımcı OR networking) (etkinlik OR buluşma) #{year}),
    %(Türkiye (TEKNOFEST OR "üniversite sanayi" OR mühendislik) (festival OR buluşma OR kongre) #{year})
  ]
  base = config["profiles"].first
  queries.each_with_index do |query, index|
    p = Marshal.load(Marshal.dump(base))
    p.merge!("id" => "google_#{index + 1}", "enabled" => true, "seed_urls" => [], "allowed_domains" => [],
      "search_queries" => [query], "search_interval_seconds" => 86400, "interval_seconds" => 1800,
      "discover_new_domains" => true, "max_pages" => 10, "max_depth" => 1)
    p["description"] = base["description"].sub(/ Kaynak:.*\z/, "").sub(/ MAKTEK Avrasya\z/, "")
    config["profiles"] << p
  end
end
config["llm"]["max_calls_per_day"] = options[:daily_calls] || existing.dig("llm", "max_calls_per_day") || 40
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
puts "Sağlayıcı: #{provider}, model: #{model}. Google: #{google_enabled ? '8 günlük sorgu, SERPAPI_API_KEY gerekli' : 'kapalı'}. Sosyal medya kapalı. .env değiştirilmedi."
puts "Günlük LLM sınırı: #{config['llm']['max_calls_per_day']} çağrı (parasal harcama limiti değildir)."
puts "50 kaynak için ilk analiz bütçe/kota nedeniyle birden fazla güne yayılabilir; 30 dakika tamamlanma garantisi değildir." if options[:sources] == 50
