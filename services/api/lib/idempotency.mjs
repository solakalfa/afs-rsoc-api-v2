// Minimal in-memory idempotency cache (per instance)
const store = new Map();

export function idempotent(handler) {
  return async (req, res, next) => {
    const key = req.headers['idempotency-key'];
    if (!key) return handler(req, res, next);
    if (store.has(key)) return res.json(store.get(key));
    const originalJson = res.json.bind(res);
    res.json = (payload) => { store.set(key, payload); return originalJson(payload); };
    try { return await handler(req, res, next); }
    catch (e) { return next(e); }
  };
}
