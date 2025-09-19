// services/api/src/workers/capiWorker.mjs
// M6 capiWorker — DRY-RUN skeleton with Windows-safe main guard

// ---- DEBUG: verify load ----
console.log(`[DEBUG] capiWorker.mjs loaded at ${new Date().toISOString()}`);

// Stage 1: fake outbox + dry-run "send"
function fakeReadOutbox(limit = 10) {
  return Array.from({ length: Math.min(limit, 3) }, (_, i) => ({
    id: `demo-${i + 1}`,
    topic: 'conversion',
    payload: { click_id: `c-${i + 1}`, value: 1, currency: 'USD' },
  }));
}

async function sendToMetaDry(event) {
  console.log('[META][DRY-RUN] sending', { id: event.id, topic: event.topic });
  return { ok: true, status: 'simulated' };
}

async function processEvent(event) {
  // TODO (next step): ensureIdempotent + withRetry wrappers
  return sendToMetaDry(event);
}

async function main(opts = {}) {
  const limit = Number(opts.limit ?? process.env.CAPI_LIMIT ?? 10);
  const dry = String(opts.dry ?? 'true') !== 'false';
  console.log(`[BOOT] capiWorker | limit=${limit} | dry=${dry}`);

  const items = fakeReadOutbox(limit);
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

// ---- Windows-safe "run if executed directly" guard ----
(function maybeRun() {
  try {
    const argv1 = process.argv[1] || '';
    // Normalize both sides to forward slashes for Windows
    const fromArg = `file://${argv1.replace(/\\/g, '/')}`;
    const urlPath = new URL(import.meta.url).pathname;
    const argPath = new URL(fromArg).pathname;

    const isDirect = argv1 && urlPath === argPath;
    // Fallback: if equality fails (edge cases), still run if this file name appears in argv1
    const nameMatch = argv1.replace(/\\/g, '/').endsWith('/services/api/src/workers/capiWorker.mjs');

    if (isDirect || nameMatch) {
      const args = Object.fromEntries(
        process.argv.slice(2).map(a => {
          const [k, v = true] = a.replace(/^--/, '').split('=');
          return [k, v];
        })
      );
      main(args).catch(err => {
        console.error('[FATAL]', err);
        process.exit(1);
      });
    } else {
      console.log('[DEBUG] not running main (module imported)');
    }
  } catch (e) {
    // If guard logic fails, prefer to run rather than stay silent.
    console.warn('[WARN] main guard fallback -> running main()', String(e?.message || e));
    main({}).catch(err => {
      console.error('[FATAL]', err);
      process.exit(1);
    });
  }
})();

export { main, processEvent };
