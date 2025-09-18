-- M2.2 MVP: Dead Letter Queue for Outbox
CREATE TABLE IF NOT EXISTS outbox_dlq (
  id SERIAL PRIMARY KEY,
  outbox_id INTEGER NOT NULL,
  trace_id TEXT,
  payload JSONB NOT NULL,
  failed_status INTEGER,
  attempts INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
