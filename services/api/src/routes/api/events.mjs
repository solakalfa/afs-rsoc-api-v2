import { Router } from "express";
import * as DB from "../lib/db.mjs";

const r = Router();

// מפעילים pool() אם קיים
const pool = typeof DB.pool === "function" ? DB.pool() : null;

r.post("/events", async (req, res) => {
  try {
    const { type, click_id, source, campaign, adset, timestamp } = req.body || {};
    if (!type || !timestamp) {
      return res.status(422).json({ error: "missing_required_fields" });
    }
    if (!pool || !pool.query) {
      return res.status(500).json({ error: "db_not_ready" });
    }

    const q = `insert into events(type, click_id, source, campaign, adset, ts)
               values ($1,$2,$3,$4,$5,$6) returning id`;
    const { rows } = await pool.query(q, [
      type,
      click_id || null,
      source || null,
      campaign || null,
      adset || null,
      timestamp,
    ]);
    return res.status(201).json({ id: rows[0].id });
  } catch (e) {
    return res.status(500).json({ error: "server_error", message: e?.message });
  }
});

r.get("/events", async (_req, res) => {
  try {
    if (!pool || !pool.query) {
      return res.status(500).json({ error: "db_not_ready" });
    }
    const { rows } = await pool.query("select * from events order by ts desc limit 50");
    return res.json(rows);
  } catch (e) {
    return res.status(500).json({ error: "server_error", message: e?.message });
  }
});

export const router = r;
