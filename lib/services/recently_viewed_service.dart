import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecentlyViewedService {
  static const String _storageKey = 'gundua_recently_viewed_places';
  static const int _maxPlaces = 12;

  Future<List<Map<String, dynamic>>> getRecentlyViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((place) => Map<String, dynamic>.from(place))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addPlace(Map<String, dynamic> place) async {
    final prefs = await SharedPreferences.getInstance();
    final places = await getRecentlyViewed();
    final id = _getPlaceId(place);

    places.removeWhere((item) => _getPlaceId(item) == id);
    places.insert(0, Map<String, dynamic>.from(place));

    final limitedPlaces = places.take(_maxPlaces).toList();
    final saved = await prefs.setString(_storageKey, jsonEncode(limitedPlaces));

    if (!saved) {
      throw Exception('Não foi possível guardar o histórico de lugares.');
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  String _getPlaceId(Map<String, dynamic> place) {
    final placeId = place['placeId'] ?? place['place_id'];
    if (placeId != null && placeId.toString().isNotEmpty) {
      return placeId.toString();
    }

    final osmId = place['osm_id'];
    if (osmId != null) return 'osm_$osmId';

    final name = (place['name'] ?? '').toString().trim().toLowerCase();
    final latitude = place['latitude'] ?? place['lat'] ?? '';
    final longitude = place['longitude'] ?? place['lon'] ?? '';
    return '$name|$latitude|$longitude';
  }
}
