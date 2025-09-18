import type { Request, Response, NextFunction } from "express";

declare global {
  namespace Express {
    // Attach traceId to request
    interface Request {
      traceId?: string;
    }
  }
}

// lightweight UUIDv4
function uuidv4(): string {
  // Prefer crypto.randomUUID if available (Node 16+)
  // @ts-ignore
  if (globalThis.crypto && typeof (globalThis.crypto as any).randomUUID === "function") {
    // @ts-ignore
    return (globalThis.crypto as any).randomUUID();
  }
  // Fallback
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => {
    const r = (Math.random() * 16) | 0;
    const v = c === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

export function traceIdMiddleware(req: Request, res: Response, next: NextFunction) {
  const headerId = req.header("x-trace-id") || req.header("x-request-id");
  const id = headerId || uuidv4();
  req.traceId = id;
  res.setHeader("X-Trace-Id", id);
  next();
}
