import test from 'node:test';
import assert from 'node:assert/strict';
import { placeId, validatePlace, placeFromRow, InputError } from '../src/db.js';

const estufa = {
  placeId: 'lisbon-hidden-estufa-fria', name: 'Estufa Fria',
  category: 'Natureza', latitude: 38.7285, longitude: -9.1533,
};

test('identificador estável, igual ao cliente Flutter', () => {
  assert.equal(placeId(estufa), 'place-lisbon-hidden-estufa-fria');
  assert.equal(placeId({osm_type:'node',osm_id:123,name:'Museu'}), 'node-123');
});

test('validação de locais e coordenadas', () => {
  assert.equal(validatePlace(estufa).category, 'Natureza');
  assert.throws(() => validatePlace({ name: 'a', latitude: 999 }), InputError);
  assert.throws(() => validatePlace({ name: '' }), InputError);
});

test('dados guardados em JSON recuperam o local', () => {
  assert.equal(placeFromRow({id: placeId(estufa), data_json: JSON.stringify(estufa)}).name, 'Estufa Fria');
});
