// Minimal Bearer auth: expects "Authorization: Bearer <token>"
import { Request, Response, NextFunction } from "express";

const REQUIRED = process.env.RSOC_API_TOKEN_STG; // adjust env if needed

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.header("authorization") || "";
  const match = header.match(/^Bearer (.+)$/i);
  if (!match) return res.status(401).json({ error: "Unauthorized" });
  const token = match[1];
  if (!REQUIRED || token !== REQUIRED) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  return next();
}
