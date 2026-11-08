import { readFile } from 'node:fs/promises';

export class InputError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

export async function one(db, sql, values = []) {
  const [rows] = await db.execute(sql, values);
  return rows[0] ?? null;
}

export async function many(db, sql, values = []) {
  const [rows] = await db.execute(sql, values);
  return rows;
}

export async function execute(db, sql, values = []) {
  const [result] = await db.execute(sql, values);
  return result;
}

// Mesma prioridade de identificadores usada por FavoritesService no Flutter.
export function placeId(place) {
  const osmType = place.osm_type ?? place.osmType;
  const osmId = place.osm_id ?? place.osmId;
  if (osmType != null && osmId != null) return `${osmType}-${osmId}`;
  const provided = place.place_id ?? place.placeId;
  if (provided != null && String(provided).trim()) return `place-${provided}`;
  const lat = place.lat ?? place.latitude ?? '';
  const lon = place.lon ?? place.longitude ?? '';
  return `${lat}-${lon}-${place.name ?? place.display_name ?? ''}`.trim().toLowerCase();
}

export function validatePlace(place) {
  if (!place || typeof place !== 'object' || Array.isArray(place)) {
    throw new InputError('Envia um objeto "place" válido.');
  }
  const name = String(place.name ?? '').trim();
  if (!name || name.length > 200) throw new InputError('Nome do local inválido.');
  const id = placeId(place);
  if (!id || id.length > 300) throw new InputError('Identificador do local inválido.');
  const json = JSON.stringify(place);
  if (Buffer.byteLength(json) > 100_000) throw new InputError('Dados do local demasiado extensos.');
  const latitude = place.latitude ?? place.lat ?? null;
  const longitude = place.longitude ?? place.lon ?? null;
  if (latitude != null && (!Number.isFinite(latitude) || Math.abs(latitude) > 90) ||
      longitude != null && (!Number.isFinite(longitude) || Math.abs(longitude) > 180)) {
    throw new InputError('Coordenadas inválidas.');
  }
  return { id, name, category: String(place.categoryLabel ?? place.category ?? '').slice(0, 150),
    latitude, longitude, json };
}

export async function savePlace(db, place) {
  const p = validatePlace(place);
  await execute(db, `INSERT INTO places (id, name, category, latitude, longitude, data_json)
    VALUES (?,?,?,?,?,?) ON DUPLICATE KEY UPDATE
      name=VALUES(name), category=VALUES(category), latitude=VALUES(latitude),
      longitude=VALUES(longitude), data_json=VALUES(data_json)`,
    [p.id, p.name, p.category, p.latitude, p.longitude, p.json]);
  return p.id;
}

export function placeFromRow(row) {
  if (!row) return null;
  const raw = typeof row.data_json === 'string' ? JSON.parse(row.data_json) : row.data_json;
  return { ...raw, gunduaId: row.id };
}

export async function seedPlaces(db) {
  const seedUrl = new URL('../seed/lisbon.json', import.meta.url);
  const places = JSON.parse(await readFile(seedUrl, 'utf8'));
  for (const place of places) {
    const p = validatePlace(place);
    await execute(db, `INSERT IGNORE INTO places (id,name,category,latitude,longitude,data_json)
      VALUES (?,?,?,?,?,?)`, [p.id, p.name, p.category, p.latitude, p.longitude, p.json]);
  }
  return places.length;
}
