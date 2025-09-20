import { Router } from "express";

// טוען את ה-DB בצורה גמישה בהתאם לאקספורים הקיימים בפרויקט
import * as DB from "../lib/db.mjs";
const pool =
  DB.pool ??
  (DB.db && DB.db.pool ? DB.db.pool : null);
const query =
  typeof DB.query === "function"
    ? DB.query
    : (pool && typeof pool.query === "function"
        ? (...args) => pool.query(...args)
        : null);

export const router = Router();

// POST /api/events
router.post("/events", async (req, res) => {
  try {
    const { type, click_id, source, campaign, adset, timestamp } = req.body || {};
    if (!type || !timestamp) {
      return res.status(422).json({ error: "missing_required_fields" });
    }
    if (!query) {
      return res.status(500).json({ error: "db_not_ready" });
    }
    const sql = `
      insert into events (type, click_id, source, campaign, adset, ts)
      values ($1,$2,$3,$4,$5,$6)
      returning id
    `;
    const { rows } = await query(sql, [
      type,
      click_id || null,
      source || null,
      campaign || null,
      adset || null,
      timestamp
    ]);
    return res.status(201).json({ id: rows[0].id });
  } catch (e) {
    return res.status(500).json({ error: "server_error", message: e?.message });
  }
});

// GET /api/events
router.get("/events", async (req, res) => {
  try {
    const limit = Math.min(Number(req.query.limit || 20), 200);
    if (!query) {
      return res.status(500).json({ error: "db_not_ready" });
    }
    const { rows } = await query(
      `select id, type, click_id, source, campaign, adset, ts as timestamp
       from events
       order by ts desc
       limit $1`,
      [limit]
    );
    return res.json(rows);
  } catch (e) {
    return res.status(500).json({ error: "server_error", message: e?.message });
  }
});
