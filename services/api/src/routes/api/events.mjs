// services/api/src/routes/api/events.mjs
import { Router } from "express";
import { db } from "../../lib/db.mjs";

/**
 * Pick a working query function from the db layer.
 * Prefer db.query; fallback to db.pool.query.
 */
function getQuery() {
  if (db && typeof db.query === "function") return db.query.bind(db);
  if (db && db.pool && typeof db.pool.query === "function") return db.pool.query.bind(db.pool);
  return null;
}

const router = Router();

// POST /api/events
router.post("/events", async (req, res) => {
  try {
    const { type, click_id, source, campaign, adset, timestamp } = req.body || {};
    if (!type || !timestamp) return res.status(422).json({ error: "missing_required_fields" });

    const query = getQuery();
    if (!query) return res.status(500).json({ error: "db_not_ready" });

    const sql = `
      INSERT INTO events (type, click_id, source, campaign, adset, ts)
      VALUES ($1,$2,$3,$4,$5,$6)
      RETURNING id
    `;
    const params = [
      type,
      click_id ?? null,
      source ?? null,
      campaign ?? null,
      adset ?? null,
      timestamp,
    ];
    const { rows } = await query(sql, params);
    return res.status(201).json({ id: rows[0]?.id ?? null });
  } catch (e) {
    return res.status(500).json({ error: "server_error", message: e?.message });
  }
});

// GET /api/events
router.get("/events", async (req, res) => {
  try {
    const query = getQuery();
    if (!query) return res.status(500).json({ error: "db_not_ready" });

    const limit = Math.min(Number(req.query.limit || 20), 200);
    const { rows } = await query(
      `
        SELECT id, type, click_id, source, campaign, adset, ts AS timestamp
        FROM events
        ORDER BY ts DESC
        LIMIT $1
      `,
      [limit]
    );
    return res.json(rows);
  } catch (e) {
    return res.status(500).json({ error: "server_error", message: e?.message });
  }
});

export default router;
