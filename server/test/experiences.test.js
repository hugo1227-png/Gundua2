import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createApp } from '../src/app.js';

const fakeUser = {
  id: 'user-1', name: 'Utilizador Teste', email: 'teste@example.test',
  password_hash: '0'.repeat(128), password_salt: '0'.repeat(32),
};
const sample = {
  placeId: 'lisbon-hidden-marioneta', name: 'Museu da Marioneta',
  latitude: 38.7104, longitude: -9.1578, category: 'Museu',
};

async function withFakeApi(callback) {
  const saved = [];
  const db = {
    query: async () => [[{ ok: 1 }]],
    execute: async (sql, values = []) => {
      if (sql.includes('FROM sessions')) return [[fakeUser], []];
      if (sql.includes('INSERT INTO places')) return [{ affectedRows: 1 }, []];
      if (sql.includes('INSERT INTO experiences')) {
        saved.push({
          id: values[0], user_id: values[1], place_id: values[2],
          title: values[3], description: values[4],
          place_location: values[5], image_base64: values[6],
          author_name: fakeUser.name, place_name: sample.name,
          latitude: sample.latitude, longitude: sample.longitude,
          created_at: '2026-11-08 12:00:00',
        });
        return [{ affectedRows: 1 }, []];
      }
      if (sql.includes('DELETE FROM experiences')) {
        const found = saved.findIndex(item => item.id === values[0] && item.user_id === values[1]);
        if (found >= 0) saved.splice(found, 1);
        return [{ affectedRows: found >= 0 ? 1 : 0 }, []];
      }
      if (sql.includes('FROM experiences')) {
        const filtered = sql.includes('WHERE e.user_id=')
          ? saved.filter(item => item.user_id === values[0])
          : saved.filter(item => item.place_id === values[0]);
        return [filtered, []];
      }
      return [[], []];
    },
  };
  const { server } = createApp({ db });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try { await callback(`http://127.0.0.1:${server.address().port}/api/v1`); }
  finally { await new Promise(resolve => server.close(resolve)); }
}

const bearer = { Authorization: `Bearer ${'a'.repeat(64)}` };

test('experiências exigem sessão para publicar ou consultar a própria conta', async () => {
  await withFakeApi(async base => {
    assert.equal((await fetch(`${base}/me/experiences`)).status, 401);
    assert.equal((await fetch(`${base}/me/experiences`, { method: 'POST',
      headers: { 'Content-Type': 'application/json' }, body: '{}' })).status, 401);
  });
});

test('experiências: criação, consulta por lugar, autor da conta e eliminação', async () => {
  await withFakeApi(async base => {
    const response = await fetch(`${base}/me/experiences`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', ...bearer },
      body: JSON.stringify({
        title: 'Um museu diferente', description: 'Uma visita interessante.',
        placeLocation: 'Lisboa', place: sample,
      }),
    });
    assert.equal(response.status, 201);
    const { id } = await response.json();
    assert.match(id, /^[0-9a-f-]{36}$/);

    const mine = await (await fetch(`${base}/me/experiences`, { headers: bearer })).json();
    assert.equal(mine.items.length, 1);
    assert.equal(mine.items[0].authorName, fakeUser.name);
    assert.equal(mine.items[0].placeName, sample.name);

    const publicResponse = await fetch(`${base}/places/place-${sample.placeId}/experiences`);
    assert.equal(publicResponse.status, 200);
    assert.equal((await publicResponse.json()).items.length, 1);

    const deleted = await fetch(`${base}/me/experiences/${id}`, { method: 'DELETE', headers: bearer });
    assert.equal(deleted.status, 204);
    const empty = await (await fetch(`${base}/me/experiences`, { headers: bearer })).json();
    assert.equal(empty.items.length, 0);
  });
});

test('a API recusa experiências vazias ou imagens demasiado grandes', async () => {
  await withFakeApi(async base => {
    for (const body of [{ title: '', description: '', place: sample },
      { title: 'Exemplo', description: 'Texto', imageBase64: 'x'.repeat(1_000_001), place: sample }]) {
      const response = await fetch(`${base}/me/experiences`, { method: 'POST',
        headers: { 'Content-Type': 'application/json', ...bearer }, body: JSON.stringify(body) });
      assert.equal(response.status, 400);
    }
  });
});

test('o catálogo da versão alfa tem dez locais distintos com coordenadas', async () => {
  const catalog = JSON.parse(await readFile(new URL('../seed/lisbon.json', import.meta.url), 'utf8'));
  assert.equal(catalog.length, 10);
  assert.equal(new Set(catalog.map(item => item.placeId)).size, 10);
  for (const place of catalog) {
    assert.ok(place.name && place.locality);
    assert.ok(Number.isFinite(place.latitude) && Number.isFinite(place.longitude));
  }
});
