import 'package:flutter_test/flutter_test.dart';
import 'package:proto_2/models/place.dart';

void main() {
  test('Place converte os dados de um resultado da Geoapify', () {
    final place = Place.fromMap({
      'place_id': 'geoapify-place-1',
      'name': 'Museu de Exemplo',
      'formatted': 'Rua Principal, Lisboa, Portugal',
      'location': 'Rua Principal, Lisboa, Portugal',
      'category': 'entertainment.museum',
      'city': 'Lisboa',
      'country': 'Portugal',
      'lat': 38.7223,
      'lon': -9.1393,
      'distance': 450,
    });

    expect(place.id, 'geoapify-place-1');
    expect(place.name, 'Museu de Exemplo');
    expect(place.locality, 'Lisboa');
    expect(place.country, 'Portugal');
    expect(place.distanceMeters, 450);
  });

  test('Place lê a classificação e o número de avaliações do Google', () {
    final place = Place.fromMap({
      'name': 'Lugar classificado',
      'latitude': 38.7223,
      'longitude': -9.1393,
      'rating': 4.8,
      'userRatingCount': 126,
      'googleMapsUri': 'https://maps.google.com/?q=place',
    });

    expect(place.rating, 4.8);
    expect(place.reviewCount, 126);
    expect(place.googleMapsUri, 'https://maps.google.com/?q=place');
  });

  test('Place mantém os dados ao actualizar a distância', () {
    const place = Place(
      id: 'place-1',
      name: 'Jardim de Exemplo',
      address: 'Lisboa, Portugal',
      category: 'leisure.park',
      country: 'Portugal',
      locality: 'Lisboa',
      latitude: 38.7223,
      longitude: -9.1393,
    );

    final updatedPlace = place.copyWith(distanceMeters: 320);

    expect(updatedPlace.distanceMeters, 320);
    expect(updatedPlace.locality, 'Lisboa');
    expect(updatedPlace.country, 'Portugal');
  });
}
