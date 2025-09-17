const UNAUTHORIZED = { error: 'Unauthorized' };

export function requireBearer(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  const expected = process.env.AUTH_TOKEN || '';
  if (expected && token !== expected) return res.status(401).json(UNAUTHORIZED);
  next();
}
