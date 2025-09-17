import { Pool } from "pg";

let pool;

function buildConfig() {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) return null;
  const instance = process.env.CLOUD_SQL_CONNECTION_NAME;
  if (instance) {
    return { connectionString: databaseUrl, ssl: false };
  }
  return { connectionString: databaseUrl, ssl: false };
}

export const db = {
  async init() {
    const cfg = buildConfig();
    if (!cfg) throw new Error("DATABASE_URL not set");
    pool = new Pool(cfg);
    await pool.query("SELECT 1;");
  },
  pool() {
    if (!pool) {
      const cfg = buildConfig();
      pool = cfg ? new Pool(cfg) : null;
    }
    return pool;
  },
};