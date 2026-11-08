import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
import { createReadStream, existsSync, statSync } from 'node:fs';
import { resolve, extname, sep } from 'node:path';
import { URL } from 'node:url';
import { one, many, execute, savePlace, placeFromRow, InputError } from './db.js';
import { requireUser, register, login, logout, me } from './auth.js';
import { geoSearch, geoNearby } from './geoapify.js';
import { googleNearby } from './google_places.js';

function respond(res, status, payload) {
  if (status === 204) {
    res.writeHead(204);
    res.end();
    return;
  }
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  res.end(JSON.stringify(payload));
}

async function readBody(req) {
  if (!String(req.headers['content-type'] ?? '').includes('application/json')) {
    throw new InputError('Content-Type deve ser application/json.', 415);
  }
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > 1_500_000) throw new InputError('Pedido demasiado grande.', 413);
    chunks.push(chunk);
  }
  try {
    const data = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!data || typeof data !== 'object' || Array.isArray(data)) throw Error();
    return data;
  } catch (_) {
    throw new InputError('JSON inválido.');
  }
}

const validId = raw => {
  const value = decodeURIComponent(raw);
  if (!value || value.length > 300) throw new InputError('Identificador inválido.');
  return value;
};

async function getPlace(db, id) {
  return placeFromRow(await one(db, 'SELECT * FROM places WHERE id=?', [id]));
}

// Os nomes de tabela/coluna são constantes do próprio servidor, nunca da URL.
async function myPlaces(db, table, userId, orderColumn) {
  const rows = await many(db, `SELECT places.* FROM ${table}
    JOIN places ON places.id=${table}.place_id
    WHERE ${table}.user_id=? ORDER BY ${table}.${orderColumn} DESC`, [userId]);
  return rows.map(placeFromRow);
}

function reviewOut(row) {
  return {
    placeId: row.place_id,
    place: { ...(typeof row.data_json === 'string' ? JSON.parse(row.data_json) : row.data_json),
      gunduaId: row.place_id },
    rating: row.rating,
    comment: row.comment,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function experienceOut(row) {
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    authorName: row.author_name,
    placeId: row.place_id,
    placeName: row.place_name,
    placeLocation: row.place_location,
    placeLatitude: row.latitude == null ? null : String(row.latitude),
    placeLongitude: row.longitude == null ? null : String(row.longitude),
    imageBase64: row.image_base64,
    createdAt: row.created_at,
  };
}

const types = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.json': 'application/json; charset=utf-8',
  '.png': 'image/png', '.jpeg': 'image/jpeg', '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.webp': 'image/webp',
  '.wasm': 'application/wasm', '.ttf': 'font/ttf', '.otf': 'font/otf',
};

function serveFlutterWeb(req, res, directory, pathname) {
  if (!directory || !['GET', 'HEAD'].includes(req.method)) return false;
  let decoded;
  try { decoded = decodeURIComponent(pathname); } catch (_) { return false; }
  const root = resolve(directory);
  let filename = resolve(root, `.${decoded}`);
  if (filename !== root && !filename.startsWith(root + sep)) return false;
  if (existsSync(filename) && statSync(filename).isDirectory()) {
    filename = resolve(filename, 'index.html');
  }
  if (!existsSync(filename) || !statSync(filename).isFile()) {
    if (extname(filename)) return false;
    filename = resolve(root, 'index.html');
  }
  if (!existsSync(filename) || !statSync(filename).isFile()) return false;
  res.writeHead(200, {
    'Content-Type': types[extname(filename)] ?? 'application/octet-stream',
    'Cache-Control': 'no-cache',
  });
  if (req.method === 'HEAD') { res.end(); return true; }
  createReadStream(filename).pipe(res);
  return true;
}

