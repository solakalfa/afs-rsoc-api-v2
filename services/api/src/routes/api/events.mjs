// services/api/src/routes/api/events.mjs
import { Router } from "express";
import * as DB from "../../lib/db.mjs";
import pg from "pg";

let localPool = null;
function getPool() {
  // 1) אם לשכבת ה-DB שלכם יש pool() תקין – נשתמש בו
  try {
    if (DB && typeof DB.pool === "function") {
      const p = DB.pool();
      if (p && typeof p.query === "function") return p;
    }
  } catch (_) {}
  // 2) אחרת, נקים Pool עצמאי מה-ENV (פעם אחת)
  if (!localPool) {
    const url = process.env.DATABASE_URL;
    if (!url) return null;
    localPool = new pg.Pool({ connectionString: url });
  }
  return localPool;
}

const router = Router();

router.post("/events", async (req, res) => {
  try {
    const { type, click_id, source, campaign, adset, timestamp } = req.body || {};
    if (!type || !timestamp) return res.status(422).json({ error: "missing_required_fields" });

    const pool = getPool();
    if (!pool) return res.status(500).json({ error: "db_not_ready" });

    const sql = `INSERT INTO events (type, click_id, source, campaign, adset, ts)
                 VALUES ($1,$2,$3,$4,$5,$6) RETURNING id`;
    const params = [
      type,
      click_id ?? null,
      source ?? null,
      campaign ?? null,
      adset ?? null,
      timestamp,
    ];
    const { rows } = await pool.query(sql, params);
    return res.status(201).json({ id: rows[0]?.id ?? null });
  } catch (e) {
    return res.status(500).json({ error: "server_error", message: e?.message });
  }
});

router.get("/events", async (req, res) => {
  try {
    const pool = getPool();
    if (!pool) return res.status(500).json({ error: "db_not_ready" });

    const limit = Math.min(Number(req.query.limit || 20), 200);
    const { rows } = await pool.query(
      `SELECT id, type, click_id, source, campaign, adset, ts AS timestamp
       FROM events
       ORDER BY ts DESC
       LIMIT $1`,
      [limit]
    );
    return res.json(rows);
  } catch (e) {
    return res.status(500).json({ error: "server_error", message: e?.message });
  }
});

export default router;
