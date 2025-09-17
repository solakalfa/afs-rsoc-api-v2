import { randomUUID } from 'node:crypto';

export function withTraceId(req, res, next) {
  req.traceId = req.headers['x-trace-id'] || randomUUID();
  res.setHeader('x-trace-id', req.traceId);
  next();
}
