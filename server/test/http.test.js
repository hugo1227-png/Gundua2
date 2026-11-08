import test from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';

// Teste de transporte HTTP + autorização/erros, sem fazer de conta que há um MySQL.
const fakePool = {
  query: async () => [[{value:1}]],
  execute: async () => [[], []],
};

async function withServer(callback) {
  const { server } = createApp({db: fakePool});
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const url = `http://127.0.0.1:${server.address().port}`;
  try { await callback(url); } finally {
    await new Promise(resolve => server.close(resolve));
  }
}

test('health REST responde JSON válido', async () => {
  await withServer(async base => {
    const response = await fetch(`${base}/api/v1/health`);
    assert.equal(response.status, 200);
    assert.equal((await response.json()).database, 'mysql');
  });
});

test('não permite consultar perfil sem token', async () => {
  await withServer(async base => {
    const response = await fetch(`${base}/api/v1/me`);
    assert.equal(response.status, 401);
  });
});

test('não permite origens Web desconhecidas', async () => {
  await withServer(async base => {
    const response = await fetch(`${base}/api/v1/health`, {
      headers: {Origin: 'https://nao-autorizado.example'},
    });
    assert.equal(response.status, 403);
  });
});

test('recusa JSON sem validação e não inventa visitas', async () => {
  await withServer(async base => {
    const response = await fetch(`${base}/api/v1/auth/register`, {
      method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({email:'email-invalido',name:'',password:'123'}),
    });
    assert.equal(response.status,400);
    const weekly = await fetch(`${base}/api/v1/analytics/weekly?metric=visits`);
    assert.equal((await weekly.json()).result,null);
  });
});

test('Google Places REST não é público: exige sessão', async () => {
  await withServer(async base => {
    const response = await fetch(`${base}/api/v1/places/google/nearby`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ locationRestriction: {
        circle: { center: { latitude: 38.72, longitude: -9.14 }, radius: 10000 },
      } }),
    });
    assert.equal(response.status, 401);
  });
});
