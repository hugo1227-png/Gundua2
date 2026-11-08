import { InputError } from './db.js';

const allowedTypes = new Set([
  'tourist_attraction', 'museum', 'restaurant', 'park',
  'art_gallery', 'church', 'beach',
]);
const fieldMask = [
  'places.id', 'places.displayName', 'places.formattedAddress',
  'places.location', 'places.types', 'places.rating',
  'places.userRatingCount', 'places.googleMapsUri',
].join(',');

/** Validate only the fields the app actually needs; never proxy arbitrary Google requests. */
export function validateNearbyRequest(input) {
  const circle = input?.locationRestriction?.circle;
  const latitude = circle?.center?.latitude;
  const longitude = circle?.center?.longitude;
  const radius = circle?.radius;
  const types = input?.includedTypes ?? [];
  const limit = input?.maxResultCount ?? 20;

  if (typeof latitude !== 'number' || !Number.isFinite(latitude) || Math.abs(latitude) > 90 ||
      typeof longitude !== 'number' || !Number.isFinite(longitude) || Math.abs(longitude) > 180 ||
      typeof radius !== 'number' || !Number.isFinite(radius) || radius <= 0 || radius > 20000 ||
      !Array.isArray(types) || types.length > 3 || types.some(type => !allowedTypes.has(type)) ||
      !Number.isInteger(limit) || limit < 1 || limit > 20) {
    throw new InputError('Pedido de lugares inválido.');
  }
  return {
    maxResultCount: limit,
    rankPreference: 'POPULARITY',
    ...(types.length ? { includedTypes: types } : {}),
    locationRestriction: { circle: { center: { latitude, longitude }, radius } },
  };
}

/** Diagnostics stay on the server; credentials and upstream messages never reach the app. */
export function summarizeGoogleError(status, payload) {
  const error = payload?.error;
  const reason = typeof error?.status === 'string' ? error.status : 'UNKNOWN';
  const message = typeof error?.message === 'string' ? error.message : '';
  const safe = message.replace(/AIza[0-9A-Za-z_-]{20,}/g, '[REDACTED]')
    .replace(/(key|token|password)=([^\s&]+)/gi, '$1=[REDACTED]')
    .slice(0, 240);
  return `Google Places HTTP ${status} (${reason}): ${safe}`;
}

export async function googleNearby(input, {
  key = process.env.GOOGLE_PLACES_API_KEY,
  fetchImpl = fetch,
  logger = console,
} = {}) {
  const body = validateNearbyRequest(input);
  if (!key) {
    throw new InputError('Google Places não está configurado no servidor.', 503);
  }
  let response;
  try {
    response = await fetchImpl('https://places.googleapis.com/v1/places:searchNearby', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': key,
        'X-Goog-FieldMask': fieldMask,
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(18000),
    });
  } catch (_) {
    throw new InputError('As classificações estão temporariamente indisponíveis.', 503);
  }
  if (!response.ok) {
    let payload;
    try { payload = await response.json(); } catch (_) { /* non-JSON error */ }
    logger.warn?.(summarizeGoogleError(response.status, payload));
    // This is server-to-server: Google HTTP 403 is not browser CORS.
    throw new InputError('As classificações estão temporariamente indisponíveis.', 503);
  }
  try {
    const payload = await response.json();
    return { places: Array.isArray(payload.places) ? payload.places : [] };
  } catch (_) {
    throw new InputError('As classificações estão temporariamente indisponíveis.', 503);
  }
}
