import express from "express";
import { db } from "../lib/db.mjs";
export const router = express.Router();

router.get("/health", async (req, res) => {
  try {
    const pool = db.pool();
    let dbOk = false;
    if (pool) {
      await pool.query("SELECT 1;");
      dbOk = true;
    }
    res.json({ ok: true, db: dbOk, now: new Date().toISOString(), traceId: req.traceId });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message, traceId: req.traceId });
  }
});