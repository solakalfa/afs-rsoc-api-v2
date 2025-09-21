import { pool } from "../lib/db";
import { linearBackoff, shouldRetry } from "../lib/retry";

interface OutboxRow {
  id: number;
  trace_id: string | null;
  payload: any;
  attempt: number;
  next_run_at: string | null;
  created_at: string;
}

// Placeholder for the actual CAPI call
async function sendToMetaCapi(event: any): Promise<{ ok: boolean; status?: number; error?: any }> {
  // TODO: integrate with actual CAPI client
  return { ok: true, status: 200 };
}

export async function processOutboxBatch(limit = 20, maxAttempts = 3) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const { rows } = await client.query<OutboxRow>(
      `SELECT id, trace_id, payload, attempt, next_run_at, created_at
       FROM outbox
       WHERE (next_run_at IS NULL OR next_run_at <= NOW())
       ORDER BY created_at ASC
       LIMIT $1
       FOR UPDATE SKIP LOCKED`, [limit]
    );

    for (const row of rows) {
      const attempt = (row.attempt || 0) + 1;
      let status: number | undefined;
      let ok = false;

      try {
        const parsed = typeof row.payload === "string" ? JSON.parse(row.payload) : row.payload;
        const result = await sendToMetaCapi(parsed);
        ok = result.ok;
        status = result.status;
      } catch (e) {
        ok = false;
        status = undefined;
      }

      if (ok) {
        await client.query(`DELETE FROM outbox WHERE id = $1`, [row.id]);
        continue;
      }

      if (attempt >= maxAttempts || !shouldRetry(status)) {
        // move to DLQ
        await client.query(
          `INSERT INTO outbox_dlq (outbox_id, trace_id, payload, failed_status, attempts)
           VALUES ($1, $2, $3, $4, $5)`,
          [row.id, row.trace_id, row.payload, status ?? null, attempt]
        );
        await client.query(`DELETE FROM outbox WHERE id = $1`, [row.id]);
      } else {
        const delayMs = linearBackoff(attempt);
        await client.query(
          `UPDATE outbox SET attempt = $2, next_run_at = NOW() + ($3::text)::interval WHERE id = $1`,
          [row.id, attempt, `${Math.ceil(delayMs/1000)} seconds`]
        );
      }
    }

    await client.query("COMMIT");
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
}
