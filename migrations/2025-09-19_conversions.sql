-- normalize conversions schema + idempotency on click_id

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS conversions (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  conversion_id  UUID DEFAULT gen_random_uuid(),
  click_id       TEXT NOT NULL,
  ext_id         TEXT,
  amount         NUMERIC,
  value          NUMERIC,
  currency       TEXT NOT NULL DEFAULT 'USD',
  event          TEXT NOT NULL DEFAULT 'conversion',
  ts             BIGINT NOT NULL DEFAULT ((EXTRACT(EPOCH FROM NOW())*1000)::BIGINT),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure unique click_id for idempotency
CREATE UNIQUE INDEX IF NOT EXISTS ux_conversions_click_id ON conversions(click_id);

-- Index for queries by time
CREATE INDEX IF NOT EXISTS idx_conversions_ts ON conversions(ts);
