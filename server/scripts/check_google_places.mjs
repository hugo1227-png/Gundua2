// Run from server/: node --env-file=.env scripts/check_google_places.mjs
// Makes one billable Google Places request. Never prints the API key.
import { googleNearby } from '../src/google_places.js';

const key = process.env.GOOGLE_PLACES_API_KEY?.trim();
if (!key) {
  console.error('Falta GOOGLE_PLACES_API_KEY em server/.env.');
  process.exitCode = 1;
} else {
  try {
    const data = await googleNearby({
      maxResultCount: 1,
      includedTypes: ['museum'],
      locationRestriction: {
        circle: {
          center: {latitude: 38.7223, longitude: -9.1393},
          radius: 1000,
        },
      },
    });
    console.log(`Google Places acessível. Lugares devolvidos: ${data.places.length}`);
  } catch (error) {
    console.error(error.message);
    console.error('Verifica faturação, Places API (New) e restrições da chave no Google Cloud.');
    process.exitCode = 1;
  }
}
