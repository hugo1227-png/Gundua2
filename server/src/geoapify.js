import { InputError, placeFromRow, many } from './db.js';

function assertCoordinates(lat, lon) {
  if (!Number.isFinite(lat) || lat < -90 || lat > 90 ||
      !Number.isFinite(lon) || lon < -180 || lon > 180) {
    throw new InputError('Coordenadas inválidas.');
  }
}

const trim = (value, max=100) => String(value ?? '').trim().slice(0,max);

async function geoapify(route, params) {
  const key = process.env.GEOAPIFY_API_KEY;
  if (!key) throw new InputError(
    'Configura GEOAPIFY_API_KEY no ficheiro server/.env para pesquisar lugares externos.',503);
  const url = new URL(`https://api.geoapify.com${route}`);
  Object.entries(params).forEach(([k,v])=>url.searchParams.set(k, String(v)));
  url.searchParams.set('apiKey',key);
  const response = await fetch(url,{signal:AbortSignal.timeout(12000)});
  const json = await response.json();
  if (!response.ok) {
    throw new InputError(`Erro Geoapify (${response.status}): ${String(json.message ?? 'Tenta novamente.')}`,502);
  }
  return json;
}

export async function geoSearch(query) {
  if (!trim(query)) throw new InputError('Indica o lugar ou a cidade.');
  const response = await geoapify('/v1/geocode/search',{
    text:trim(query,150),format:'json',lang:'pt',limit:10,
  });
  return (response.results ?? []).map(place => ({
    ...place,
    name:place.name ?? place.address_line1 ?? place.city ?? place.formatted ?? 'Local',
    location:place.formatted ?? '',
    country:place.country ?? '',
    locality:place.city ?? place.town ?? place.village ?? place.suburb ?? place.state ?? '',
    latitude:place.lat,longitude:place.lon,lat:place.lat,lon:place.lon,
    placeId:place.place_id,
  }));
}

function distanceKm(lat1,lon1,lat2,lon2) {
  const r=Math.PI/180;
  const dLat=(lat2-lat1)*r, dLon=(lon2-lon1)*r;
  const h=Math.sin(dLat/2)**2+Math.cos(lat1*r)*Math.cos(lat2*r)*Math.sin(dLon/2)**2;
  return 12742*Math.asin(Math.min(1,Math.sqrt(h)));
}

function fitsCuratedCategory(place, filters) {
  const value = String(place.category ?? '').toLowerCase();
  const allowed = filters.split(',');
  return allowed.some(filter => {
    if (filter === 'tourism') return true;
    if (filter.startsWith('catering')) return value.includes('restaur');
    if (filter.includes('museum')) return value.includes('museu');
    if (filter.includes('square')) return value.includes('praça');
    if (filter.includes('sights')) return ['património','monumento','miradouro'].some(x=>value.includes(x));
    if (filter.startsWith('natural') || filter.startsWith('leisure')) {
      return ['natureza','jardim','parque'].some(x=>value.includes(x));
    }
    if (filter.includes('culture') || filter.includes('attraction')) {
      return ['cultura','mercado','museu'].some(x=>value.includes(x));
    }
    if (filter.includes('beach')) return value.includes('praia');
    if (filter === 'entertainment') return ['cultura','museu','mercado'].some(x=>value.includes(x));
    return false;
  });
}

export async function geoNearby(db,query) {
  const lat=Number(query.get('lat')),lon=Number(query.get('lon'));
  assertCoordinates(lat,lon);
  const radius=Math.min(20000,Math.max(100,Number.parseInt(query.get('radius') ?? '5000',10)||5000));
  const limit=Math.min(100,Math.max(1,Number.parseInt(query.get('limit') ?? '20',10)||20));
  const categories=trim(query.get('categories') || 'tourism,leisure.park',200);
  if (!/^[a-z.,_]+$/.test(categories)) throw new InputError('Categorias inválidas.');
  if (!process.env.GEOAPIFY_API_KEY) {
    // Catálogo local real, proveniente de seeds e locais guardados pelos utilizadores.
    // Sem fornecedores externos não atribuímos classificações ou visitas inventadas.
    const items=(await many(db, 'SELECT * FROM places')).map(placeFromRow)
      .filter(p=>fitsCuratedCategory(p,categories))
      .filter(p=>typeof p.latitude==='number'&&typeof p.longitude==='number')
      .map(p=>({...p,distance:Math.round(distanceKm(lat,lon,p.latitude,p.longitude)*1000)}))
      .filter(p=>p.distance<=radius).sort((a,b)=>a.distance-b.distance).slice(0,limit);
    return {items,source:'local_database'};
  }
  const response = await geoapify('/v2/places',{
    categories,filter:`circle:${lon},${lat},${radius}`,bias:`proximity:${lon},${lat}`,
    limit,lang:'pt',
  });
  const places=[];
  for (const feature of response.features ?? []) {
    const p=feature.properties ?? {};
    const coords=feature.geometry?.coordinates;
    const latitude=p.lat ?? coords?.[1];
    const longitude=p.lon ?? coords?.[0];
    const name=p.name ?? p.address_line1 ?? p.formatted;
    if (!name || typeof latitude!=='number' || typeof longitude!=='number') continue;
    const categories=Array.isArray(p.categories)?p.categories:[];
    places.push({
      ...p,name,location:p.formatted ?? p.address_line2 ?? '',
      country:p.country ?? '', locality:p.city ?? p.town ?? p.suburb ?? p.county ?? '',
      latitude,longitude,lat:latitude,lon:longitude,
      placeId:p.place_id,categories,
      category:categories.sort((a,b)=>b.split('.').length-a.split('.').length)[0] ?? 'Ponto de interesse',
      image:null,
    });
  }
  return {items:places,source:'geoapify'};
}
