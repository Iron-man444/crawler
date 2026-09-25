module Radar
  class Config
    attr_reader :data
    def initialize(path)
      @data = JSON.parse(File.read(path, encoding: "UTF-8"))
      validate!
    end

    def [](key) = @data.fetch(key)
    def profiles = self["profiles"].select { |p| p["enabled"] }
    def profile(id) = profiles.find { |p| p["id"] == id }

    def validate!
      raise "listen yalnızca loopback olabilir" unless %w[127.0.0.1 ::1].include?(self["listen"])
      integer!(self["port"], 1024..65535, "port")
      integer!(self["host_delay_seconds"], 1..3600, "host_delay_seconds")
      integer!(self["max_jobs_per_tick"], 1..1000, "max_jobs_per_tick")
      llm = self["llm"]
      raise "provider gemini veya mistral olmalı" unless %w[gemini mistral].include?(llm["provider"])
      integer!(llm["max_calls_per_day"], 1..100000, "max_calls_per_day")
      integer!(llm["chunk_chars"], 1000..30000, "chunk_chars")
      integer!(llm["max_chunks"], 1..20, "max_chunks")
      integer!(llm["min_interval_seconds"], 1..3600, "min_interval_seconds") if llm.key?("min_interval_seconds")
      integer!(llm["max_output_tokens"], 256..8192, "max_output_tokens") if llm.key?("max_output_tokens")
      raise "profiles dizi olmalı" unless self["profiles"].is_a?(Array)
      ids = self["profiles"].map { |p| p["id"] }
      raise "Profil ID tekrar ediyor" unless ids.uniq == ids
      self["profiles"].each do |p|
        raise "Geçersiz profil ID" unless p["id"].to_s.match?(/\A[a-z0-9_-]+\z/)
        %w[seed_urls search_queries allowed_domains include_words exclude_words include_tags exclude_tags allowed_types excluded_types locations].each do |k|
          raise "#{k} metin dizisi olmalı" unless p[k].is_a?(Array) && p[k].all? { |s| s.is_a?(String) }
        end
        raise "target_ref/description eksik" if p["target_ref"].to_s.empty? || p["description"].to_s.empty?
        raise "match_mode any/all olmalı" unless %w[any all].include?(p["match_mode"])
        integer!(p["interval_seconds"], 60..604800, "interval_seconds")
        integer!(p["max_pages"], 1..500, "max_pages")
        integer!(p["max_depth"], 0..5, "max_depth")
        p["allowed_domains"].each { |d| raise "Geçersiz domain: #{d}" unless d.match?(/\A[a-z0-9.-]+\z/) && d.include?(".") }
        p["seed_urls"].each { |u| raise "Seed izinli domain içinde olmalı" unless URL.allowed?(u, p["allowed_domains"]) }
        %w[enabled notify_initial exclude_past_events].each { |k| raise "#{k} boolean olmalı" unless [true, false].include?(p[k]) }
      end
    end

    def check_secrets!
      raise "Aktif profil yok; önce kaynakları ve profili ayarlayın" if profiles.empty?
      raise "LLM model kimliğini ayarlayın" if self["llm"]["model"].to_s.empty? || self["llm"]["model"] == "SET_MODEL_ID"
      ["DATABASE_URL", self["llm"]["api_key_env"]].each { |key| raise "#{key} eksik" if ENV[key.to_s].to_s.empty? }
      raise "RADAR_API_TOKEN en az 32 karakter olmalı" if ENV["RADAR_API_TOKEN"].to_s.length < 32
      raise "SERPAPI_API_KEY eksik" if profiles.any? { |p| !p["search_queries"].empty? } && ENV["SERPAPI_API_KEY"].to_s.empty?
    end

    private

    def integer!(value, range, name)
      raise "#{name}: #{range} aralığında tamsayı olmalı" unless value.is_a?(Integer) && range.cover?(value)
    end
  end
end
