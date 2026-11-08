import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'gundua_api_client.dart';

class VisitedPlacesService {
  // Mantém a chave utilizada anteriormente pelo GUNDUA.
  static const String _storageKey = 'gundua_visited_places';

  String getPlaceId(Map<String, dynamic> place) {
    final osmType = (place['osm_type'] ?? place['osmType'])?.toString() ?? '';
    final osmId = (place['osm_id'] ?? place['osmId'])?.toString() ?? '';

    if (osmType.isNotEmpty && osmId.isNotEmpty) {
      return '$osmType-$osmId';
    }

    final placeId = (place['place_id'] ?? place['placeId'])?.toString() ?? '';

    if (placeId.isNotEmpty) {
      return 'place-$placeId';
    }

    final latitude = (place['lat'] ?? place['latitude'])?.toString() ?? '';
    final longitude = (place['lon'] ?? place['longitude'])?.toString() ?? '';
    final name = (place['name'] ?? place['display_name'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    // Compatível com o formato anteriormente utilizado pelo GUNDUA.
    return '$latitude-$longitude-$name';
  }

  Future<List<Map<String, dynamic>>> getVisitedPlaces() async {
    if (GunduaApiClient.isConfigured) {
      final data = await GunduaApiClient().get('/me/visits') as Map;
      return (data['items'] as List).whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)).toList();
    }
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_storageKey);

    if (savedData == null || savedData.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(savedData);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> isVisited(Map<String, dynamic> place) async {
    final places = await getVisitedPlaces();
    final id = getPlaceId(place);

    return places.any((item) => getPlaceId(item) == id);
  }

  Future<void> markAsVisited(Map<String, dynamic> place) async {
    if (GunduaApiClient.isConfigured) {
      await GunduaApiClient().post('/me/visits', {'place': place});
      return;
    }
    final places = await getVisitedPlaces();
    final id = getPlaceId(place);

    final alreadyVisited = places.any((item) => getPlaceId(item) == id);

    if (alreadyVisited) return;

    places.add(Map<String, dynamic>.from(place));

    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_storageKey, jsonEncode(places));

    if (!saved) {
      throw Exception('Não foi possível guardar a visita.');
    }
  }

  Future<void> removeVisitedPlace(Map<String, dynamic> place) async {
    if (GunduaApiClient.isConfigured) {
      final id = Uri.encodeComponent(getPlaceId(place));
      await GunduaApiClient().delete('/me/visits/$id');
      return;
    }
    final places = await getVisitedPlaces();
    final id = getPlaceId(place);

    places.removeWhere((item) => getPlaceId(item) == id);

    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_storageKey, jsonEncode(places));

    if (!saved) {
      throw Exception('Não foi possível remover a visita.');
    }
  }

  // true quando fica marcado como visitado; false quando é removido.
  Future<bool> toggleVisited(Map<String, dynamic> place) async {
    if (await isVisited(place)) {
      await removeVisitedPlace(place);
      return false;
    }

    await markAsVisited(place);
    return true;
  }
}
