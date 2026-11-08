import { openDatabase } from './mysql_pool.js';
import { seedPlaces } from './db.js';

const db = openDatabase();
try {
  await db.query('SELECT 1');
  const count = await seedPlaces(db);
  console.log(`Seed concluído: ${count} locais do catálogo GUNDUA.`);
} catch (error) {
  console.error(`Erro ao inserir os locais: ${error.message}`);
  process.exitCode = 1;
} finally {
  await db.end();
}
