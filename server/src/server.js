import { resolve } from 'node:path';
import { createApp } from './app.js';
import { openDatabase } from './mysql_pool.js';

const port = Number.parseInt(process.env.PORT || '3000', 10);
const host = process.env.HOST || '0.0.0.0';
const origins = (process.env.ALLOWED_ORIGINS || 'http://localhost:5001,http://127.0.0.1:5001')
  .split(',').map(s => s.trim()).filter(Boolean);
const webDir = process.env.FLUTTER_WEB_DIR ? resolve(process.env.FLUTTER_WEB_DIR) : null;
const db = openDatabase();

try {
  await db.query('SELECT 1');
  const { server } = createApp({ db, allowedOrigins: origins, flutterWebDir: webDir });
  server.listen(port, host, () => {
    console.log(`GUNDUA REST API: http://localhost:${port}/api/v1/health`);
    console.log(`MySQL: ${process.env.DB_HOST || '127.0.0.1'} / ${process.env.DB_NAME || 'gundua'}`);
    if (webDir) console.log(`Flutter Web: ${webDir}`);
  });
  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, () => server.close(async () => {
      await db.end();
      process.exit(0);
    }));
  }
} catch (error) {
  console.error('Não foi possível ligar ao MySQL. Confirma server/.env e o SQL no Workbench.');
  console.error(error.message);
  await db.end();
  process.exitCode = 1;
}
