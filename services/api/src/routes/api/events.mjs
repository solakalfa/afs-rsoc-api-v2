// services/api/src/routes/api/events.mjs
import { Router } from "express";
import { db } from "../../lib/db.mjs";

/**
 * Query helper:
 * - Use db.pool() -> pg.Pool instance -> pool.query(...)
 * - If pool() not ready -> return 500 db_not_ready
 */
function getPool() {
  try {
    if (db && typeof db.pool === "function") return db.pool();
  } catch (_) { /* ignore */ }
  return null;
}

const router = Router();

// POST /api/events
router.post("/events", async (req, res) => {
  try {
    const { type, click_id, source, campaign, adset, timestamp } = req.body || {};
    if (!type || !timestamp) return res.status(422).json({ error: "missing_required_fields" });

    const pool = getPool();
    if (!pool || typeof pool.query !== "function") {
      return res.status(500).json({ error: "db_not_ready" });
    }

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

// GET /api/events
router.get("/events", async (req, res) => {
  try {
    const pool = getPool();
    if (!pool || typeof pool.query !== "function") {
      return res.status(500).json({ error: "db_not_ready" });
    }

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
