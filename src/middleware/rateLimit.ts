import type { Request, Response, NextFunction } from "express";

type Key = string;
interface Bucket {
  windowStart: number;
  count: number;
  limit: number;
}

const buckets = new Map<Key, Bucket>();

export interface RateRule {
  match: (req: Request) => boolean;
  limit: number;         // max requests per window
  windowMs: number;      // window length
}

// Default MVP rules
export const defaultRules: RateRule[] = [
  {
    match: (req) => req.path.startsWith("/api/convert"),
    limit: 5,          // 5 req/sec per key
    windowMs: 1000,
  },
  {
    match: (req) => req.path.startsWith("/api/tracking"),
    limit: 50,         // 50 req/sec per key
    windowMs: 1000,
  },
];

function clientKey(req: Request): string {
  const token = (req.header("authorization") || "").replace(/^Bearer\s+/i, "") || "anon";
  const ip = (req.ip || req.socket?.remoteAddress || "0.0.0.0");
  const path = req.path || req.url;
  return `${token}:${ip}:${path}`;
}

export function rateLimitMiddleware(rules: RateRule[] = defaultRules) {
  return (req: Request, res: Response, next: NextFunction) => {
    const rule = rules.find(r => r.match(req));
    if (!rule) return next();

    const key = clientKey(req);
    const now = Date.now();

    let bucket = buckets.get(key);
    if (!bucket || now - bucket.windowStart >= rule.windowMs) {
      bucket = { windowStart: now, count: 0, limit: rule.limit };
      buckets.set(key, bucket);
    }

    bucket.count += 1;
    const remaining = Math.max(0, bucket.limit - bucket.count);
    const resetInMs = rule.windowMs - (now - bucket.windowStart);

    res.setHeader("X-RateLimit-Limit", String(rule.limit));
    res.setHeader("X-RateLimit-Remaining", String(remaining));
    res.setHeader("X-RateLimit-Reset", String(Math.ceil(resetInMs / 1000)));

    if (bucket.count > rule.limit) {
      res.setHeader("Retry-After", String(Math.ceil(resetInMs / 1000)));
      return res.status(429).json({
        error: "rate_limited",
        message: "Too many requests, please retry later.",
        traceId: (req as any).traceId,
      });
    }

    next();
  };
}
