CREATE TABLE IF NOT EXISTS radar_schedules (
  profile_id text PRIMARY KEY, next_at timestamptz NOT NULL, started boolean NOT NULL DEFAULT false
);
CREATE TABLE IF NOT EXISTS radar_jobs (
  id bigserial PRIMARY KEY, key text UNIQUE NOT NULL, kind text NOT NULL,
  profile_id text NOT NULL, payload jsonb NOT NULL,
  state text NOT NULL DEFAULT 'pending', attempts integer NOT NULL DEFAULT 0,
  available_at timestamptz NOT NULL DEFAULT now(), lease_until timestamptz,
  error text, updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS radar_jobs_due ON radar_jobs (available_at) WHERE state = 'pending';
CREATE TABLE IF NOT EXISTS radar_documents (
  key text PRIMARY KEY, profile_id text NOT NULL, url text NOT NULL,
  hash text NOT NULL, signature text NOT NULL, etag text, modified text,
  content jsonb NOT NULL, checked_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS radar_items (
  key text PRIMARY KEY, profile_id text NOT NULL, source_url text NOT NULL,
  content jsonb NOT NULL, fingerprint text NOT NULL, decision text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE radar_documents ADD COLUMN IF NOT EXISTS analyzed_at timestamptz;
ALTER TABLE radar_documents ADD COLUMN IF NOT EXISTS analyzed_items integer;
CREATE TABLE IF NOT EXISTS radar_events (
  id text PRIMARY KEY, item_key text NOT NULL REFERENCES radar_items(key),
  kind text NOT NULL, payload jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS radar_outbox (
  id text PRIMARY KEY, event_id text NOT NULL REFERENCES radar_events(id),
  target_ref text NOT NULL, payload jsonb NOT NULL, state text NOT NULL DEFAULT 'pending',
  claim_token text, lease_until timestamptz, available_at timestamptz NOT NULL DEFAULT now(),
  attempts integer NOT NULL DEFAULT 0, message_id text, error text,
  created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(event_id, target_ref)
);
CREATE INDEX IF NOT EXISTS radar_outbox_due ON radar_outbox (available_at) WHERE state = 'pending';
CREATE TABLE IF NOT EXISTS radar_delivery_attempts (
  id bigserial PRIMARY KEY, delivery_id text NOT NULL, result text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS radar_hosts (
  host text PRIMARY KEY, next_at timestamptz NOT NULL DEFAULT now(), blocked boolean NOT NULL DEFAULT false,
  reason text, robots text, robots_until timestamptz
);
CREATE TABLE IF NOT EXISTS radar_discovery (
  profile_id text NOT NULL, url text NOT NULL, query text NOT NULL, title text, snippet text,
  state text NOT NULL, found_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(profile_id,url,query)
);
ALTER TABLE radar_hosts ADD COLUMN IF NOT EXISTS robots_fetch_url text;
ALTER TABLE radar_hosts ADD COLUMN IF NOT EXISTS robots_redirects integer NOT NULL DEFAULT 0;
CREATE TABLE IF NOT EXISTS radar_usage (
  day date NOT NULL, provider text NOT NULL, calls integer NOT NULL, PRIMARY KEY(day,provider)
);
CREATE TABLE IF NOT EXISTS radar_llm_calls (
  id bigserial PRIMARY KEY, created_at timestamptz NOT NULL DEFAULT now(),
  provider text NOT NULL, model text NOT NULL, profile_id text NOT NULL,
  source_url text, input_chars integer NOT NULL, outcome text NOT NULL
);
CREATE INDEX IF NOT EXISTS radar_llm_calls_time ON radar_llm_calls(created_at);
CREATE TABLE IF NOT EXISTS radar_notification_keys (
  target_ref text NOT NULL, fingerprint text NOT NULL, delivery_id text NOT NULL,
  PRIMARY KEY(target_ref, fingerprint)
);
CREATE TABLE IF NOT EXISTS radar_analysis_cache (
  key text PRIMARY KEY, items jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS radar_crawl_visits (
  profile_id text NOT NULL, cycle text NOT NULL, url text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(profile_id,cycle,url)
);
