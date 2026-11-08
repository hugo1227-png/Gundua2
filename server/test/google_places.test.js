import test from 'node:test';
import assert from 'node:assert/strict';
import { validateNearbyRequest, googleNearby, summarizeGoogleError } from '../src/google_places.js';
import { InputError } from '../src/db.js';

const nearby = {
  maxResultCount: 20,
  includedTypes: ['museum'],
  locationRestriction: {
    circle: {
      center: { latitude: 38.72, longitude: -9.14 },
      radius: 20000,
    },
  },
};

test('aceita apenas raio e categorias seguros', () => {
  assert.deepEqual(validateNearbyRequest(nearby).includedTypes, ['museum']);
  assert.throws(() => validateNearbyRequest({ ...nearby, includedTypes: ['bank'] }), InputError);
  assert.throws(() => validateNearbyRequest({ ...nearby,
    locationRestriction: { circle: { ...nearby.locationRestriction.circle, radius: 30000 } },
  }), InputError);
});

test('proxy adiciona a chave apenas ao pedido feito pelo servidor', async () => {
  let request;
  const output = await googleNearby(nearby, {
    key: 'TEST_ONLY_SECRET',
    fetchImpl: async (url, init) => {
      request = { url, init };
      return { ok: true, json: async () => ({ places: [{ id: 'id-1' }] }) };
    },
  });
  assert.equal(request.url, 'https://places.googleapis.com/v1/places:searchNearby');
  assert.equal(request.init.headers['X-Goog-Api-Key'], 'TEST_ONLY_SECRET');
  assert.deepEqual(output, { places: [{ id: 'id-1' }] });
  assert.equal(JSON.stringify(output).includes('TEST_ONLY_SECRET'), false);
});

test('sem chave, o servidor responde com erro controlado', async () => {
  await assert.rejects(() => googleNearby(nearby, { key: '' }), error => error.status === 503);
});


test('403: diagnosis is logged, never exposed to user', async () => {
  const logs = [];
  const secret = 'AIzaTESTFAKESECRET_1234567890123456789';
  await assert.rejects(() => googleNearby(nearby, {
    key: secret,
    logger: { warn: message => logs.push(message) },
    fetchImpl: async () => ({ok: false, status: 403, json: async () => ({
      error: {status: 'PERMISSION_DENIED', message: `Key not allowed: ${secret}`},
    })}),
  }), error => error.status === 503 && !error.message.includes('403') &&
      !error.message.includes(secret));
  assert.match(logs[0], /HTTP 403 \(PERMISSION_DENIED\)/);
  assert.equal(logs[0].includes(secret), false);
});

test('upstream diagnostics handle empty response', () => {
  assert.match(summarizeGoogleError(403, null), /UNKNOWN/);
});