/** Recebe um pool mysql2/promise. Nenhum estado fica guardado na memória do Node. */
export function createApp({ db, allowedOrigins = [], flutterWebDir = null } = {}) {
  if (!db) throw new Error('A pool MySQL é obrigatória.');
  const origins = new Set(allowedOrigins);
  // Budget guard: up to 60 Google Places requests per session per minute.
  const googleRequests = new Map();

  const server = createServer(async (req, res) => {
    try {
      const origin = req.headers.origin;
      if (origin) {
        let sameOrigin = false;
        try { sameOrigin = new URL(origin).host === req.headers.host; } catch (_) { /* origem inválida */ }
        if (!sameOrigin && !origins.has(origin)) {
          return respond(res, 403, { error: 'Origem não autorizada. Configura ALLOWED_ORIGINS.' });
        }
        res.setHeader('Access-Control-Allow-Origin', origin);
        res.setHeader('Vary', 'Origin');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
      }
      if (req.method === 'OPTIONS') return respond(res, 204);
      const url = new URL(req.url, 'http://localhost');
      const path = url.pathname;
      const method = req.method;

      if (method === 'GET' && path === '/api/v1/health') {
        await db.query('SELECT 1');
        return respond(res, 200, { service: 'gundua-api', status: 'ok', database: 'mysql' });
      }
      if (path === '/api/v1/auth/register' && method === 'POST') {
        return respond(res, 201, await register(db, await readBody(req)));
      }
      if (path === '/api/v1/auth/login' && method === 'POST') {
        return respond(res, 200, await login(db, await readBody(req)));
      }
      if (path === '/api/v1/geo/search' && method === 'GET') {
        return respond(res, 200, { items: await geoSearch(url.searchParams.get('q')), source: 'geoapify' });
      }
      if (path === '/api/v1/geo/nearby' && method === 'GET') {
        return respond(res, 200, await geoNearby(db, url.searchParams));
      }
      if (path === '/api/v1/places/google/nearby' && method === 'POST') {
        // Google Places costs money. The proxy is limited to signed-in users.
        const user = await requireUser(db, req);
        const session = String(user.id);
        const now = Date.now();
        const usage = googleRequests.get(session);
        const count = usage && now - usage.since < 60000 ? usage.count : 0;
        if (count >= 60) return respond(res, 429, { error: 'Limite temporário de pesquisas atingido.' });
        googleRequests.set(session, { since: count ? usage.since : now, count: count + 1 });
        if (googleRequests.size > 1000) {
          for (const [token, item] of googleRequests) {
            if (now - item.since >= 60000) googleRequests.delete(token);
          }
        }
        return respond(res, 200, await googleNearby(await readBody(req)));
      }
      if (path === '/api/v1/places' && method === 'GET') {
        const q = (url.searchParams.get('q') ?? '').trim().slice(0, 100);
        const category = (url.searchParams.get('category') ?? '').trim().slice(0, 100);
        const limit = Math.min(100, Math.max(1, parseInt(url.searchParams.get('limit') ?? '25', 10) || 25));
        const rows = await many(db, `SELECT * FROM places WHERE name LIKE ? AND category LIKE ?
          ORDER BY name ASC LIMIT ?`, [`%${q}%`, `%${category}%`, limit]);
        return respond(res, 200, { items: rows.map(placeFromRow), count: rows.length });
      }
      const placeMatch = path.match(/^\/api\/v1\/places\/([^/]+)$/);
      if (placeMatch && method === 'GET') {
        const place = await getPlace(db, validId(placeMatch[1]));
        return respond(res, place ? 200 : 404, place ?? { error: 'Local não encontrado.' });
      }
      const placeExperiencesMatch = path.match(/^\/api\/v1\/places\/([^/]+)\/experiences$/);
      if (placeExperiencesMatch && method === 'GET') {
        const id = validId(placeExperiencesMatch[1]);
        const rows = await many(db, `SELECT e.*, u.name AS author_name,
          p.name AS place_name, p.latitude, p.longitude
          FROM experiences e JOIN users u ON u.id=e.user_id
          JOIN places p ON p.id=e.place_id
          WHERE e.place_id=? ORDER BY e.created_at DESC LIMIT 100`, [id]);
        return respond(res, 200, { items: rows.map(experienceOut) });
      }
      if (path === '/api/v1/places' && method === 'POST') {
        await requireUser(db, req);
        const id = await savePlace(db, (await readBody(req)).place);
        return respond(res, 201, await getPlace(db, id));
      }
      const placeReviewsMatch = path.match(/^\/api\/v1\/places\/([^/]+)\/reviews$/);
      if (placeReviewsMatch && method === 'GET') {
        const id = validId(placeReviewsMatch[1]);
        if (!await getPlace(db, id)) return respond(res, 404, { error: 'Local não encontrado.' });
        const rows = await many(db, `SELECT reviews.rating, reviews.comment, reviews.created_at,
          users.name AS author FROM reviews JOIN users ON reviews.user_id=users.id
          WHERE reviews.place_id=? ORDER BY reviews.updated_at DESC LIMIT 100`, [id]);
        return respond(res, 200, { items: rows.map(r => ({
          rating: r.rating, comment: r.comment, author: r.author, createdAt: r.created_at,
        })) });
      }

      if (path.startsWith('/api/v1/me') || path === '/api/v1/auth/logout') {
        const user = await requireUser(db, req);
        if (path === '/api/v1/auth/logout' && method === 'POST') {
          await logout(db, req);
          return respond(res, 204);
        }
        if (path === '/api/v1/me' && method === 'GET') return respond(res, 200, { user: me(user) });
        if (path === '/api/v1/me' && method === 'PATCH') {
          const body = await readBody(req);
          const fields = [];
          const args = [];
          for (const field of ['name', 'username', 'bio', 'location', 'interests', 'avatar']) {
            if (body[field] === undefined) continue;
            const max = { name: 100, username: 80, bio: 500, location: 200,
              interests: 500, avatar: 1_000_000 }[field];
            if (typeof body[field] !== 'string' || body[field].length > max) {
              throw new InputError(`Campo ${field} inválido.`);
            }
            if (field === 'name' && !body.name.trim()) throw new InputError('Nome obrigatório.');
            fields.push(`${field}=?`);
            args.push(body[field].trim());
          }
          if (fields.length) await execute(db, `UPDATE users SET ${fields.join(',')} WHERE id=?`, [...args, user.id]);
          const updated = await one(db, 'SELECT * FROM users WHERE id=?', [user.id]);
          return respond(res, 200, { user: me(updated) });
        }
        if (path === '/api/v1/me/location') {
          if (method === 'GET') {
            const row = await one(db, 'SELECT * FROM selected_locations WHERE user_id=?', [user.id]);
            return respond(res, 200, { location: row ? {
              label: row.label, latitude: row.latitude, longitude: row.longitude,
              isDeviceLocation: Boolean(row.is_device_location),
            } : null });
          }
          if (method === 'PUT') {
            const body = await readBody(req);
            const { label, latitude, longitude, isDeviceLocation = false } = body;
            if (typeof label !== 'string' || !label.trim() || label.length > 200 ||
                !Number.isFinite(latitude) || Math.abs(latitude) > 90 ||
                !Number.isFinite(longitude) || Math.abs(longitude) > 180 ||
                typeof isDeviceLocation !== 'boolean') {
              throw new InputError('Localização inválida.');
            }
            await execute(db, `INSERT INTO selected_locations
              (user_id,label,latitude,longitude,is_device_location) VALUES (?,?,?,?,?)
              ON DUPLICATE KEY UPDATE label=VALUES(label), latitude=VALUES(latitude),
              longitude=VALUES(longitude), is_device_location=VALUES(is_device_location),
              updated_at=CURRENT_TIMESTAMP(3)`,
            [user.id, label.trim(), latitude, longitude, isDeviceLocation ? 1 : 0]);
            return respond(res, 200, { location: body });
          }
          if (method === 'DELETE') {
            await execute(db, 'DELETE FROM selected_locations WHERE user_id=?', [user.id]);
            return respond(res, 204);
          }
        }
        if (path === '/api/v1/me/favorites') {
          if (method === 'GET') {
            return respond(res, 200, { items: await myPlaces(db, 'favorites', user.id, 'created_at') });
          }
          if (method === 'POST') {
            const id = await savePlace(db, (await readBody(req)).place);
            await execute(db, `INSERT IGNORE INTO favorites(user_id,place_id) VALUES (?,?)`, [user.id, id]);
            return respond(res, 201, { favorite: true, placeId: id });
          }
        }
        const favMatch = path.match(/^\/api\/v1\/me\/favorites\/([^/]+)$/);
        if (favMatch && method === 'DELETE') {
          await execute(db, 'DELETE FROM favorites WHERE user_id=? AND place_id=?',
            [user.id, validId(favMatch[1])]);
          return respond(res, 204);
        }
        if (path === '/api/v1/me/visits') {
          if (method === 'GET') {
            return respond(res, 200, { items: await myPlaces(db, 'visits', user.id, 'visited_at') });
          }
          if (method === 'POST') {
            const id = await savePlace(db, (await readBody(req)).place);
            await execute(db, 'INSERT IGNORE INTO visits(user_id,place_id) VALUES (?,?)', [user.id, id]);
            return respond(res, 201, { visited: true, placeId: id });
          }
        }
        const visitMatch = path.match(/^\/api\/v1\/me\/visits\/([^/]+)$/);
        if (visitMatch && method === 'DELETE') {
          await execute(db, 'DELETE FROM visits WHERE user_id=? AND place_id=?',
            [user.id, validId(visitMatch[1])]);
          return respond(res, 204);
        }
        if (path === '/api/v1/me/views' && method === 'POST') {
          const id = await savePlace(db, (await readBody(req)).place);
          await execute(db, 'INSERT INTO page_views (user_id,place_id) VALUES (?,?)', [user.id, id]);
          return respond(res, 201, { recorded: true });
        }
        if (path === '/api/v1/me/experiences') {
          if (method === 'GET') {
            const rows = await many(db, `SELECT e.*, u.name AS author_name,
              p.name AS place_name, p.latitude, p.longitude
              FROM experiences e JOIN users u ON u.id=e.user_id
              JOIN places p ON p.id=e.place_id
              WHERE e.user_id=? ORDER BY e.created_at DESC LIMIT 100`, [user.id]);
            return respond(res, 200, { items: rows.map(experienceOut) });
          }
          if (method === 'POST') {
            const body = await readBody(req);
            const title = typeof body.title === 'string' ? body.title.trim() : '';
            const description = typeof body.description === 'string' ? body.description.trim() : '';
            const placeLocation = typeof body.placeLocation === 'string'
              ? body.placeLocation.trim() : '';
            const imageBase64 = body.imageBase64 == null ? null : body.imageBase64;
            if (!title || title.length > 160 || !description || description.length > 2000 ||
                placeLocation.length > 250 ||
                (imageBase64 !== null && (typeof imageBase64 !== 'string' ||
                  imageBase64.length > 1_000_000 ||
                  !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(imageBase64)))) {
              throw new InputError('Confirma o título, a descrição e a fotografia da experiência.');
            }
            const id = await savePlace(db, body.place);
            const experienceId = randomUUID();
            await execute(db, `INSERT INTO experiences
              (id,user_id,place_id,title,description,place_location,image_base64)
              VALUES (?,?,?,?,?,?,?)`,
            [experienceId, user.id, id, title, description, placeLocation, imageBase64]);
            return respond(res, 201, { id: experienceId });
          }
        }
        const experienceMatch = path.match(/^\/api\/v1\/me\/experiences\/([^/]+)$/);
        if (experienceMatch && method === 'DELETE') {
          const id = validId(experienceMatch[1]);
          await execute(db, 'DELETE FROM experiences WHERE id=? AND user_id=?', [id, user.id]);
          return respond(res, 204);
        }
        if (path === '/api/v1/me/reviews' && method === 'GET') {
          const rows = await many(db, `SELECT reviews.*,places.data_json FROM reviews
            JOIN places ON places.id=reviews.place_id WHERE reviews.user_id=?
            ORDER BY reviews.updated_at DESC`, [user.id]);
          return respond(res, 200, { items: rows.map(reviewOut) });
        }
        const reviewMatch = path.match(/^\/api\/v1\/me\/reviews\/([^/]+)$/);
        if (reviewMatch) {
          const id = validId(reviewMatch[1]);
          if (method === 'GET') {
            const row = await one(db, `SELECT reviews.*,places.data_json FROM reviews
              JOIN places ON places.id=reviews.place_id
              WHERE reviews.user_id=? AND reviews.place_id=?`, [user.id, id]);
            return respond(res, row ? 200 : 404,
              row ? reviewOut(row) : { error: 'Ainda não avaliaste este local.' });
          }
          if (method === 'PUT') {
            const body = await readBody(req);
            const { rating } = body;
            const comment = typeof body.comment === 'string' ? body.comment.trim() : '';
            if (!Number.isInteger(rating) || rating < 1 || rating > 5 || !comment || comment.length > 600) {
              throw new InputError('Avaliação inválida (1–5 estrelas e comentário até 600 caracteres).');
            }
            const actualId = await savePlace(db, body.place);
            if (actualId !== id) throw new InputError('O ID do local não coincide com o pedido.');
            await execute(db, `INSERT INTO reviews(user_id,place_id,rating,comment) VALUES (?,?,?,?)
              ON DUPLICATE KEY UPDATE rating=VALUES(rating), comment=VALUES(comment),
              updated_at=CURRENT_TIMESTAMP(3)`, [user.id, id, rating, comment]);
            return respond(res, 200, { saved: true, placeId: id });
          }
          if (method === 'DELETE') {
            await execute(db, 'DELETE FROM reviews WHERE user_id=? AND place_id=?', [user.id, id]);
            return respond(res, 204);
          }
        }
      }
      if (path === '/api/v1/analytics/weekly' && method === 'GET') {
        const metric = url.searchParams.get('metric') === 'visits' ? 'visits' : 'views';
        const table = metric === 'visits' ? 'visits' : 'page_views';
        const timeField = metric === 'visits' ? 'visited_at' : 'viewed_at';
        const top = await one(db, `SELECT place_id, COUNT(*) AS interactions FROM ${table}
          WHERE ${timeField} >= UTC_TIMESTAMP(3) - INTERVAL 7 DAY
          GROUP BY place_id ORDER BY interactions DESC, place_id ASC LIMIT 1`);
        return respond(res, 200, {
          period: 'last_7_days',
          metric: metric === 'visits' ? 'self_reported_visits' : 'detail_page_views',
          result: top ? { place: await getPlace(db, top.place_id), count: Number(top.interactions) } : null,
        });
      }
      if (!path.startsWith('/api/') && serveFlutterWeb(req, res, flutterWebDir, path)) return;
      return respond(res, 404, { error: 'Endpoint não encontrado.' });
    } catch (error) {
      if (!(error instanceof InputError)) console.error('[GUNDUA API]', error);
      if (!res.headersSent) {
        respond(res, error.status ?? 500,
          { error: error.status ? error.message : 'Erro interno do servidor.' });
      }
    }
  });
  return { server, db };
}
