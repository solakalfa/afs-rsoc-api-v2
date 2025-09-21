import { Pool } from "pg";

const {
  DATABASE_URL,
  PGHOST,
  PGPORT,
  PGUSER,
  PGPASSWORD,
  PGDATABASE,
  NODE_ENV,
} = process.env as Record<string, string | undefined>;

// Prefer single DATABASE_URL; fallback to discrete vars.
const connectionString =
  DATABASE_URL ||
  (PGHOST &&
    `postgres://${encodeURIComponent(PGUSER ?? "")}:${encodeURIComponent(PGPASSWORD ?? "")}@${PGHOST}:${PGPORT ?? "5432"}/${PGDATABASE ?? ""}`) ||
  undefined;

if (!connectionString) {
  // Fail fast so misconfig is obvious
  // You can handle differently if desired
  throw new Error("Postgres config missing. Set DATABASE_URL or PG* env vars.");
}

// For GCP/Cloud Run with sslmode=require (e.g., Cloud SQL with proxy-less)
const ssl =
  (process.env.PGSSLMODE || "").toLowerCase() in { require: 1, "true": 1 }
    ? { rejectUnauthorized: false }
    : undefined;

export const pool = new Pool({
  connectionString,
  ssl,
  max: Number(process.env.PGPOOL_MAX ?? 10),
  idleTimeoutMillis: Number(process.env.PG_IDLE_TIMEOUT ?? 30000),
});

// Convenience health check
export async function dbPing() {
  const { rows } = await pool.query("select 1 as ok");
  return rows[0]?.ok === 1;
}
