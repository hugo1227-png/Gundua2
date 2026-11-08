import { readFile } from 'node:fs/promises';
// Executar com a API e o MySQL já em funcionamento: npm run smoke:db
// Cria registos de demonstração na BD real; não apaga dados existentes.
const base = (process.env.GUNDUA_API_URL || 'http://127.0.0.1:3000/api/v1').replace(/\/$/, '');
const stamp = `${Date.now()}-${Math.floor(Math.random() * 10000)}`;
const email = `alpha-check-${stamp}@example.test`;
const password = `GunduaDemo-${stamp}!`;

async function request(method, path, { token, body } = {}) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      'Accept': 'application/json',
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const raw = await response.text();
  const data = raw ? JSON.parse(raw) : null;
  if (!response.ok) throw Error(`${method} ${path}: HTTP ${response.status} — ${data?.error || 'Resposta inesperada'}`);
  return data;
}

try {
  const health = await request('GET', '/health');
  if (health.status !== 'ok' || health.database !== 'mysql') throw Error('MySQL não está operacional.');
  console.log('✓ Node.js e MySQL: disponíveis');
  const seed = JSON.parse(await readFile(new URL('../seed/lisbon.json', import.meta.url), 'utf8'));
  const catalog = [];
  for (const expected of seed) {
    const result = await request('GET', `/places?q=${encodeURIComponent(expected.name)}&limit=100`);
    const place = result.items.find(item => item.name === expected.name);
    if (!place?.gunduaId) throw Error(`Falta um dos dez locais iniciais: ${expected.name}. Executa npm run seed.`);
    const detail = await request('GET', `/places/${encodeURIComponent(place.gunduaId)}`);
    if (detail.name !== expected.name) throw Error(`Detalhes incorretos para ${expected.name}.`);
    catalog.push(place);
  }
  console.log(`✓ Catálogo MySQL: os ${catalog.length} lugares iniciais abrem os detalhes`);

  const registration = await request('POST', '/auth/register', {
    body: { name: 'Teste Alfa GUNDUA', email, password },
  });
  if (!registration.token) throw Error('Registo não devolveu sessão.');
  const userId = registration.user.id;
  const session = await request('POST', '/auth/login', { body: { email, password } });
  if (session.user.id !== userId) throw Error('Login não recuperou o mesmo utilizador.');
  const token = session.token;
  console.log('✓ Conta e login: funcionam na BD real');

  const place = catalog.items[0];
  await request('POST', '/me/favorites', { token, body: { place } });
  const favorites = await request('GET', '/me/favorites', { token });
  if (!favorites.items.some(item => item.gunduaId === place.gunduaId)) {
    throw Error('O favorito não foi persistido no MySQL.');
  }
  console.log('✓ Favoritos: persistência verificada');

  await request('POST', '/me/visits', { token, body: { place } });
  const visits = await request('GET', '/me/visits', { token });
  if (!visits.items.some(item => item.gunduaId === place.gunduaId)) {
    throw Error('A visita não foi persistida no MySQL.');
  }
  console.log('✓ Visitas: persistência verificada');

  await request('PUT', `/me/reviews/${encodeURIComponent(place.gunduaId)}`, {
    token, body: { place, rating: 5, comment: 'Avaliação de teste da versão alfa.' },
  });
  const reviews = await request('GET', '/me/reviews', { token });
  if (!reviews.items.some(item => item.placeId === place.gunduaId && item.rating === 5)) {
    throw Error('A avaliação não foi persistida no MySQL.');
  }
  console.log('✓ Avaliações: persistência verificada');

  const location = { label: 'Lisboa, Portugal', latitude: 38.7223, longitude: -9.1393,
    isDeviceLocation: false };
  await request('PUT', '/me/location', { token, body: location });
  const selected = await request('GET', '/me/location', { token });
  if (selected.location?.label !== location.label) {
    throw Error('A localização escolhida não foi persistida no MySQL.');
  }
  console.log('✓ Localização escolhida: persistência verificada');

  const experience = await request('POST', '/me/experiences', {
    token,
    body: {
      title: 'Descoberta de Lisboa',
      description: 'Experiência criada para testar a versão alfa.',
      placeLocation: place.location || 'Lisboa',
      place,
    },
  });
  const mine = await request('GET', '/me/experiences', { token });
  if (!mine.items.some(item => item.id === experience.id && item.authorName === 'Teste Alfa GUNDUA')) {
    throw Error('A experiência não foi guardada com o nome da conta.');
  }
  const publicList = await request('GET', `/places/${encodeURIComponent(place.gunduaId)}/experiences`);
  if (!publicList.items.some(item => item.id === experience.id)) {
    throw Error('A experiência não aparece na página pública do lugar.');
  }
  console.log('✓ Experiências: persistência e leitura pública verificadas');
  await request('POST', '/auth/logout', { token });
  console.log('✓ Logout: sessão terminada');
  console.log(`\nVerifica no Workbench: utilizador ${email} (ID ${userId}).`);
  console.log('Os registos de teste ficam na BD para a demonstração.');
} catch (error) {
  console.error(`Falha no teste real: ${error.message}`);
  process.exitCode = 1;
}
