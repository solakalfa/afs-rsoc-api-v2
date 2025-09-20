// services/api/src/routes/api/events.mjs
import { Router } from "express";
import * as DB from "../../lib/db.mjs";

// Fallback query detector: DB.query → DB.db.query → DB.db.pool.query
function pickQuery() {
  if (typeof DB.query === "function") return DB.query;
  if (DB.db && typeof DB.db.query === "function") return DB.db.query.bind(DB.db);
  if (DB.db && DB.db.pool && typeof DB.db.pool.query === "function") {
    return DB.db.pool.query.bind(DB.db.pool);
  }
  return null;
}

const router = Router();

router.post("/events", async (req, res) => {
  try {
    const { type, click_id, source, campaign, adset, timestamp } = req.body || {};
    if (!type || !timestamp) return res.status(422).json({ error: "missing_required_fields" });

    const query = pickQuery();
    if (!query) return res.status(500).json({ error: "db_not_ready" });

    const sql = `INSERT INTO events (type, click_id, source, campaign, adset, ts)
                 VALUES ($1,$2,$3,$4,$5,$6) RETURNING id`;
    const params = [type, click_id ?? null, source ?? null, campaign ?? null, adset ?? null, timestamp];
    const { rows } = await query(sql, params);
    return res.status(201).json({ id: rows[0]?.id ?? null });
  } catch (e) {
    return res.status(500).json({ error: "server_error", message: e?.message });
  }
});

router.get("/events", async (req, res) => {
  try {
    const query = pickQuery();
    if (!query) return res.status(500).json({ error: "db_not_ready" });

    const limit = Math.min(Number(req.query.limit || 20), 200);
    const { rows } = await query(
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
