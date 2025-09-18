import express from "express";
import { requireAuth } from "./middleware/auth";
import { trackingRouter } from "./routes/tracking";
import { convertRouter } from "./routes/convert";

const app = express();
app.use(express.json());

// Auth first
app.use(requireAuth);

// Routes
app.use("/api/tracking", trackingRouter);
app.use("/api/convert", convertRouter);

export default app;
