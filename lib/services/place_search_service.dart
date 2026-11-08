import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_service.dart';
import 'place_service.dart';

/// Used by Home and Explore. A place name is geocoded; a category is searched
/// in the Geoapify Places API around a real GPS/manual location.
class PlaceSearchService {
  PlaceSearchService({PlaceService? placeService})
      : _placeService = placeService ?? PlaceService();

  final PlaceService _placeService;

  static const categoryFilters = <String, String>{
    'Restaurantes': 'catering.restaurant',
    'Museus': 'entertainment.museum',
    'Monumentos': 'tourism.sights',
    'Natureza': 'natural,leisure.park',
    'Cultura': 'entertainment.culture,tourism.attraction',
    'Praias': 'beach',
    'Praças': 'tourism.sights.square',
  };

  /// Usa a taxonomia real Geoapify, não apenas o primeiro rótulo da ficha.
  static bool matchesCategory(Map<String, dynamic> place, String category) {
    if (category == 'Todos') return true;
    final filter = categoryFilters[category];
    if (filter == null) return true;
    final permitted = filter.split(',');
    final rawCategories = place['categories'];
    final values = <String>[
      if (rawCategories is List) ...rawCategories.map((value) => value.toString()),
      (place['category'] ?? '').toString(),
      (place['categoryLabel'] ?? '').toString(),
    ];
    // Praças também pertencem ao ramo tourism.sights; não são monumentos.
    if (category == 'Monumentos' && values.any((value) =>
        value == 'tourism.sights.square' ||
        value.startsWith('tourism.sights.square.'))) {
      return false;
    }
    return values.any((value) => permitted.any((term) =>
        value == term || value.startsWith('$term.')));
  }

  static String? categoryFromTerm(String text) {
    final term = text.trim().toLowerCase();
    const words = {
      'restaurante': 'Restaurantes', 'restaurantes': 'Restaurantes',
      'museu': 'Museus', 'museus': 'Museus',
      'monumento': 'Monumentos', 'monumentos': 'Monumentos',
      'parque': 'Natureza', 'parques': 'Natureza',
      'natureza': 'Natureza', 'jardins': 'Natureza',
      'cultura': 'Cultura', 'praia': 'Praias', 'praias': 'Praias',
      'praça': 'Praças', 'praças': 'Praças',
    };
    return words[term];
  }

  Future<List<Map<String, dynamic>>> search({
    String placeQuery = '',
    String locationQuery = '',
    String category = 'Todos',
    AppLocation? nearbyLocation,
    int radiusMeters = 20000,
  }) async {
    final place = placeQuery.trim();
    final location = locationQuery.trim();
    if (place.isEmpty && location.isEmpty && category == 'Todos') return [];

    AppLocation? anchor = nearbyLocation;
    if (location.isNotEmpty &&
        (anchor == null || location.toLowerCase() != anchor.label.toLowerCase())) {
      final matches = await _placeService.searchPlaces(location);
      if (matches.isEmpty) return [];
      final first = matches.first;
      final lat = first['latitude'];
      final lon = first['longitude'];
      if (lat is num && lon is num) {
        anchor = AppLocation(
          label: (first['name'] ?? location).toString(),
          latitude: lat.toDouble(), longitude: lon.toDouble(),
          isDeviceLocation: false,
        );
      }
    }

    final chosenCategory = category != 'Todos'
        ? category
        : categoryFromTerm(place);
    if (chosenCategory != null && categoryFilters.containsKey(chosenCategory) && anchor == null) {
      throw StateError('Escolhe uma localização para pesquisar por categoria.');
    }
    if (chosenCategory != null && categoryFilters.containsKey(chosenCategory) && anchor != null) {
      final results = await _placeService.getNearbyPlaces(
        latitude: anchor.latitude,
        longitude: anchor.longitude,
        radiusMeters: radiusMeters,
        limit: 100,
        categoryFilter: categoryFilters[chosenCategory]!,
      );
      // A categoria é filtrada na API e validada novamente no cliente.
      // Se foi escrito um nome, não mostrar outros pontos da mesma categoria.
      final terms = place.toLowerCase().split(RegExp(r'\s+'))
          .where((term) => term.isNotEmpty &&
              categoryFromTerm(term) != chosenCategory).toList();
      return results.where((item) =>
          matchesCategory(item, chosenCategory) &&
          (terms.isEmpty || terms.every((term) {
            final content = '${item['name'] ?? ''} ${item['location'] ?? ''}'.toLowerCase();
            return content.contains(term);
          }))).map((result) => {
        ...result,
        'distance': Geolocator.distanceBetween(
          anchor!.latitude, anchor.longitude,
          (result['latitude'] as num).toDouble(),
          (result['longitude'] as num).toDouble(),
        ),
      }).toList();
    }

    if (place.isEmpty && anchor != null) {
      return _placeService.getNearbyPlaces(
        latitude: anchor.latitude,
        longitude: anchor.longitude,
        radiusMeters: radiusMeters,
        limit: 100,
        categoryFilter: 'tourism,entertainment,leisure.park,beach,catering.restaurant',
      );
    }

    final query = [place, location].where((part) => part.isNotEmpty).join(', ');
    final results = await _placeService.searchPlaces(query);
    if (anchor == null) return results;
    return results.map((result) {
      final lat = result['latitude'];
      final lon = result['longitude'];
      if (lat is! num || lon is! num) return result;
      return {
        ...result,
        'distance': Geolocator.distanceBetween(
          anchor!.latitude, anchor.longitude,
          lat.toDouble(), lon.toDouble(),
        ),
      };
    }).toList();
  }
}

class SearchHistoryService {
  static const String _storageKey = 'gundua_recent_searches';
  static const int _maxItems = 12;

  Future<List<Map<String, String>>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((item) {
        return {
          'placeQuery': (item['placeQuery'] ?? '').toString(),
          'locationQuery': (item['locationQuery'] ?? '').toString(),
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add({required String placeQuery, required String locationQuery}) async {
    final place = placeQuery.trim();
    final location = locationQuery.trim();
    if (place.isEmpty && location.isEmpty) return;

    final history = await getRecentSearches();
    history.removeWhere((item) =>
        item['placeQuery']?.toLowerCase() == place.toLowerCase() &&
        item['locationQuery']?.toLowerCase() == location.toLowerCase());
    history.insert(0, {'placeQuery': place, 'locationQuery': location});

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(history.take(_maxItems).toList()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
