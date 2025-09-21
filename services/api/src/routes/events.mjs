import { Router } from "express";
import * as DB from "../lib/db.mjs";

const pickQuery = () =>
  (typeof DB.query === "function" && DB.query) ||
  (DB.db && typeof DB.db.query === "function" && DB.db.query.bind(DB.db)) ||
  (DB.db && DB.db.pool && typeof DB.db.pool.query === "function" && DB.db.pool.query.bind(DB.db.pool)) ||
  null;

export const router = Router();

router.post("/events", async (req, res) => {
  try {
    const { type, click_id, source, campaign, adset, timestamp } = req.body || {};
    if (!type || !timestamp) return res.status(422).json({ error: "missing_required_fields" });
    const query = pickQuery(); if (!query) return res.status(500).json({ error: "db_not_ready" });
    const sql = `insert into events(type,click_id,source,campaign,adset,ts) values($1,$2,$3,$4,$5,$6) returning id`;
    const { rows } = await query(sql, [type, click_id ?? null, source ?? null, campaign ?? null, adset ?? null, timestamp]);
    return res.status(201).json({ id: rows[0].id });
  } catch (e) { return res.status(500).json({ error: "server_error", message: e?.message }); }
});

router.get("/events", async (req, res) => { if (!process.env.DATABASE_URL) return res.status(200).json([]);
    if (!process.env.DATABASE_URL) return res.status(200).json([]);
  try {
    const query = pickQuery(); if (!query) return res.status(500).json({ error: "db_not_ready" });
    const limit = Math.min(Number(req.query.limit || 20), 200);
    const { rows } = await query(
      `select id,type,click_id,source,campaign,adset,ts as timestamp from events order by ts desc limit $1`,
      [limit]
    );
    return res.json(rows);
  } catch (e) { return res.status(500).json({ error: "server_error", message: e?.message }); }
});
