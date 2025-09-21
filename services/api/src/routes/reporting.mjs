import express from "express";
import { requireAuth } from "../mw/auth.mjs";

export const router = express.Router();

router.get("/reporting", requireAuth, async (req, res) => {
  res.status(501).json({ error: "Not implemented yet", traceId: req.traceId });
});