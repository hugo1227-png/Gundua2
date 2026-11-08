import { randomBytes, randomUUID, createHash, scrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { InputError, one, execute } from './db.js';

const derive = promisify(scrypt);
const digest = value => createHash('sha256').update(value).digest('hex');
const publicUser = row => ({
  id: row.id, name: row.name, email: row.email, username: row.username,
  bio: row.bio, location: row.location, interests: row.interests,
  avatar: row.avatar ?? '', createdAt: row.created_at,
});

export async function requireUser(db, request) {
  const value = request.headers.authorization ?? '';
  if (!value.startsWith('Bearer ')) throw new InputError('Inicia sessão primeiro.', 401);
  const token = value.slice(7).trim();
  if (!/^[a-f0-9]{64}$/.test(token)) throw new InputError('Sessão inválida.', 401);
  const user = await one(db, `SELECT users.* FROM sessions
    INNER JOIN users ON sessions.user_id=users.id
    WHERE sessions.token_hash=? AND sessions.expires_at > UTC_TIMESTAMP(3)`, [digest(token)]);
  if (!user) throw new InputError('Sessão expirada ou inválida.', 401);
  return user;
}

async function newSession(db, userId) {
  const token = randomBytes(32).toString('hex');
  const expiry = new Date(Date.now() + 14 * 86_400_000);
  await execute(db, 'INSERT INTO sessions (token_hash,user_id,expires_at) VALUES (?,?,?)',
    [digest(token), userId, expiry]);
  return token;
}

export async function register(db, data) {
  const name = String(data.name ?? '').trim();
  const email = String(data.email ?? '').trim().toLowerCase();
  const password = String(data.password ?? '');
  if (!name || name.length > 100) throw new InputError('Indica um nome válido.');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    throw new InputError('Indica um email válido.');
  }
  if (password.length < 8 || password.length > 200) {
    throw new InputError('A palavra-passe deve ter entre 8 e 200 caracteres.');
  }
  const salt = randomBytes(16).toString('hex');
  const hash = (await derive(password, salt, 64)).toString('hex');
  const id = randomUUID();
  try {
    await execute(db, `INSERT INTO users (id,email,password_hash,password_salt,name)
      VALUES (?,?,?,?,?)`, [id, email, hash, salt, name]);
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') throw new InputError('Este email já está registado.', 409);
    throw error;
  }
  const user = await one(db, 'SELECT * FROM users WHERE id=?', [id]);
  return { token: await newSession(db, id), user: publicUser(user) };
}

export async function login(db, data) {
  const email = String(data.email ?? '').trim().toLowerCase();
  const password = String(data.password ?? '');
  const user = await one(db, 'SELECT * FROM users WHERE email=?', [email]);
  const hash = await derive(password, user?.password_salt ?? 'gundua-placeholder', 64);
  const expected = Buffer.from(user?.password_hash ?? '00'.repeat(64), 'hex');
  if (!user || !timingSafeEqual(hash, expected)) {
    throw new InputError('Email ou palavra-passe inválidos.', 401);
  }
  return { token: await newSession(db, user.id), user: publicUser(user) };
}

export async function logout(db, request) {
  const token = request.headers.authorization?.slice(7).trim() ?? '';
  await execute(db, 'DELETE FROM sessions WHERE token_hash=?', [digest(token)]);
}

export const me = publicUser;
