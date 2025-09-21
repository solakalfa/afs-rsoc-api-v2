import { z } from "zod";

export const trackingSchema = z.object({
  event: z.literal("click").or(z.literal("view")).or(z.literal("visit")),
  clickId: z.string().min(1),
  ts: z.number().int().positive(),       // epoch ms
  userAgent: z.string().optional(),
  ip: z.string().optional(),
  meta: z.record(z.any()).optional(),
});
