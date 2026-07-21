const fs = require('fs');
const path = require('path');
const pool = require('./pool');

const MIGRATIONS_DIR = path.join(__dirname, 'migrations');

async function migrate() {
  const client = await pool.connect();

  try {
    // 1. Tabla para llevar el registro de migraciones aplicadas
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        name       VARCHAR(255) PRIMARY KEY,
        applied_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    // 2. Qué migraciones hay en disco (ordenadas)
    const files = fs
      .readdirSync(MIGRATIONS_DIR)
      .filter((f) => f.endsWith('.sql'))
      .sort();

    // 3. Cuáles ya están aplicadas
    const { rows } = await client.query('SELECT name FROM schema_migrations');
    const applied = new Set(rows.map((r) => r.name));

    // 4. Aplicar las que faltan
    for (const file of files) {
      if (applied.has(file)) {
        console.log(`↷  ${file} (ya aplicada)`);
        continue;
      }

      const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, file), 'utf8');

      await client.query('BEGIN');
      try {
        await client.query(sql);
        await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
        await client.query('COMMIT');
        console.log(`✓  ${file}`);
      } catch (err) {
        await client.query('ROLLBACK');
        console.error(`✗  ${file}`);
        throw err;
      }
    }

    console.log('\nMigraciones al día.');
  } finally {
    client.release();
    await pool.end();
  }
}

migrate().catch((err) => {
  console.error('Error aplicando migraciones:', err.message);
  process.exit(1);
});