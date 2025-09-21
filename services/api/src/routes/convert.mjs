import express from "express";
import { z } from "zod";
import { validate } from "../mw/validate.mjs";
import { requireAuth } from "../mw/auth.mjs";
import { v4 as uuidv4 } from "uuid";
import { db } from "../lib/db.mjs";

export const router = express.Router();

const ConvertSchema = z.object({
  body: z.object({
    click_id: z.string(),
    value: z.number().nonnegative().optional(),
    currency: z.string().length(3).optional(),
    meta: z.record(z.any()).optional(),
  }),
});

router.post("/convert", requireAuth, validate(ConvertSchema), async (req, res) => {
  const idempotencyKey = req.headers["idempotency-key"] || "";
  const id = uuidv4();
  try {
    const pool = db.pool();
    if (pool) {
      await pool.query(
        `insert into conversions (conversion_id, click_id, payload, idempotency_key, created_at) values ($1,$2,$3,$4,now())`,
        [id, req.body.click_id, req.body, idempotencyKey || null]
      );
    }
  } catch (e) {
    console.warn("convert insert failed", e.message);
  }
  res.status(201).json({ id, status: "accepted", idempotencyKey, traceId: req.traceId });
});