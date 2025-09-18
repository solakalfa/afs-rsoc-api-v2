import { Router, Request, Response } from "express";
import { validateBody } from "../middleware/validate";
import { trackingSchema } from "../schemas/tracking";

export const trackingRouter = Router();

trackingRouter.post("/", validateBody(trackingSchema), async (req: Request, res: Response) => {
  // TODO: persist to DB (events table), enqueue outbox if needed
  // req.body כאן כבר עבר ולידציה
  return res.status(200).json({ ok: true });
});
