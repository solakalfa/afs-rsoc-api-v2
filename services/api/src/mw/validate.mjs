import { z } from "zod";

export function validate(schema) {
  return (req, res, next) => {
    const input = { body: req.body, query: req.query, headers: req.headers, params: req.params };
    const result = schema.safeParse(input);
    if (!result.success) {
      return res.status(422).json({ error: "Validation failed", details: result.error.flatten(), traceId: req.traceId });
    }
    req.valid = result.data;
    next();
  };
}