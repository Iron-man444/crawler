module Radar
  class Runner
    def initialize(config, store, http: HTTP.new(user_agent: config["user_agent"]), logger: Logger.new($stdout))
      @config, @store, @http, @log = config, store, http, logger
      @analyzer = Analyzer.new(config["llm"], http: http, cache: store, budget: lambda {
        provider_host = config["llm"]["provider"] == "gemini" ? "generativelanguage.googleapis.com" : "api.mistral.ai"
        store.reserve_host(provider_host, config["llm"].fetch("min_interval_seconds", config["host_delay_seconds"]))
        store.budget!(config["llm"]["provider"], config["llm"]["max_calls_per_day"])
      })
    end

    def tick
      @config.profiles.each do |profile|
        @store.schedule(profile) do |initial|
          payload = { "cycle" => SecureRandom.uuid, "depth" => 0, "initial" => initial }
          profile["seed_urls"].each { |url| @store.enqueue_crawl(profile, URL.canonical(url), payload) }
          profile["search_queries"].each do |q|
            @store.enqueue("search", profile["id"], payload.merge("query" => q), key: Radar.digest(["search", profile["id"], q]), refresh: true)
          end
          # Keep room for new links instead of filling every cycle with old detail pages.
          @store.known_urls(profile).first(profile["max_pages"] / 2).each do |url|
            @store.enqueue_crawl(profile, url, payload.merge("depth" => profile["max_depth"]))
          end
        end
      end
      @config["max_jobs_per_tick"].times do
        job = @store.claim_job
        break unless job
        profile = @config.profile(job["profile_id"])
        if profile.nil?
          @store.fail_job(job, WorkError.new("profile_disabled", permanent: true))
          next
        end
        begin
          case job["kind"]
          when "search" then search(profile, job["payload"])
          when "crawl" then crawl(profile, job["payload"])
          when "analyze" then analyze(profile, job["payload"])
          else raise WorkError.new("unknown_job", permanent: true)
          end
          @store.done(job["id"])
          @log.info("job=#{job['id']} kind=#{job['kind']} completed")
        rescue WorkError => e
          provider_host = if job["kind"] == "search"
                            "serpapi.com"
                          elsif job["kind"] == "analyze"
                            @config["llm"]["provider"] == "gemini" ? "generativelanguage.googleapis.com" : "api.mistral.ai"
                          end
          if provider_host
            @store.cooldown_host(provider_host, e.delay) if e.code == "http_429"
            @store.block_host(provider_host, e.code) if %w[http_401 http_402 http_403].include?(e.code)
          end
          @store.fail_job(job, e)
          @log.warn("job=#{job['id']} kind=#{job['kind']} status=#{e.code}")
        end
      end
    end

    def search(profile, payload)
      @store.reserve_host("serpapi.com", @config["host_delay_seconds"])
      @store.budget!("serpapi", 50)
      params = URI.encode_www_form(engine: "google", q: payload["query"], api_key: ENV.fetch("SERPAPI_API_KEY"), hl: "tr", gl: "tr", num: 10)
      response = HTTP.check!(@http.request(:get, "https://serpapi.com/search.json?#{params}", headers: { "Accept" => "application/json" }))
      data = JSON.parse(response.body)
      raise WorkError.new("search_provider_error") if data["error"]
      results = data.fetch("organic_results", [])
      raise WorkError.new("search_invalid_response") unless results.is_a?(Array)
      results.first(10).each do |result|
        begin
          url = URL.canonical(result.fetch("link"))
        rescue WorkError, KeyError
          next
        end
        allowed = URL.allowed?(url, profile["allowed_domains"])
        @store.discover(profile["id"], result.merge("link" => url), payload["query"], allowed)
        @store.enqueue_crawl(profile, url, payload.merge("depth" => 0)) if allowed
      end
    rescue JSON::ParserError, TypeError, NoMethodError
      raise WorkError.new("search_invalid_response")
    end

    def page_request(url, profile, headers = {})
      @http.request(:get, url, headers: headers, domains: profile["allowed_domains"], follow_redirects: false, before_request: lambda { |host|
        @store.reserve_host(host, @config["host_delay_seconds"])
      })
    end

    def check_robots(url, profile)
      uri = URI(url)
      row = @store.host(uri.host)
      if row && row["robots_until"] && row["robots_until"] > Time.now
        body = row["robots"]
      else
        response = page_request("#{uri.scheme}://#{uri.host}/robots.txt", profile)
        raise WorkError.new("robots_redirect_requires_review", permanent: true) if (300..399).cover?(response.status)
        if response.status == 404
          body = ""
        else
          handle_source_response(response)
          body = response.body
        end
        @store.robots(uri.host, body)
      end
      raise WorkError.new("robots_disallowed", permanent: true) unless Robots.new(body).allowed?(url)
    end

    def handle_source_response(response)
      HTTP.check!(response)
    rescue WorkError => e
      host = URI(response.url).host
      @store.block_host(host, e.code) if [401, 403].include?(response.status)
      @store.cooldown_host(host, e.delay) if response.status == 429
      raise
    end

    def crawl(profile, payload)
      url = payload.fetch("url")
      raise WorkError.new("domain_not_allowed", permanent: true) unless URL.allowed?(url, profile["allowed_domains"])
      check_robots(url, profile)
      key = Radar.digest([profile["id"], url])
      prior = @store.document(key)
      signature = @analyzer.signature(profile)
      headers = {}
      headers["If-None-Match"] = prior["etag"] if prior && prior["etag"]
      headers["If-Modified-Since"] = prior["modified"] if prior && prior["modified"]
      response = page_request(url, profile, headers)
      if [301, 302, 303, 307, 308].include?(response.status)
        target = URL.canonical(response.headers.fetch("location", ""), url)
        redirects = payload.fetch("redirects", 0)
        raise WorkError.new("redirect_limit", permanent: true) if redirects >= 5
        raise WorkError.new("domain_not_allowed", permanent: true) unless URL.allowed?(target, profile["allowed_domains"])
        raise WorkError.new("https_downgrade", permanent: true) if URI(url).scheme == "https" && URI(target).scheme != "https"
        @store.enqueue_crawl(profile, target, payload.merge("redirects" => redirects + 1))
        return
      end
      if response.status == 304 && prior
        content = prior["content"]
        response_headers = { "etag" => prior["etag"], "last-modified" => prior["modified"] }
      else
        handle_source_response(response)
        content = Extractor.call(response.body, response.url, response.headers.fetch("content-type", ""))
        response_headers = response.headers
      end
      hash = Radar.digest(content["text"])
      silent = (payload["initial"] && !profile["notify_initial"]) ||
               (prior && prior["signature"] != signature && !profile.fetch("notify_on_reanalysis", false))
      @store.transaction do
        @store.save_document(key, profile["id"], url, content, hash, signature, response_headers)
        if !content["text"].empty? && (!prior || prior["hash"] != hash || prior["signature"] != signature)
          @store.enqueue("analyze", profile["id"], { "document_key" => key, "hash" => hash, "signature" => signature, "silent" => !!silent }, key: Radar.digest(["analyze", key, hash, signature]), refresh: true)
        end
        if payload["depth"] < profile["max_depth"]
          content["links"].each do |link|
            next unless URL.allowed?(link, profile["allowed_domains"])
            @store.enqueue_crawl(profile, link, payload.merge("depth" => payload["depth"] + 1))
          end
        end
      end
    rescue WorkError => e
      @store.block_host(URI(url).host, e.code) if e.code == "challenge_page"
      raise
    end

    def analyze(profile, payload)
      doc = @store.document(payload["document_key"])
      return unless doc && doc["hash"] == payload["hash"] && doc["signature"] == payload["signature"]
      # Configuration edits invalidate queued work; a new crawl will enqueue the current signature.
      return unless @analyzer.signature(profile) == payload["signature"]
      items = @analyzer.analyze(doc["content"]["text"], profile, source_tags: doc["content"]["source_tags"])
      @store.apply_items(profile, doc["url"], items, silent: payload["silent"])
    end
  end
end
