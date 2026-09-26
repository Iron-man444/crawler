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
          # Keep room for new links instead of filling every cycle with old detail pages.
          revisit_limit = profile["max_pages"] / (profile["seed_urls"].empty? ? 2 : 4)
          @store.known_urls(profile).first(revisit_limit).each do |url|
            @store.enqueue_crawl(profile, url, payload.merge("depth" => profile["max_depth"]))
          end
        end
        unless profile["search_queries"].empty?
          @store.schedule(profile, key: "search:#{profile['id']}", interval: profile.fetch("search_interval_seconds", 86400)) do |initial|
            profile["search_queries"].each do |q|
              # Each query has its own bounded crawl budget; slow queries cannot fill another's slots.
              payload = { "cycle" => SecureRandom.uuid, "depth" => 0, "initial" => initial, "query" => q }
              @store.enqueue("search", profile["id"], payload, key: Radar.digest(["search", profile["id"], q]), refresh: true)
            end
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
          @log.warn("job=#{job['id']} kind=#{job['kind']} status=#{e.code}") unless %w[host_wait daily_budget].include?(e.code)
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
        allowed = URL.allowed?(url, profile["allowed_domains"]) || profile.fetch("discover_new_domains", false)
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
        robots_url = row && row["robots_fetch_url"] || "#{uri.scheme}://#{uri.host}/robots.txt"
        response = page_request(robots_url, profile)
        if [301, 302, 303, 307, 308].include?(response.status)
          target = URL.canonical(response.headers.fetch("location", ""), robots_url)
          hops = row && row["robots_redirects"] || 0
          raise WorkError.new("robots_redirect_requires_review", permanent: true) unless URL.allowed?(target, profile["allowed_domains"])
          raise WorkError.new("https_downgrade", permanent: true) if URI(robots_url).scheme == "https" && URI(target).scheme != "https"
          raise WorkError.new("robots_redirect_limit", permanent: true) if hops >= 5
          @store.robots_redirect(uri.host, target, hops + 1)
          raise WorkError.new("host_wait", delay: @config["host_delay_seconds"])
        end
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
      access_profile = profile
      if !URL.allowed?(url, profile["allowed_domains"]) && profile.fetch("discover_new_domains", false)
        # Only URLs actually returned by discovery may open a new domain. HTTP still validates/pins public IPs.
        origin = payload.fetch("discovery_origin", url)
        if @store.discovery_allowed?(profile["id"], origin)
          access_profile = profile.merge("allowed_domains" => [URI(origin).host.sub(/\Awww\./, "")])
          payload = payload.merge("discovery_origin" => origin)
        end
      end
      raise WorkError.new("domain_not_allowed", permanent: true) unless URL.allowed?(url, access_profile["allowed_domains"])
      check_robots(url, access_profile)
      key = Radar.digest([profile["id"], url])
      prior = @store.document(key)
      signature = @analyzer.signature(profile)
      headers = {}
      if prior && prior["content"]["extractor_version"] == Extractor::VERSION
        headers["If-None-Match"] = prior["etag"] if prior["etag"]
        headers["If-Modified-Since"] = prior["modified"] if prior["modified"]
      end
      response = page_request(url, access_profile, headers)
      if [301, 302, 303, 307, 308].include?(response.status)
        target = URL.canonical(response.headers.fetch("location", ""), url)
        redirects = payload.fetch("redirects", 0)
        raise WorkError.new("redirect_limit", permanent: true) if redirects >= 5
        raise WorkError.new("domain_not_allowed", permanent: true) unless URL.allowed?(target, access_profile["allowed_domains"])
        raise WorkError.new("https_downgrade", permanent: true) if URI(url).scheme == "https" && URI(target).scheme != "https"
        if profile.fetch("discover_new_domains", false)
          @store.discover(profile["id"], { "link" => target }, "redirect:#{url}", true)
        end
        @store.enqueue_crawl(profile, target, payload.merge("redirects" => redirects + 1), redirect_from: url)
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
          links = content["links"].select { |link| URL.allowed?(link, access_profile["allowed_domains"]) }
          # Leave room for detail links from list pages at the next depth.
          limit = [profile["max_pages"] / (profile["max_depth"] - payload["depth"] + 1), 1].max
          @store.prioritize_unread(profile, links).first(limit).each do |link|
            @store.discover(profile["id"], { "link" => link }, "link:#{url}", true) if profile.fetch("discover_new_domains", false)
            @store.enqueue_crawl(profile, link, payload.merge("depth" => payload["depth"] + 1, "redirects" => 0))
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
      items = @analyzer.analyze(doc["content"]["text"], profile, source_tags: doc["content"]["source_tags"], source_url: doc["url"])
      @store.transaction do
        @store.apply_items(profile, doc["url"], items, silent: payload["silent"])
        @store.mark_analyzed(payload["document_key"], items.size)
      end
    end
  end
end
