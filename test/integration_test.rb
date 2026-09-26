require_relative "test_helper"

class IntegrationTest < Minitest::Test
  def setup
    skip "RADAR_TEST_DATABASE_URL ile yalnızca test PostgreSQL'ini belirtin" unless ENV["RADAR_TEST_DATABASE_URL"]
    @store = Radar::Store.new(ENV.fetch("RADAR_TEST_DATABASE_URL"))
    @store.query("SET client_min_messages TO warning")
    @schema = "radar_test_#{SecureRandom.hex(8)}"
    @store.query("CREATE SCHEMA #{@schema}")
    @store.query("SET search_path TO #{@schema}")
    @store.migrate
  end

  def teardown
    if @store
      @store.query("SET search_path TO public")
      @store.query("DROP SCHEMA #{@schema} CASCADE")
      @store.close
    end
  end

  def test_nested_transaction_rolls_back_all_writes
    assert_raises(RuntimeError) do
      @store.transaction do
        @store.enqueue("crawl", "test", {}, key: "first")
        @store.transaction { @store.enqueue("crawl", "test", {}, key: "second") }
        raise "abort"
      end
    end
    assert_empty @store.query("SELECT * FROM radar_jobs")
  end

  def test_baseline_dedup_updates_and_claim_ack
    @store.apply_items(profile, "https://example.org/a", [item], silent: true)
    assert_nil @store.claim_delivery
    @store.apply_items(profile, "https://example.org/a", [item], silent: false)
    assert_nil @store.claim_delivery
    changed = item.merge("date" => "2030-10-16")
    @store.apply_items(profile, "https://example.org/a", [changed], silent: false)
    job = @store.claim_delivery
    assert_equal "updated", job.dig("payload", "kind")
    refute @store.delivery_action(job["delivery_id"], "ack", { "claim_token" => "wrong", "message_id" => "42" })
    assert @store.delivery_action(job["delivery_id"], "renew", job)
    assert @store.delivery_action(job["delivery_id"], "ack", job.merge("message_id" => "42"))
    assert @store.delivery_action(job["delivery_id"], "ack", job.merge("message_id" => "42"))
    assert_nil @store.claim_delivery
  end

  def test_newly_relevant_record_is_not_suppressed_by_unchanged_fingerprint
    @store.apply_items(profile, "https://example.org/a", [item.merge("relevance" => "uncertain")], silent: false)
    assert_nil @store.claim_delivery
    @store.apply_items(profile, "https://example.org/a", [item], silent: false)
    job = @store.claim_delivery
    assert_equal "new", job.dig("payload", "kind")
    @store.apply_items(profile, "https://example.org/a", [item], silent: false)
    assert_equal 1, @store.query("SELECT count(*)::integer AS n FROM radar_outbox").first["n"]
  end

  def test_reanalysis_notifications_are_opt_in_even_on_unchanged_page
    [false, true].each do |notify|
      p = profile.merge("id" => "reanalysis_#{notify}", "notify_on_reanalysis" => notify)
      url = p["seed_urls"].first
      key = Radar.digest([p["id"], url])
      content = { "text" => "Existing event content", "links" => [], "source_tags" => [] }
      @store.save_document(key, p["id"], url, content, Radar.digest(content["text"]), "old-policy", {})
      http = FakeHTTP.new { |_, request_url, _| response(request_url.end_with?("robots.txt") ? 404 : 304, "") }
      runner = Radar::Runner.new(config, @store, http: http)
      @store.query("INSERT INTO radar_hosts(host) VALUES($1) ON CONFLICT DO NOTHING", [URI(url).host])
      @store.robots(URI(url).host, "")
      @store.query("UPDATE radar_hosts SET next_at=now()-interval '1 second'")
      runner.crawl(p, { "url" => url, "depth" => p["max_depth"], "initial" => false })
      payload = @store.query("SELECT payload FROM radar_jobs WHERE profile_id=$1 AND kind='analyze'", [p["id"]]).first.fetch("payload")
      assert_equal !notify, payload["silent"]
    end
  end

  def test_expired_delivery_is_held_and_transient_is_retried
    @store.apply_items(profile, "https://example.org/a", [item], silent: false)
    job = @store.claim_delivery
    assert @store.delivery_action(job["delivery_id"], "fail", job.merge("type" => "transient", "retry_after" => 120))
    assert_nil @store.claim_delivery
    @store.query("UPDATE radar_outbox SET available_at=now()-interval '1 second'")
    job2 = @store.claim_delivery
    refute_equal job["claim_token"], job2["claim_token"]
    @store.query("UPDATE radar_outbox SET lease_until=now()-interval '1 second'")
    assert_nil @store.claim_delivery
    assert_equal "unknown_delivery", @store.query("SELECT state FROM radar_outbox").first["state"]
    @store.resolve_delivery(job2["delivery_id"], "retry")
    assert @store.claim_delivery
  end

  def test_queue_survives_connection_restart_and_worker_lease
    @store.enqueue("crawl", profile["id"], { "url" => "https://example.org" }, key: "unique")
    @store.enqueue("crawl", profile["id"], {}, key: "unique")
    job = @store.claim_job
    assert_nil @store.claim_job
    @store.query("UPDATE radar_jobs SET lease_until=now()-interval '1 second'")
    assert_equal job["id"], @store.claim_job["id"]
    another = Radar::Store.new(ENV.fetch("RADAR_TEST_DATABASE_URL"))
    another.query("SET search_path TO #{@schema}")
    assert_equal 1, another.query("SELECT count(*)::integer AS n FROM radar_jobs").first["n"]
  ensure
    another&.close
  end

  def test_daily_budget_host_cooldown_and_review
    @store.budget!("test", 1)
    assert_equal "daily_budget", assert_raises(Radar::WorkError) { @store.budget!("test", 1) }.code
    @store.reserve_host("example.org", 60)
    assert_equal "host_wait", assert_raises(Radar::WorkError) { @store.reserve_host("example.org", 60) }.code
    @store.block_host("example.org", "http_403")
    assert_equal "host_blocked", assert_raises(Radar::WorkError) { @store.reserve_host("example.org", 60) }.code
    @store.enqueue("crawl", profile["id"], {}, key: "review")
    job = @store.claim_job
    @store.fail_job(job, Radar::WorkError.new("http_403", permanent: true))
    assert_equal "http_403", @store.review["jobs"].first["error"]
  end

  def test_entire_crawl_analyze_baseline_new_record_and_cache
    c = config
    p = profile.merge("max_depth" => 0, "search_queries" => [])
    c.data["profiles"] = [p]
    c.data["llm"].merge!("model" => "test", "api_key_env" => "RADAR_TEST_KEY")
    ENV["RADAR_TEST_KEY"] = "fake"
    items = [item.slice(*Radar::Analyzer::FIELDS)]
    http = FakeHTTP.new do |_, url, _|
      if url.include?("generativelanguage")
        response(200, JSON.generate("candidates" => [{ "finishReason" => "STOP", "content" => { "parts" => [{ "text" => JSON.generate("items" => items) }] } }]))
      elsif url.end_with?("robots.txt")
        response(200, "User-agent: *\nAllow: /", {}, url)
      else
        html = "<main>#{items.map { |i| "<p>#{i['title']} #{i['evidence']}</p>" }.join}</main>"
        response(200, html, { "content-type" => "text/html" }, url)
      end
    end
    runner = Radar::Runner.new(c, @store, http: http, logger: Logger.new(StringIO.new))
    run_ready(runner)
    assert_equal 1, @store.query("SELECT count(*)::integer AS n FROM radar_items").first["n"]
    assert_equal 1, @store.sources([p]).first["pages_analyzed"]
    assert_nil @store.claim_delivery
    @store.query("UPDATE radar_schedules SET next_at=now()-interval '1 second'")
    run_ready(runner)
    assert_equal 1, http.calls.count { |_, url, _| url.include?("generativelanguage") }
    items << item.slice(*Radar::Analyzer::FIELDS).merge("title" => "Siber Güvenlik Buluşması", "type" => "partnership")
    @store.query("UPDATE radar_schedules SET next_at=now()-interval '1 second'")
    run_ready(runner)
    notification = @store.claim_delivery
    assert_equal "Siber Güvenlik Buluşması", notification.dig("payload", "item", "title")
    assert_nil @store.claim_delivery
  ensure
    ENV.delete("RADAR_TEST_KEY")
  end

  def test_search_saves_unapproved_domains_without_crawling_them
    ENV["SERPAPI_API_KEY"] = "fake"
    http = FakeHTTP.new { response(200, JSON.generate("organic_results" => [
      { "title" => "Approved", "link" => "https://example.org/1" },
      { "title" => "New source", "link" => "https://new-source.test/2" }
    ])) }
    runner = Radar::Runner.new(config, @store, http: http)
    runner.search(profile, { "query" => "test", "cycle" => "test", "initial" => false })
    assert_equal 1, @store.query("SELECT count(*)::integer AS n FROM radar_jobs").first["n"]
    assert_equal "https://new-source.test/2", @store.review["domains"].first["url"]
  ensure
    ENV.delete("SERPAPI_API_KEY")
  end

  def test_api_auth_and_real_local_claim_ack
    c = config
    c.data["profiles"] = [profile]
    c.data["port"] = 0
    api = Radar::API.new(c, @store, token: "t" * 32)
    port = api.instance_variable_get(:@server).config[:Port]
    thread = Thread.new { api.start }
    client = Radar::BotClient.new("http://127.0.0.1:#{port}", "t" * 32)
    @store.apply_items(profile, "https://example.org/a", [item], silent: false)
    job = client.call("/api/v1/notification-jobs/claim")
    assert job["delivery_id"]
    assert client.call("/api/v1/notification-jobs/#{job['delivery_id']}/ack", job.merge("message_id" => "1"))["ok"]
    bad = Radar::BotClient.new("http://127.0.0.1:#{port}", "wrong")
    assert_raises(Radar::WorkError) { bad.call("/api/v1/notification-jobs/claim") }
  ensure
    api&.shutdown
    thread&.join
  end

  def test_crawl_forbidden_blocks_host_and_preserves_last_document
    @store.reserve_host("example.org", 1)
    @store.robots("example.org", "User-agent: *\nAllow: /")
    @store.query("UPDATE radar_hosts SET next_at=now()-interval '1 second'")
    url = "https://example.org/events"
    key = Radar.digest([profile["id"], url])
    @store.save_document(key, profile["id"], url, { "text" => "last valid", "links" => [], "source_tags" => [] }, "hash", "sig", {})
    http = FakeHTTP.new { response(403, "denied", {}, url) }
    runner = Radar::Runner.new(config, @store, http: http)
    assert_raises(Radar::WorkError) { runner.crawl(profile, { "url" => url, "cycle" => "test", "depth" => 0, "initial" => false }) }
    assert @store.host("example.org")["blocked"]
    assert_equal "last valid", @store.document(key)["content"]["text"]
  end

  def test_crawl_redirect_cannot_reach_private_or_unapproved_host
    @store.reserve_host("example.org", 1)
    @store.robots("example.org", "User-agent: *\nAllow: /")
    @store.query("UPDATE radar_hosts SET next_at=now()-interval '1 second'")
    http = FakeHTTP.new { response(302, "", { "location" => "http://169.254.169.254/latest/meta-data/" }) }
    runner = Radar::Runner.new(config, @store, http: http)
    e = assert_raises(Radar::WorkError) { runner.crawl(profile, { "url" => "https://example.org/events", "cycle" => "test", "depth" => 0, "initial" => false }) }
    assert_equal "domain_not_allowed", e.code
    assert_equal 1, http.calls.size
  end

  def test_changed_model_is_silently_reprocessed_and_stale_job_is_ignored
    c = config
    c.data["profiles"] = [profile]
    runner = Radar::Runner.new(c, @store, http: FakeHTTP.new { flunk "Stale work must not call LLM" })
    @store.save_document("key", profile["id"], "https://example.org/a", { "text" => "text" }, "new", "new", {})
    runner.analyze(profile, { "document_key" => "key", "hash" => "old", "signature" => "old" })
    @store.apply_items(profile, "https://example.org/a", [item], silent: false)
    @store.apply_items(profile, "https://example.org/a", [item.merge("date" => "2030-11-01")], silent: true)
    assert_equal 1, @store.query("SELECT count(*)::integer AS n FROM radar_outbox").first["n"]
  end

  def test_redirect_reuses_page_slot_and_link_rotation_prefers_unread
    p = profile.merge("max_pages" => 1)
    payload = { "cycle" => "one", "depth" => 0 }
    @store.enqueue_crawl(p, "https://example.org/start", payload)
    @store.enqueue_crawl(p, "https://example.org/fair", payload, redirect_from: "https://example.org/start")
    assert_equal ["https://example.org/fair"], @store.query("SELECT url FROM radar_crawl_visits").map { |r| r["url"] }
    assert_equal 2, @store.query("SELECT count(*)::integer AS n FROM radar_jobs").first["n"]
    @store.save_document("existing", p["id"], "https://example.org/old", {}, "hash", "sig", {})
    assert_equal ["https://example.org/new", "https://example.org/old"], @store.prioritize_unread(p, ["https://example.org/old", "https://example.org/new"])
  end

  def test_search_has_daily_schedule_independent_of_crawl
    c = config
    p = profile.merge("search_queries" => ["test"], "search_interval_seconds" => 86400)
    c.data["profiles"] = [p]
    c.data["max_jobs_per_tick"] = 0 # Inspect scheduling without processing network work.
    runner = Radar::Runner.new(c, @store, http: FakeHTTP.new { flunk "No network" })
    runner.tick
    @store.query("UPDATE radar_jobs SET state='done'")
    @store.query("UPDATE radar_schedules SET next_at=now()-interval '1 second' WHERE profile_id=$1", [p["id"]])
    runner.tick
    assert_equal "done", @store.query("SELECT state FROM radar_jobs WHERE kind='search'").first["state"]
    assert_equal "pending", @store.query("SELECT state FROM radar_jobs WHERE kind='crawl'").first["state"]
  end

  def test_discovery_opens_only_returned_domains_and_report_includes_empty_sources
    ENV["SERPAPI_API_KEY"] = "fake"
    p = profile.merge("discover_new_domains" => true, "max_depth" => 0)
    http = FakeHTTP.new do |_, url, _|
      if url.include?("serpapi.com")
        response(200, JSON.generate("organic_results" => [{ "link" => "https://new-source.test/events" }]))
      else
        response(200, "<main>Trade fair announcement content</main>", { "content-type" => "text/html" }, url)
      end
    end
    runner = Radar::Runner.new(config, @store, http: http)
    runner.search(p, { "query" => "test", "cycle" => "discovery", "initial" => false })
    @store.query("INSERT INTO radar_hosts(host) VALUES('new-source.test')")
    @store.robots("new-source.test", "")
    runner.crawl(p, { "url" => "https://new-source.test/events", "depth" => 0 })
    assert_equal "domain_not_allowed", assert_raises(Radar::WorkError) {
      runner.crawl(p, { "url" => "https://unseen.test/", "depth" => 0 })
    }.code
    @store.apply_items(p, "https://new-source.test/events", [item], silent: false)
    report = @store.sources([p, p.merge("id" => "empty")])
    assert_equal 1, report.first["pages"]
    assert_equal 1, report.first.dig("items", "matched")
    assert_equal 1, report.first.dig("notifications", "pending")
    assert_equal 0, report.last["pages"]
    assert_empty report.last["jobs"]
  ensure
    ENV.delete("SERPAPI_API_KEY")
  end

  def test_robots_redirect_is_resumed_then_disallow_is_enforced
    http = FakeHTTP.new do |_, url, _|
      if url.end_with?("robots.txt")
        response(301, "", { "location" => "/robots-policy" }, url)
      else
        response(200, "User-agent: *\nDisallow: /private", {}, url)
      end
    end
    runner = Radar::Runner.new(config, @store, http: http)
    assert_equal "host_wait", assert_raises(Radar::WorkError) { runner.check_robots("https://example.org/private", profile) }.code
    @store.query("UPDATE radar_hosts SET next_at=now()-interval '1 second'")
    assert_equal "robots_disallowed", assert_raises(Radar::WorkError) { runner.check_robots("https://example.org/private", profile) }.code
    assert_equal 2, http.calls.size
    assert_nil @store.host("example.org")["robots_fetch_url"]
  end

  def test_retry_crawls_does_not_retry_blocked_or_inactive_sources
    ["network_error", "robots_disallowed", "http_403"].each do |code|
      @store.enqueue("crawl", profile["id"], {}, key: code)
      @store.query("UPDATE radar_jobs SET state='review',error=$1 WHERE key=$1", [code])
    end
    @store.enqueue("crawl", "inactive", {}, key: "inactive")
    @store.query("UPDATE radar_jobs SET state='review',error='network_error' WHERE key='inactive'")
    assert_equal 1, @store.retry_crawls([profile])
    assert_equal ["network_error"], @store.query("SELECT key FROM radar_jobs WHERE state='pending'").map { |r| r["key"] }
  end

  def test_analysis_report_invalidates_changed_document_only
    @store.save_document("doc", profile["id"], "https://example.org/", { "text" => "text" }, "hash", "sig", {})
    @store.mark_analyzed("doc", 0)
    @store.save_document("doc", profile["id"], "https://example.org/", { "text" => "text" }, "hash", "sig", {})
    assert_equal 1, @store.sources([profile]).first["pages_analyzed"]
    @store.save_document("doc", profile["id"], "https://example.org/", { "text" => "changed" }, "new-hash", "sig", {})
    assert_equal 0, @store.sources([profile]).first["pages_analyzed"]
  end

  def test_cross_domain_robots_redirect_still_requires_review
    http = FakeHTTP.new { response(302, "", { "location" => "https://other.test/robots.txt" }) }
    runner = Radar::Runner.new(config, @store, http: http)
    assert_equal "robots_redirect_requires_review", assert_raises(Radar::WorkError) { runner.check_robots("https://example.org/events", profile) }.code
    assert_equal 1, http.calls.size
  end

  def test_queued_notices_are_suppressed_and_duplicate_events_are_sent_once
    p = profile.merge("meeting_only" => true, "allowed_types" => ["event"], "include_words" => [], "exclude_words" => [])
    old = p.merge("meeting_only" => false, "allowed_types" => [])
    notice = item.merge("title" => "Gümrük Müşavirleri için Vekaleten Belge Talebi", "type" => "announcement", "date" => nil)
    @store.apply_items(old, "https://example.org/belge", [notice], silent: false)
    event = item.merge("evidence" => "Yazılım Buluşması 15 Ekim 2030 tarihinde İstanbul'da düzenlenecek.")
    @store.apply_items(p, "https://example.org/event", [event], silent: false)
    @store.apply_items(p, "https://another.test/event", [event], silent: false)
    job = @store.claim_delivery(profiles: [p])
    assert_equal event["title"], job.dig("payload", "item", "title")
    assert @store.delivery_action(job["delivery_id"], "fail", job.merge("type" => "transient", "retry_after" => 1))
    @store.query("UPDATE radar_outbox SET available_at=now()-interval '1 second' WHERE id=$1", [job["delivery_id"]])
    retried = @store.claim_delivery(profiles: [p])
    assert_equal job["delivery_id"], retried["delivery_id"]
    assert @store.delivery_action(retried["delivery_id"], "ack", retried.merge("message_id" => "55"))
    assert_nil @store.claim_delivery(profiles: [p])
    assert_equal 2, @store.query("SELECT count(*)::integer AS n FROM radar_outbox WHERE state='suppressed'").first["n"]
  end

  def test_new_call_audit_records_success_and_failure_without_secrets
    @store.record_llm_call(config["llm"], profile, "https://example.org/event", 6000, "ok")
    @store.record_llm_call(config["llm"], profile, "https://example.org/event", 6000, "llm_unverified_evidence")
    report = @store.audit
    assert_equal 2, report["expensive_pages"].first["calls"]
    assert_equal %w[llm_unverified_evidence ok], report["llm_last_24h"].map { |r| r["outcome"] }.sort
  end

  def test_bad_llm_output_stops_after_two_attempts
    @store.enqueue("analyze", profile["id"], {}, key: "bad-response")
    2.times do
      @store.query("UPDATE radar_jobs SET available_at=now()-interval '1 second'")
      @store.fail_job(@store.claim_job, Radar::WorkError.new("llm_unverified_evidence"))
    end
    assert_equal "review", @store.query("SELECT state FROM radar_jobs WHERE key='bad-response'").first["state"]
  end

  private


  def run_ready(runner)
    4.times do
      @store.query("UPDATE radar_hosts SET next_at=now()-interval '1 second'")
      @store.query("UPDATE radar_jobs SET available_at=now()-interval '1 second' WHERE state='pending'")
      runner.tick
    end
  end
end
