// Simple in-memory token bucket (per instance)
const buckets = new Map();

export function rateLimit({ windowMs = 60_000, max = 60 } = {}) {
  return (req, res, next) => {
    const key = (req.ip || req.headers['x-forwarded-for'] || 'global') + ':' + (req.path || '/');
    const now = Date.now();
    let b = buckets.get(key);
    if (!b || now - b.ts > windowMs) b = { ts: now, n: 0 };
    b.n += 1; buckets.set(key, b);
    if (b.n > max) return res.status(429).json({ error: 'Too Many Requests' });
    next();
  };
}
