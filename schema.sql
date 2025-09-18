CREATE TABLE events (id SERIAL PRIMARY KEY, click_id TEXT, source TEXT, campaign_id TEXT, ts BIGINT); 
CREATE TABLE identities (id SERIAL PRIMARY KEY, user_id TEXT, email TEXT, phone TEXT); 
CREATE TABLE conversions (id SERIAL PRIMARY KEY, click_id TEXT, event TEXT, value NUMERIC, currency TEXT, ts BIGINT); 
CREATE TABLE outbox (id SERIAL PRIMARY KEY, payload JSONB, created_at TIMESTAMP DEFAULT NOW(), sent BOOLEAN DEFAULT FALSE); 
