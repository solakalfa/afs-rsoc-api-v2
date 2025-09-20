import { Router } from "express";

// טעינת pool בצורה סלחנית: אם יש export בשם pool נשתמש בו,
// ואם יש פונקציה getPool() נזמן אותה.
import * as db from "../../lib/db.mjs";
const pool = db.pool ?? (typeof db.getPool === "function" ? db.getPool() : null);

const r = Router();

r.post("/", async (req, res) => {
  try {
    const { type, click_id, source, campaign, adset, timestamp } = req.body || {};
    if (!type || !timestamp) return res.status(422).json({ error: "missing_required_fields" });
    if (!pool) return res.status(500).json({ error: "db_not_ready" });

    const q = `insert into events(type, click_id, source, campaign, adset, ts)
               values ($1,$2,$3,$4,$5,$6) returning id`;
    const { rows } = await pool.query(q, [
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

r.get("/", async (req, res) => {
  try {
    const limit = Math.min(Number(req.query.limit || 20), 200);
    if (!pool) return res.status(500).json({ error: "db_not_ready" });

    const { rows } = await pool.query(
      `select id, type, click_id, source, campaign, adset, ts as timestamp
       from events order by ts desc limit $1`,
      [limit]
    );
    return res.json(rows);
  } catch (e) {
    return res.status(500).json({ error: "server_error", message: e?.message });
  }
});

export default r;
