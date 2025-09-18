import { z } from "zod";

export const convertSchema = z.object({
  event: z.literal("conversion"),
  clickId: z.string().min(1),
  convType: z.string().min(1),           // e.g. "lead","purchase"
  value: z.number().nonnegative().optional(),
  currency: z.string().length(3).optional(),
  ts: z.number().int().positive(),       // epoch ms
  meta: z.record(z.any()).optional(),
});
