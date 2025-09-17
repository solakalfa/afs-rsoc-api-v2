export function requireAuth(req, res, next) {
  const auth = req.headers["authorization"] || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  const expected = process.env.AUTH_TOKEN || process.env.RSOC_API_TOKEN || "";
  if (!expected) return res.status(500).json({ error: "Server misconfigured: AUTH_TOKEN missing", traceId: req.traceId });
  if (token !== expected) return res.status(401).json({ error: "Unauthorized", traceId: req.traceId });
  next();
}