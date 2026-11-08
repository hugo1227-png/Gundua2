import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'gundua_api_client.dart';

class FavoritesService {
  static const String _storageKey = 'gundua_favorite_places';

  // Identificador consistente para reconhecer o mesmo lugar em vários ecrãs.
  String getPlaceId(Map<String, dynamic> place) {
    final osmType = place['osm_type'] ?? place['osmType'];
    final osmId = place['osm_id'] ?? place['osmId'];

    if (osmType != null && osmId != null) {
      return '$osmType-$osmId';
    }

    final placeId = place['place_id'] ?? place['placeId'];
    if (placeId != null) {
      return 'place-$placeId';
    }

    final latitude = place['lat'] ?? place['latitude'] ?? '';
    final longitude = place['lon'] ?? place['longitude'] ?? '';
    final name = place['name'] ?? place['display_name'] ?? '';

    return '$latitude-$longitude-$name'.toString().trim().toLowerCase();
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    if (GunduaApiClient.isConfigured) {
      final data = await GunduaApiClient().get('/me/favorites') as Map;
      return (data['items'] as List).whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)).toList();
    }
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);

    if (data == null || data.isEmpty) return [];

    try {
      final decoded = jsonDecode(data);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> isFavorite(Map<String, dynamic> place) async {
    final favorites = await getFavorites();
    final placeId = getPlaceId(place);

    return favorites.any((favorite) => getPlaceId(favorite) == placeId);
  }

  Future<bool> addFavorite(Map<String, dynamic> place) async {
    if (GunduaApiClient.isConfigured) {
      await GunduaApiClient().post('/me/favorites', {'place': place});
      return true;
    }
    final favorites = await getFavorites();
    final placeId = getPlaceId(place);

    final alreadyExists = favorites.any(
      (favorite) => getPlaceId(favorite) == placeId,
    );
    if (alreadyExists) return true;

    favorites.add(Map<String, dynamic>.from(place));

    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_storageKey, jsonEncode(favorites));

    if (!saved) {
      throw Exception('Não foi possível guardar o lugar.');
    }

    return true;
  }

  Future<bool> removeFavorite(Map<String, dynamic> place) async {
    if (GunduaApiClient.isConfigured) {
      final id = Uri.encodeComponent(getPlaceId(place));
      await GunduaApiClient().delete('/me/favorites/$id');
      return false;
    }
    final favorites = await getFavorites();
    final placeId = getPlaceId(place);

    favorites.removeWhere((favorite) => getPlaceId(favorite) == placeId);

    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_storageKey, jsonEncode(favorites));

    if (!saved) {
      throw Exception('Não foi possível remover o lugar.');
    }

    return false;
  }

  // Devolve true quando o lugar fica guardado e false quando é removido.
  Future<bool> toggleFavorite(Map<String, dynamic> place) async {
    final favorite = await isFavorite(place);

    if (favorite) {
      return removeFavorite(place);
    }

    return addFavorite(place);
  }
}
