-- M2.2 MVP: Idempotency storage
CREATE TABLE IF NOT EXISTS idempotency_keys (
  id SERIAL PRIMARY KEY,
  idem_key TEXT NOT NULL UNIQUE,
  method TEXT NOT NULL,
  path TEXT NOT NULL,
  body_hash TEXT NOT NULL,
  status_code INTEGER,
  response_body TEXT,
  state TEXT NOT NULL DEFAULT 'in_progress',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- TTL cleanup (run via cron/k8s job or Cloud Scheduler)
-- DELETE FROM idempotency_keys WHERE created_at < NOW() - INTERVAL '1 day';
