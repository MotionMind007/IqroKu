import { readdir, readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import pg from 'pg';

const { Pool } = pg;
const repoRoot = resolve(fileURLToPath(new URL('../..', import.meta.url)));

await loadEnvFile(resolve(repoRoot, 'backend/.env'));
await loadEnvFile(resolve(process.cwd(), '.env'));

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  console.error('DATABASE_URL is required to run migrations.');
  process.exit(1);
}

const migrationsDir = resolve(repoRoot, 'deploy/migrations');
const statusOnly = process.argv.includes('--status');
const pool = new Pool({
  connectionString: databaseUrl,
  max: 1,
  idleTimeoutMillis: 10_000,
  connectionTimeoutMillis: 5_000,
});

try {
  await ensureMigrationsTable();
  const files = (await readdir(migrationsDir))
    .filter((file) => file.endsWith('.sql'))
    .sort();
  const applied = await appliedMigrationNames();

  if (statusOnly) {
    for (const file of files) {
      console.log(`${applied.has(file) ? 'applied' : 'pending'} ${file}`);
    }
    process.exitCode = 0;
  } else {
    for (const file of files) {
      if (applied.has(file)) {
        console.log(`skip ${file}`);
        continue;
      }
      await runMigration(file);
    }
  }
} finally {
  await pool.end();
}

async function ensureMigrationsTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

async function appliedMigrationNames() {
  const result = await pool.query('SELECT name FROM schema_migrations');
  return new Set(result.rows.map((row) => row.name));
}

async function runMigration(file) {
  const sql = await readFile(resolve(migrationsDir, file), 'utf8');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(sql);
    await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
    await client.query('COMMIT');
    console.log(`applied ${file}`);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error(`failed ${file}: ${error.message}`);
    throw error;
  } finally {
    client.release();
  }
}

async function loadEnvFile(path) {
  if (process.env.DATABASE_URL) {
    return;
  }
  try {
    const content = await readFile(path, 'utf8');
    for (const line of content.split(/\r?\n/)) {
      if (!line.trim() || line.trimStart().startsWith('#') || !line.includes('=')) {
        continue;
      }
      const [key, ...rest] = line.split('=');
      const name = key.trim();
      const value = rest.join('=').trim();
      if (name && process.env[name] === undefined) {
        process.env[name] = value;
      }
    }
  } catch (_) {
    // Env files are optional; DATABASE_URL may already be injected by process manager.
  }
}
