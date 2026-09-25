require "pg"
require "monitor"

module Radar
  class Store
    def initialize(url)
      @db = PG.connect(url, connect_timeout: 10)
      @mutex = Monitor.new
      @db.type_map_for_results = PG::BasicTypeMapForResults.new(@db)
      @db.exec("SET TIME ZONE 'UTC'")
    end

    def close = @db.close
    def query(sql, params = []) = @mutex.synchronize { @db.exec_params(sql, params).to_a }
    def transaction
      @mutex.synchronize do
        return yield if @in_transaction
        @db.exec("BEGIN")
        @in_transaction = true
        completed = false
        begin
          result = yield
          completed = true
          result
        ensure
          @in_transaction = false
          @db.exec(completed ? "COMMIT" : "ROLLBACK")
        end
      end
    end
    def migrate
      @mutex.synchronize { @db.exec(File.read(File.expand_path("../../db/schema.sql", __dir__))) }
    end

    def lock!
      raise "Başka radar worker'ı çalışıyor" unless query("SELECT pg_try_advisory_lock(824735019) AS locked").first["locked"]
    end

    def schedule(profile, key: profile["id"], interval: profile["interval_seconds"])
      transaction do
        query("INSERT INTO radar_schedules(profile_id,next_at) VALUES($1,now()) ON CONFLICT DO NOTHING", [key])
        row = query("SELECT * FROM radar_schedules WHERE profile_id=$1 FOR UPDATE", [key]).first
        next nil if row["next_at"] > Time.now
        yield !row["started"]
        query("UPDATE radar_schedules SET started=true,next_at=now()+$2*interval '1 second' WHERE profile_id=$1", [key, interval])
      end
    end

    def enqueue(kind, profile_id, payload, key:, refresh: false)
      sql = "INSERT INTO radar_jobs(key,kind,profile_id,payload) VALUES($1,$2,$3,$4) ON CONFLICT(key) DO NOTHING"
      if refresh
        sql = "INSERT INTO radar_jobs(key,kind,profile_id,payload) VALUES($1,$2,$3,$4) ON CONFLICT(key) DO UPDATE SET payload=EXCLUDED.payload,state='pending',attempts=0,available_at=now(),error=NULL WHERE radar_jobs.state='done'"
      end
      query(sql, [key, kind, profile_id, JSON.generate(payload)])
    end

    def claim_job
      query(<<~SQL).first
        WITH candidate AS (
          SELECT id FROM radar_jobs WHERE (state='pending' AND available_at<=now())
          OR (state='working' AND lease_until<now()) ORDER BY available_at,id FOR UPDATE SKIP LOCKED LIMIT 1
        ) UPDATE radar_jobs SET state='working',lease_until=now()+interval '1 hour',updated_at=now()
          FROM candidate WHERE radar_jobs.id=candidate.id RETURNING radar_jobs.*
      SQL
    end

    def done(id)
      query("UPDATE radar_jobs SET state='done',error=NULL,lease_until=NULL,updated_at=now() WHERE id=$1", [id])
    end

    def fail_job(job, error)
      deferred = %w[host_wait daily_budget].include?(error.code)
      attempts = job["attempts"] + (deferred ? 0 : 1)
      state = error.permanent || attempts >= 5 ? "review" : "pending"
      delay = [error.delay, deferred ? 1 : 30 * 2**[attempts, 8].min + rand(10)].max
      query("UPDATE radar_jobs SET state=$2,attempts=$3,error=$4,available_at=now()+$5*interval '1 second',lease_until=NULL,updated_at=now() WHERE id=$1", [job["id"], state, attempts, error.code, delay])
    end

    def document(key) = query("SELECT * FROM radar_documents WHERE key=$1", [key]).first
    def cached_analysis(key) = query("SELECT items FROM radar_analysis_cache WHERE key=$1", [key]).first&.fetch("items")
    def cache_analysis(key, items)
      query("INSERT INTO radar_analysis_cache(key,items) VALUES($1,$2) ON CONFLICT DO NOTHING", [key, JSON.generate(items)])
    end
    def known_urls(profile)
      query("SELECT url FROM radar_documents WHERE profile_id=$1 ORDER BY checked_at LIMIT $2", [profile["id"], profile["max_pages"]]).map { |r| r["url"] }
    end
    def enqueue_crawl(profile, url, payload, redirect_from: nil)
      transaction do
        # A redirect replaces the original visit instead of consuming another page slot.
        query("DELETE FROM radar_crawl_visits WHERE profile_id=$1 AND cycle=$2 AND url=$3", [profile["id"], payload["cycle"], redirect_from]) if redirect_from
        count = query("SELECT count(*)::integer AS n FROM radar_crawl_visits WHERE profile_id=$1 AND cycle=$2", [profile["id"], payload["cycle"]]).first["n"]
        next if count >= profile["max_pages"]
        rows = query("INSERT INTO radar_crawl_visits(profile_id,cycle,url) VALUES($1,$2,$3) ON CONFLICT DO NOTHING RETURNING url", [profile["id"], payload["cycle"], url])
        next if rows.empty?
        enqueue("crawl", profile["id"], payload.merge("url" => url), key: Radar.digest(["crawl", profile["id"], url]), refresh: true)
      end
    end

    def discovery_allowed?(profile_id, url)
      !query("SELECT 1 FROM radar_discovery WHERE profile_id=$1 AND url=$2 AND state='approved' LIMIT 1", [profile_id, url]).empty?
    end

    def prioritize_unread(profile, links)
      checked = query("SELECT url,checked_at FROM radar_documents WHERE profile_id=$1", [profile["id"]]).to_h { |r| [r["url"], r["checked_at"]] }
      links.each_with_index.sort_by { |url, index| [checked.key?(url) ? 1 : 0, checked[url] || Time.at(0), index] }.map(&:first)
    end
    def save_document(key, profile_id, url, content, hash, signature, headers)
      query(<<~SQL, [key, profile_id, url, hash, signature, headers["etag"], headers["last-modified"], JSON.generate(content)])
        INSERT INTO radar_documents(key,profile_id,url,hash,signature,etag,modified,content) VALUES($1,$2,$3,$4,$5,$6,$7,$8)
        ON CONFLICT(key) DO UPDATE SET hash=$4,signature=$5,etag=$6,modified=$7,content=$8,checked_at=now(),
          analyzed_at=CASE WHEN radar_documents.hash=$4 AND radar_documents.signature=$5 THEN radar_documents.analyzed_at END,
          analyzed_items=CASE WHEN radar_documents.hash=$4 AND radar_documents.signature=$5 THEN radar_documents.analyzed_items END
      SQL
    end

    def mark_analyzed(key, count)
      query("UPDATE radar_documents SET analyzed_at=now(),analyzed_items=$2 WHERE key=$1", [key, count])
    end

    def reserve_host(host, delay)
      transaction do
        query("INSERT INTO radar_hosts(host) VALUES($1) ON CONFLICT DO NOTHING", [host])
        row = query("SELECT * FROM radar_hosts WHERE host=$1 FOR UPDATE", [host]).first
        raise WorkError.new("host_blocked", permanent: true) if row["blocked"]
        raise WorkError.new("host_wait", delay: (row["next_at"] - Time.now).ceil) if row["next_at"] > Time.now
        query("UPDATE radar_hosts SET next_at=now()+$2*interval '1 second' WHERE host=$1", [host, delay])
      end
    end

    def host(host) = query("SELECT * FROM radar_hosts WHERE host=$1", [host]).first
    def robots(host, body)
      query("UPDATE radar_hosts SET robots=$2,robots_until=now()+interval '12 hours',robots_fetch_url=NULL,robots_redirects=0 WHERE host=$1", [host, body])
    end
    def robots_redirect(host, url, hops)
      query("UPDATE radar_hosts SET robots_fetch_url=$2,robots_redirects=$3 WHERE host=$1", [host, url, hops])
    end
    def block_host(host, reason)
      query("UPDATE radar_hosts SET blocked=true,reason=$2 WHERE host=$1", [host, reason])
    end
    def cooldown_host(host, seconds)
      query("UPDATE radar_hosts SET next_at=GREATEST(next_at,now()+$2*interval '1 second') WHERE host=$1", [host, seconds])
    end
    def budget!(provider, limit)
      rows = query(<<~SQL, [provider, limit])
        INSERT INTO radar_usage(day,provider,calls) VALUES(CURRENT_DATE,$1,1)
        ON CONFLICT(day,provider) DO UPDATE SET calls=radar_usage.calls+1 WHERE radar_usage.calls<$2 RETURNING calls
      SQL
      raise WorkError.new("daily_budget", delay: 3600) if rows.empty?
    end

    def discover(profile, result, query_text, allowed)
      query(<<~SQL, [profile, result["link"], query_text, result["title"], result["snippet"], allowed ? "approved" : "review_new_domain"])
        INSERT INTO radar_discovery(profile_id,url,query,title,snippet,state) VALUES($1,$2,$3,$4,$5,$6)
        ON CONFLICT(profile_id,url,query) DO UPDATE SET title=$4,snippet=$5,state=$6,found_at=now()
      SQL
    end

    def apply_items(profile, url, items, silent:)
      transaction do
        items.each do |item|
          key = Radar.digest([profile["id"], url, Filter.normalize(item["title"])])
          # Ignore LLM prose/tag ordering drift; event changes are date/location/type changes.
          fingerprint = Radar.digest(item.values_at("type", "date", "location"))
          prior = query("SELECT fingerprint,decision FROM radar_items WHERE key=$1 FOR UPDATE", [key]).first
          decision = Filter.decision(item, profile)
          query(<<~SQL, [key, profile["id"], url, JSON.generate(item), fingerprint, decision])
            INSERT INTO radar_items(key,profile_id,source_url,content,fingerprint,decision) VALUES($1,$2,$3,$4,$5,$6)
            ON CONFLICT(key) DO UPDATE SET content=$4,fingerprint=$5,decision=$6,updated_at=now()
          SQL
          changed = prior && prior["fingerprint"] != fingerprint
          newly_matched = prior && prior["decision"] != "matched"
          next if silent || decision != "matched" || (prior && !changed && !newly_matched)
          event = SecureRandom.uuid
          kind = prior && !newly_matched ? "updated" : "new"
          payload = { "kind" => kind, "item" => item, "url" => url, "checked_at" => Time.now.utc.iso8601, "evidence_status" => "source_quote_verified" }
          query("INSERT INTO radar_events(id,item_key,kind,payload) VALUES($1,$2,$3,$4)", [event, key, kind, JSON.generate(payload)])
          query("INSERT INTO radar_outbox(id,event_id,target_ref,payload) VALUES($1,$2,$3,$4)", [SecureRandom.uuid, event, profile["target_ref"], JSON.generate(payload)])
        end
      end
    end

    def claim_delivery
      transaction do
        # An expired delivery may have reached Telegram. Hold for manual reconciliation.
        query("UPDATE radar_outbox SET state='unknown_delivery',error='lease_expired' WHERE state='sending' AND lease_until<now()")
        row = query("SELECT id FROM radar_outbox WHERE state='pending' AND available_at<=now() ORDER BY created_at FOR UPDATE SKIP LOCKED LIMIT 1").first
        next nil unless row
        token = SecureRandom.hex(24)
        job = query("UPDATE radar_outbox SET state='sending',claim_token=$2,lease_until=now()+interval '5 minutes',attempts=attempts+1 WHERE id=$1 RETURNING id AS delivery_id,claim_token,lease_until,target_ref,payload", [row["id"], token]).first
        job["lease_until"] = job["lease_until"].utc.iso8601
        job
      end
    end

    def delivery_action(id, action, input)
      transaction do
        row = query("SELECT * FROM radar_outbox WHERE id=$1 FOR UPDATE", [id]).first
        next false unless row && row["claim_token"] == input["claim_token"]
        next true if action == "ack" && row["state"] == "sent" && row["message_id"] == input["message_id"].to_s
        next false unless row["state"] == "sending" && row["lease_until"] > Time.now
        case action
        when "ack"
          next false if input["message_id"].to_s.empty?
          query("UPDATE radar_outbox SET state='sent',message_id=$2,lease_until=NULL WHERE id=$1", [id, input["message_id"].to_s])
        when "renew"
          query("UPDATE radar_outbox SET lease_until=now()+interval '5 minutes' WHERE id=$1", [id])
        when "fail"
          type = input["type"]
          next false unless %w[transient permanent unknown_delivery].include?(type)
          state = type == "transient" ? (row["attempts"] >= 5 ? "failed" : "pending") : (type == "permanent" ? "failed" : "unknown_delivery")
          delay = [[input.fetch("retry_after", 60).to_i, 1].max, 604800].min
          query("UPDATE radar_outbox SET state=$2,error=$3,lease_until=NULL,available_at=now()+$4*interval '1 second' WHERE id=$1", [id, state, type, delay])
        else
          next false
        end
        query("INSERT INTO radar_delivery_attempts(delivery_id,result) VALUES($1,$2)", [id, action == "fail" ? input["type"] : action])
        true
      end
    end

    def status
        { "jobs" => query("SELECT state,count(*)::integer AS count FROM radar_jobs GROUP BY state"),
          "waiting_jobs" => query("SELECT id,kind,profile_id,attempts,error,available_at FROM radar_jobs WHERE state='pending' ORDER BY available_at,id LIMIT 20"),
        "notifications" => query("SELECT state,count(*)::integer AS count FROM radar_outbox GROUP BY state"),
        "items" => query("SELECT decision,count(*)::integer AS count FROM radar_items GROUP BY decision"),
        "usage_today" => query("SELECT provider,calls FROM radar_usage WHERE day=CURRENT_DATE") }
    end

    def sources(profiles)
      documents = query("SELECT profile_id,count(*)::integer AS pages,count(analyzed_at)::integer AS pages_analyzed,max(analyzed_at) AS last_analysis,max(checked_at) AS last_fetch,max(length(content->>'text'))::integer AS largest_text_chars FROM radar_documents GROUP BY profile_id").to_h { |r| [r["profile_id"], r] }
      jobs = query("SELECT profile_id,kind,state,error,count(*)::integer AS count FROM radar_jobs GROUP BY profile_id,kind,state,error").group_by { |r| r["profile_id"] }
      items = query("SELECT profile_id,decision,count(*)::integer AS count FROM radar_items GROUP BY profile_id,decision").group_by { |r| r["profile_id"] }
      deliveries = query(<<~SQL).group_by { |r| r["profile_id"] }
        SELECT i.profile_id,o.state,count(*)::integer AS count FROM radar_outbox o
        JOIN radar_events e ON e.id=o.event_id JOIN radar_items i ON i.key=e.item_key
        GROUP BY i.profile_id,o.state
      SQL
      profiles.map do |p|
        { "id" => p["id"], "sources" => p["seed_urls"], "google_queries" => p["search_queries"].size,
          "pages" => documents.dig(p["id"], "pages") || 0,
          "pages_analyzed" => documents.dig(p["id"], "pages_analyzed") || 0,
          "last_analysis" => documents.dig(p["id"], "last_analysis"),
          "last_fetch" => documents.dig(p["id"], "last_fetch"),
          "largest_text_chars" => documents.dig(p["id"], "largest_text_chars") || 0,
          "jobs" => (jobs[p["id"]] || []).map { |r| r.reject { |k, _| k == "profile_id" } },
          "items" => (items[p["id"]] || []).to_h { |r| [r["decision"], r["count"]] },
          "notifications" => (deliveries[p["id"]] || []).to_h { |r| [r["state"], r["count"]] } }
      end
    end
    def review
      { "jobs" => query("SELECT id,kind,profile_id,error FROM radar_jobs WHERE state='review' ORDER BY id LIMIT 100"),
        "domains" => query("SELECT profile_id,url,title FROM radar_discovery WHERE state='review_new_domain' LIMIT 100"),
        "hosts" => query("SELECT host,reason FROM radar_hosts WHERE blocked=true"),
        "uncertain" => query("SELECT source_url,content FROM radar_items WHERE decision='uncertain' LIMIT 100"),
        "deliveries" => query("SELECT id,target_ref,state,error FROM radar_outbox WHERE state IN ('unknown_delivery','failed') LIMIT 100") }
    end
    def retry_job(id)
      query("UPDATE radar_jobs SET state='pending',attempts=0,available_at=now() WHERE id=$1 AND state='review'", [id])
    end
    def retry_crawls(profiles)
      profiles.sum do |profile|
        query("UPDATE radar_jobs SET state='pending',attempts=0,error=NULL,available_at=now() WHERE profile_id=$1 AND kind='crawl' AND state='review' AND error IN ('network_error','http_500','http_502','http_503','http_504','robots_redirect_requires_review') RETURNING id", [profile["id"]]).size
      end
    end
    def unblock_host(host)
      query("UPDATE radar_hosts SET blocked=false,reason=NULL,next_at=now(),robots_until=NULL,robots_fetch_url=NULL,robots_redirects=0 WHERE host=$1", [host])
    end
    def resolve_delivery(id, action)
      raise "İşlem sent veya retry olmalı" unless %w[sent retry].include?(action)
      transaction do
        query("UPDATE radar_outbox SET state=$2,available_at=now(),claim_token=NULL WHERE id=$1 AND state IN ('unknown_delivery','failed')", [id, action == "sent" ? "sent" : "pending"])
        query("INSERT INTO radar_delivery_attempts(delivery_id,result) VALUES($1,$2)", [id, "manual_#{action}"])
      end
    end
  end
end
