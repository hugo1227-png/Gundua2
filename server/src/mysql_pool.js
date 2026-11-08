import mysql from 'mysql2/promise';

export function openDatabase(options = {}) {
  return mysql.createPool({
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER || 'gundua_app',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'gundua',
    waitForConnections: true,
    connectionLimit: 10,
    decimalNumbers: true,
    dateStrings: true,
    timezone: 'Z',
    ...options,
  });
}
