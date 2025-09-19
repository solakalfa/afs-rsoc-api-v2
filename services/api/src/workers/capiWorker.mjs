// services/api/src/workers/capiWorker.mjs
// M6 capiWorker — PG-backed outbox reader + dry-run sender
// Notes:
// - Loads .env automatically (dotenv/config).
// - Uses pg.Pool via DATABASE_URL.
// - Provides --ensure to create outbox table (minimal shape) if missing.
// - Provides --seed to insert demo rows if table empty.
// - Reads up to --limit rows and simulates send to Meta (no network).

import 'dotenv/config';
import { Pool } from 'pg';

console.log(`[DEBUG] capiWorker.mjs (pg) loaded at ${new Date().toISOString()}`);

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  console.warn('[WARN] DATABASE_URL is not set; defaulting to local postgres');
}
const pool = new Pool({
  connectionString: DATABASE_URL || 'postgres://postgres:postgres@127.0.0.1:5432/rsoc',
  // If your Cloud SQL requires SSL, add: ssl: { rejectUnauthorized: false }
});

async function ensureOutbox() {
  const sql = `
    CREATE TABLE IF NOT EXISTS outbox (
      id            BIGSERIAL PRIMARY KEY,
      topic         TEXT NOT NULL,
      payload_json  JSONB NOT NULL,
      created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
      attempts      INT NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS outbox_created_idx ON outbox (created_at);
  `;
  await pool.query(sql);
  console.log('[ENSURE] outbox table ensured');
}

async function seedDemoIfEmpty() {
  const { rows } = await pool.query('SELECT count(*)::int AS c FROM outbox');
  if (rows[0]?.c > 0) {
    console.log('[SEED] skipped (outbox not empty)');
    return;
  }
  const demo = [
    { topic: 'conversion', payload: { click_id: 'c-1', value: 1, currency: 'USD' } },
    { topic: 'conversion', payload: { click_id: 'c-2', value: 2, currency: 'USD' } },
    { topic: 'conversion', payload: { click_id: 'c-3', value: 3, currency: 'USD' } },
  ];
  for (const d of demo) {
    await pool.query(
      'INSERT INTO outbox (topic, payload_json) VALUES ($1, $2::jsonb)',
      [d.topic, JSON.stringify(d.payload)]
    );
  }
  console.log('[SEED] inserted 3 demo rows');
}

async function readOutbox(limit = 10) {
  const { rows } = await pool.query(
    `SELECT id, topic, payload_json
       FROM outbox
      ORDER BY created_at ASC
      LIMIT $1`,
    [limit]
  );
  return rows.map(r => ({
    id: String(r.id),
    topic: r.topic,
    payload: r.payload_json,
  }));
}

// --- DRY-RUN sender (no network) ---
async function sendToMetaDry(event) {
  console.log('[META][DRY-RUN] sending', { id: event.id, topic: event.topic });
  return { ok: true, status: 'simulated' };
}

// --- Minimal local idempotency (fallback). Replace with your lib/idempotency.mjs when wiring. ---
const sentOnce = new Set();
async function ensureIdempotent(key) {
  if (sentOnce.has(key)) return true;
  sentOnce.add(key);
  return false;
}

// --- Minimal retry (fallback). Replace with your lib/retry.mjs when wiring. ---
async function withRetry(op, { retries = 3, baseMs = 250 } = {}) {
  let lastErr;
  for (let i = 0; i <= retries; i++) {
    try { return await op(); } catch (err) {
      lastErr = err;
      if (i === retries) break;
      const ms = baseMs * Math.pow(2, i);
      console.warn(`[RETRY] attempt ${i + 1} failed → sleep ${ms}ms`, String(err?.message || err));
      await new Promise(r => setTimeout(r, ms));
    }
  }
  throw lastErr;
}

async function processEvent(event) {
  const key = `capi:${event.id}`;
  const already = await ensureIdempotent(key);
  if (already) {
    console.log('[IDEMPOTENT] skip', key);
    return { ok: true, skipped: true };
  }
  return withRetry(() => sendToMetaDry(event), { retries: 2, baseMs: 200 });
}

async function main(opts = {}) {
  const limit = Number(opts.limit ?? process.env.CAPI_LIMIT ?? 10);
  const dry = String(opts.dry ?? 'true') !== 'false';
  const ensure = String(opts.ensure ?? 'false') === 'true';
  const seed = String(opts.seed ?? 'false') === 'true';

  console.log(`[BOOT] capiWorker | limit=${limit} | dry=${dry} | ensure=${ensure} | seed=${seed}`);

  if (ensure) await ensureOutbox();
  if (seed) await seedDemoIfEmpty();

  const items = await readOutbox(limit);
  console.log(`[OUTBOX] fetched ${items.length}`);

  for (const ev of items) {
    try {
      const res = await processEvent(ev);
      console.log('[DONE]', { id: ev.id, res });
    } catch (err) {
      console.error('[FAIL]', { id: ev.id, err: String(err?.message || err) });
    }
  }

  console.log('[EXIT] capiWorker done');
}

// Windows-safe runner guard (normalized)
(function maybeRun() {
  try {
    const argv1 = process.argv[1] || '';
    const fromArg = `file://${argv1.replace(/\\/g, '/')}`;
    const urlPath = new URL(import.meta.url).pathname;
    const argPath = new URL(fromArg).pathname;
    const isDirect = argv1 && urlPath === argPath;
    const nameMatch = argv1.replace(/\\/g, '/').endsWith('/services/api/src/workers/capiWorker.mjs');

    if (isDirect || nameMatch) {
      const args = Object.fromEntries(
        process.argv.slice(2).map(a => {
          const [k, v = true] = a.replace(/^--/, '').split('=');
          return [k, v];
        })
      );
      main(args).finally(() => pool.end()).catch(err => {
        console.error('[FATAL]', err);
        process.exit(1);
      });
    } else {
      console.log('[DEBUG] not running main (module imported)');
    }
  } catch (e) {
    console.warn('[WARN] main guard fallback -> running main()', String(e?.message || e));
    main({}).finally(() => pool.end()).catch(err => {
      console.error('[FATAL]', err);
      process.exit(1);
    });
  }
})();

export { main, readOutbox, processEvent };
