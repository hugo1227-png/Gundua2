import 'package:flutter_test/flutter_test.dart';
import 'package:proto_2/services/location_service.dart';
import 'package:proto_2/services/place_search_service.dart';
import 'package:proto_2/services/place_service.dart';

class _FakePlaces extends PlaceService {
  String? lastCategory;

  @override
  Future<List<Map<String, dynamic>>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    int limit = 20,
    String categoryFilter = 'tourism,leisure.park',
  }) async {
    lastCategory = categoryFilter;
    return [
      {'name': 'Museu Nacional', 'latitude': 38.72, 'longitude': -9.13,
        'category': 'entertainment',
        'categories': ['entertainment', 'entertainment.museum']},
      {'name': 'Praça do Comércio', 'latitude': 38.71, 'longitude': -9.13,
        'category': 'tourism.sights.square',
        'categories': ['tourism.sights.square']},
    ];
  }
}

void main() {
  const location = AppLocation(label: 'Lisboa', latitude: 38.72,
      longitude: -9.13, isDeviceLocation: false);

  test('seleção Museus exclui praças e respeita o termo pesquisado', () async {
    final places = _FakePlaces();
    final search = PlaceSearchService(placeService: places);
    final result = await search.search(placeQuery: 'Museu Nacional',
        category: 'Museus', nearbyLocation: location);
    expect(places.lastCategory, 'entertainment.museum');
    expect(result.length, 1);
    expect(result.first['name'], 'Museu Nacional');
  });

  test('praças têm uma categoria distinta de monumentos', () {
    const square = {'category': 'tourism.sights.square',
      'categories': ['tourism.sights', 'tourism.sights.square']};
    expect(PlaceSearchService.matchesCategory(square, 'Praças'), isTrue);
    expect(PlaceSearchService.matchesCategory(square, 'Restaurantes'), isFalse);
    expect(PlaceSearchService.matchesCategory(square, 'Monumentos'), isFalse);
  });
}
