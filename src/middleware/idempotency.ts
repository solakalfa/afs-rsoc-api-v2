import type { Request, Response, NextFunction } from "express";
import crypto from "crypto";
import { pool } from "../lib/db"; // adjust path if your db module differs

interface Row {
  id: number;
  idem_key: string;
  method: string;
  path: string;
  body_hash: string;
  status_code: number | null;
  response_body: string | null;
  created_at: string;
  state: "in_progress" | "succeeded" | "failed";
}

function bodyHash(req: Request): string {
  const h = crypto.createHash("sha256");
  const raw = JSON.stringify({ body: req.body ?? {}, query: req.query ?? {} });
  h.update(raw);
  return h.digest("hex");
}

export async function idempotencyMiddleware(req: Request, res: Response, next: NextFunction) {
  const idemKey = req.header("Idempotency-Key");
  if (!idemKey) return next(); // only enforce if key present (MVP)

  const method = req.method.toUpperCase();
  const path = req.path;
  const hash = bodyHash(req);

  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const select = await client.query<Row>(
      `SELECT * FROM idempotency_keys WHERE idem_key = $1 FOR UPDATE`,
      [idemKey],
    );

    if (select.rowCount && select.rows[0]) {
      const row = select.rows[0];
      if (row.state === "succeeded" && row.response_body && row.status_code) {
        await client.query("COMMIT");
        res.setHeader("Idempotency-Replayed", "true");
        return res.status(row.status_code).type("application/json").send(row.response_body);
      } else if (row.state === "in_progress") {
        await client.query("COMMIT");
        res.setHeader("Retry-After", "3");
        return res.status(409).json({ error: "in_progress", message: "Request in progress, retry later.", traceId: (req as any).traceId });
      }
      // else: failed → allow reprocess
    } else {
      // insert new record
      await client.query(
        `INSERT INTO idempotency_keys (idem_key, method, path, body_hash, state) VALUES ($1, $2, $3, $4, 'in_progress')`,
        [idemKey, method, path, hash],
      );
    }
    await client.query("COMMIT");
  } catch (e) {
    await client.query("ROLLBACK");
    // If DB failed, we still allow the request to continue in MVP.
  } finally {
    client.release();
  }

  // Hook response to capture output if succeeds
  const originalJson = res.json.bind(res);
  const originalSend = res.send.bind(res);

  async function persist(statusCode: number, payload: any) {
    const body = typeof payload === "string" ? payload : JSON.stringify(payload);
    try {
      await pool.query(
        `UPDATE idempotency_keys
         SET status_code = $2, response_body = $3, state = 'succeeded'
         WHERE idem_key = $1`,
        [idemKey, statusCode, body],
      );
    } catch {}
  }

  res.json = ((body: any) => {
    // @ts-ignore
    const statusCode = res.statusCode || 200;
    persist(statusCode, body);
    return originalJson(body);
  }) as any;

  res.send = ((body?: any) => {
    const statusCode = res.statusCode || 200;
    persist(statusCode, body);
    return originalSend(body);
  }) as any;

  next();
}
