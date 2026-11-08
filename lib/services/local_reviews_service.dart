import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'favorites_service.dart';
import 'gundua_api_client.dart';

/// Avaliações próprias neste dispositivo, não publicadas em plataformas externas.
class LocalReviewsService {
  static const _key = 'gundua_local_reviews';

  Future<List<Map<String, dynamic>>> getReviews() async {
    if (GunduaApiClient.isConfigured) {
      final data = await GunduaApiClient().get('/me/reviews') as Map;
      return (data['items'] as List).whereType<Map>().map((raw) {
        final review = Map<String, dynamic>.from(raw);
        final place = review['place'];
        if (place is Map) {
          review['placeId'] = (place['placeId'] ?? place['place_id'] ??
              review['placeId']).toString();
        }
        return review;
      }).toList();
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      return [];
    }
    try {
      final data = jsonDecode(raw);
      if (data is! List) {
        return [];
      }
      return data.whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> forPlace(String placeId) async {
    if (GunduaApiClient.isConfigured) {
      final id = Uri.encodeComponent(_apiPlaceId(placeId));
      try {
        final data = await GunduaApiClient().get('/me/reviews/$id') as Map;
        return Map<String, dynamic>.from(data);
      } on GunduaApiException catch (error) {
        if (error.statusCode == 404) return null;
        rethrow;
      }
    }
    final reviews = await getReviews();
    for (final item in reviews) {
      if (item['placeId'] == placeId) {
        return item;
      }
    }
    return null;
  }

  Future<void> save({required Map<String, dynamic> place,
      required int rating, required String comment}) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Classificação inválida.');
    }
    if (comment.trim().isEmpty) {
      throw ArgumentError('Deixa a tua avaliação.');
    }
    final id = (place['placeId'] ?? place['place_id'] ??
        '${place['name']}_${place['latitude']}_${place['longitude']}').toString();
    if (GunduaApiClient.isConfigured) {
      final apiId = Uri.encodeComponent(FavoritesService().getPlaceId(place));
      await GunduaApiClient().put('/me/reviews/$apiId', {
        'place': place,
        'rating': rating,
        'comment': comment.trim(),
      });
      return;
    }
    final reviews = await getReviews();
    reviews.removeWhere((item) => item['placeId'] == id);
    reviews.insert(0, {
      'placeId': id,
      'place': place,
      'rating': rating,
      'comment': comment.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(reviews));
  }

  String _apiPlaceId(String placeId) {
    return placeId.startsWith('place-') ? placeId : 'place-$placeId';
  }

  Future<void> delete(String placeId) async {
    if (GunduaApiClient.isConfigured) {
      await GunduaApiClient().delete('/me/reviews/${Uri.encodeComponent(_apiPlaceId(placeId))}');
      return;
    }
    final reviews = await getReviews();
    reviews.removeWhere((item) => item['placeId'] == placeId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(reviews));
  }
}
