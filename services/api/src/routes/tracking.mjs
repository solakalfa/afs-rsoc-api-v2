import express from "express";
import { z } from "zod";
import { validate } from "../mw/validate.mjs";
import { requireAuth } from "../mw/auth.mjs";
import { v4 as uuidv4 } from "uuid";
import { db } from "../lib/db.mjs";

export const router = express.Router();

const TrackingSchema = z.object({
  body: z.object({
    utm_source: z.string(),
    source: z.string(),
    account_id: z.string(),
    campaign_id: z.string(),
    adset_id: z.string(),
    ad_id: z.string(),
    click_id: z.string().optional(),
    user_agent: z.string().optional(),
    ip: z.string().optional(),
    extra: z.record(z.any()).optional(),
  }),
});

router.post("/tracking", requireAuth, validate(TrackingSchema), async (req, res) => {
  const idempotencyKey = req.headers["idempotency-key"] || "";
  const id = uuidv4();
  try {
    const pool = db.pool();
    if (pool) {
      await pool.query(
        `insert into events (event_id, type, payload, idempotency_key, created_at) values ($1,$2,$3,$4,now())`,
        [id, "tracking", req.body, idempotencyKey || null]
      );
    }
  } catch (e) {
    console.warn("tracking insert failed", e.message);
  }
  res.status(201).json({ id, status: "accepted", idempotencyKey, traceId: req.traceId });
});