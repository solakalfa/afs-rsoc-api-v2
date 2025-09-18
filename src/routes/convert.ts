import { Router, Request, Response } from "express";
import { validateBody } from "../middleware/validate";
import { convertSchema } from "../schemas/convert";

export const convertRouter = Router();

convertRouter.post("/", validateBody(convertSchema), async (req: Request, res: Response) => {
  // TODO: insert conversion, set outbox item for CAPI worker
  return res.status(200).json({ ok: true });
});
