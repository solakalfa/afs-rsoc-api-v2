import { db } from "../lib/db.mjs";

/**
 * Idempotency middleware, backed by Postgres.
 * - אם יש רשומה עם תגובה -> מחזיר מיד את אותה תגובה.
 * - אם יש רשומה בלי תגובה (in-progress) -> 409.
 * - אחרת יוצר רשומה, ולוכד את res.status/res.json כדי לשמור את התשובה.
 */
export const idempotency = () => async (req, res, next) => {
  const key = req.header("Idempotency-Key");
  if (!key) return next();

  const pool = db.pool();
  if (!pool) return next();

  try {
    const found = await pool.query(
      "SELECT status, response, finished_at FROM idempotency_keys WHERE idem_key=$1",
      [key]
    );

    if (found.rows.length) {
      const row = found.rows[0];
      if (row.response) {
        return res.status(row.status || 200).json(row.response);
      }
      return res.status(409).json({ error: "In-Progress", idemKey: key });
    }

    await pool.query(
      "INSERT INTO idempotency_keys (idem_key, method, path) VALUES ($1,$2,$3)",
      [key, req.method, req.path]
    );

    // wrap to capture the outgoing response
    const origStatus = res.status.bind(res);
    const origJson = res.json.bind(res);
    let outStatus = 200;

    res.status = (code) => { outStatus = code; return origStatus(code); };
    res.json = async (body) => {
      try {
        await pool.query(
          `UPDATE idempotency_keys
           SET status=$1, response=$2, finished_at=NOW()
           WHERE idem_key=$3`,
          [outStatus, body, key]
        );
      } catch {}
      return origJson(body);
    };

    next();
  } catch {
    // לא מפיל זרימה אם ה־DB לא זמין
    next();
  }
};
