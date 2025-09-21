// services/api/server.mjs
import dotenv from "dotenv";
dotenv.config({ path: ".env.local" });
console.log("DEBUG DATABASE_URL:", process.env.DATABASE_URL);

import express from "express";
import rateLimit from "express-rate-limit";
import { v4 as uuidv4 } from "uuid";

import { router as healthRouter } from "./src/routes/health.mjs";
import { router as trackingRouter } from "./src/routes/tracking.mjs";
import { router as convertRouter } from "./src/routes/convert.mjs";
import { router as reportingRouter } from "./src/routes/reporting.mjs";
import { router as eventsRouter } from "./src/routes/api/events.mjs";

import { db } from "./src/lib/db.mjs";

const app = express();
app.set("trust proxy", 1);
app.use(express.json({ limit: "1mb" }));

// rate limiter
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// add traceId
app.use((req, res, next) => {
  const traceId = req.headers["x-request-id"] || uuidv4();
  req.traceId = String(traceId);
  res.setHeader("x-request-id", req.traceId);
  next();
});

// basic request logger
app.use((req, _res, next) => {
  console.log(JSON.stringify({
    t: new Date().toISOString(),
    traceId: req.traceId,
    method: req.method,
    path: req.path,
    ip: req.ip,
  }));
  next();
});

// routers
app.use("/api", healthRouter);
app.use("/api", trackingRouter);
app.use("/api", convertRouter);
app.use("/api", reportingRouter);
app.use("/api", eventsRouter);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: "Not Found", traceId: req.traceId });
});

const PORT = process.env.PORT || 8080;

// init DB
db.init()
  .then(() => console.log("DB init ok"))
  .catch((e) => console.warn("DB init skip", e.message));

app.listen(PORT, () => {
  console.log(`RSOC API listening on ${PORT}`);
});

export default app;

app.use('/api/events', express.json({ limit: '8kb' }), eventsRouter);
