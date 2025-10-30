import { Pool } from 'pg';

function resolveSslConfig() {
  const sslMode = (process.env.PGSSLMODE ?? '').toLowerCase();
  if (sslMode === 'require' || sslMode === 'verify-full') {
    return { rejectUnauthorized: false };
  }
  return undefined;
}

export function createPoolFromEnv() {
  const connectionString = process.env.DATABASE_URL;
  const max = Number.parseInt(process.env.PGPOOL_MAX ?? '10', 10);
  const idleTimeoutMillis = Number.parseInt(process.env.PGPOOL_IDLE_TIMEOUT ?? '30000', 10);

  if (connectionString) {
    return new Pool({
      connectionString,
      ssl: resolveSslConfig(),
      max,
      idleTimeoutMillis,
    });
  }

  return new Pool({
    host: process.env.PGHOST ?? '127.0.0.1',
    port: Number.parseInt(process.env.PGPORT ?? '5432', 10),
    user: process.env.PGUSER ?? 'root',
    password: process.env.PGPASSWORD,
    database: process.env.PGDATABASE ?? 'aabb',
    ssl: resolveSslConfig(),
    max,
    idleTimeoutMillis,
  });
}

export function createPool(options = {}) {
  return new Pool(options);
}
