// Verifica/limpia exclusivamente UUID y operador de un manifiesto de pruebas.
const fs = require('node:fs');
const path = require('node:path');
const backend = process.env.SYNC_BACKEND_ROOT || 'C:/Trabajo/nuevo 4/Api-Node/Backend';
const mysql = require(path.join(backend, 'node_modules/mysql2/promise'));
const config = require(path.join(backend, 'config/config.json')).development;
const tables = {
  tal_largo: 'Operacion_tal_largo', tal_horizontal: 'Operacion_tal_horizontal',
  empernador: 'Operacion_empernador', carguio: 'Operacion_carguio',
  rompebanco: 'Operacion_rompebanco', scissor: 'Operacion_scissor',
  anfochanger: 'Operacion_anfochanger', scalamin: 'Operacion_scalamin',
  dumper: 'Operacion_dumper', volquetes: 'Operacion_Volquetes',
};
async function main() {
  const [mode, manifestPath] = process.argv.slice(2);
  if (!['probe', 'verify', 'cleanup'].includes(mode)) throw new Error('Modo invalido');
  const connection = await mysql.createConnection({
    host: config.host, port: config.port, user: config.username,
    password: config.password, database: config.database, connectTimeout: 15000,
  });
  try {
    if (mode === 'probe') {
      await connection.query('SELECT 1');
      console.log('Conexion disponible para verificar y limpiar pruebas.');
      return;
    }
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    if (!manifest.marker?.startsWith('CODEX_SYNC_TEST_') || !Array.isArray(manifest.rows)) {
      throw new Error('Manifiesto invalido');
    }
    let count = 0;
    for (const row of manifest.rows) {
      const table = tables[row.type];
      if (!table || !/^[0-9a-f-]{36}$/.test(row.uuid)) throw new Error('Registro invalido');
      if (mode === 'cleanup') {
        const [result] = await connection.execute(
          `DELETE FROM \`${table}\` WHERE sync_uuid = ? AND operador = ?`,
          [row.uuid, manifest.marker],
        );
        count += result.affectedRows;
        const [remaining] = await connection.execute(
          `SELECT COUNT(*) AS n FROM \`${table}\` WHERE sync_uuid = ?`, [row.uuid],
        );
        if (Number(remaining[0].n) !== 0) throw new Error('No se pudo limpiar un UUID de prueba');
      } else {
        const [found] = await connection.execute(
          `SELECT id, operador, estado, registros FROM \`${table}\` WHERE sync_uuid = ?`, [row.uuid],
        );
        if (found.length !== 1 || found[0].operador !== manifest.marker ||
            Number(found[0].id) !== row.cloudId || found[0].estado !== 'cerrado' ||
            !String(found[0].registros).includes('version-local-actual')) {
          throw new Error('Verificacion remota fallida para ' + row.type);
        }
        count++;
      }
    }
    if (mode === 'cleanup') {
      manifest.cleanupComplete = true;
      manifest.cleanedAt = new Date().toISOString();
      fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
    }
    console.log(JSON.stringify({ mode, checked: manifest.rows.length, rows: count }));
  } finally {
    await connection.end();
  }
}
main().catch(error => {
  console.error('No se completo la operacion de prueba:', error.code || error.message);
  process.exitCode = 1;
});
