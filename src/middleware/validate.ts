import { AnyZodObject, ZodError } from "zod";
import { Request, Response, NextFunction } from "express";

export function validateBody(schema: AnyZodObject) {
  return (req: Request, res: Response, next: NextFunction) => {
    try {
      req.body = schema.parse(req.body);
      next();
    } catch (err) {
      if (err instanceof ZodError) {
        return res.status(422).json({
          error: "Unprocessable Entity",
          issues: err.issues.map(i => ({
            path: i.path.join("."),
            message: i.message,
            code: i.code,
          })),
        });
      }
      next(err);
    }
  };
}
