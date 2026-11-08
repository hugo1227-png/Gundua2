import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'favorites_service.dart';
import 'gundua_api_client.dart';
import 'profile_service.dart';

class ExperiencesService {
  static const String _experiencesKey = 'gundua_experiences';
  static const String _fallbackAuthorName = 'Viajante';

  /// Devolve todas as experiências, começando pelas mais recentes.
  Future<List<Map<String, dynamic>>> getExperiences() async {
    if (GunduaApiClient.isConfigured) {
      final data = await GunduaApiClient().get('/me/experiences') as Map;
      return (data['items'] as List).whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)).toList();
    }
    final prefs = await SharedPreferences.getInstance();
    final savedExperiences = prefs.getString(_experiencesKey);

    if (savedExperiences == null || savedExperiences.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(savedExperiences);
      if (decoded is! List) return [];

      final experiences = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      experiences.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB =
            DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      return experiences;
    } catch (_) {
      return [];
    }
  }

  /// Devolve o nome do autor ou um nome alternativo para publicações antigas.
  static String getAuthorName(Map<String, dynamic> experience) {
    final authorName = experience['authorName']?.toString().trim();
    if (authorName == null || authorName.isEmpty) {
      return _fallbackAuthorName;
    }
    return authorName;
  }

  /// Cria um identificador para associar uma experiência a um lugar.
  static String getPlaceId(Map<String, dynamic> place) =>
      FavoritesService().getPlaceId(place);

  /// Guarda uma experiência, incluindo o autor e os dados do lugar.
  Future<void> addExperience({
    required String title,
    required String description,
    required String placeName,
    required String placeLocation,
    String? authorName,
    Map<String, dynamic>? place,
    String? imageBase64,
    String? placeId,
    String? placeLatitude,
    String? placeLongitude,
    String? placeDisplayName,
  }) async {
    if (GunduaApiClient.isConfigured) {
      if (place == null) {
        throw ArgumentError('Seleciona um lugar antes de partilhar.');
      }
      await GunduaApiClient().post('/me/experiences', {
        'title': title.trim(),
        'description': description.trim(),
        'placeLocation': placeLocation.trim(),
        'imageBase64': imageBase64,
        'place': place,
      });
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final experiences = await getExperiences();
    final profileName = (await ProfileService().getProfile())['name']?.trim();
    final providedName = authorName?.trim() ?? '';
    final cleanAuthorName = providedName.isNotEmpty ? providedName : profileName;

    final experience = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'title': title.trim(),
      'description': description.trim(),
      'authorName': cleanAuthorName == null || cleanAuthorName.isEmpty
          ? _fallbackAuthorName
          : cleanAuthorName,
      'placeName': placeName.trim(),
      'placeLocation': placeLocation.trim(),
      'imageBase64': imageBase64,
      'placeId': placeId,
      'placeLatitude': placeLatitude,
      'placeLongitude': placeLongitude,
      'placeDisplayName': placeDisplayName,
      'createdAt': DateTime.now().toIso8601String(),
    };

    experiences.insert(0, experience);
    await prefs.setString(_experiencesKey, jsonEncode(experiences));
  }

  /// Devolve as experiências associadas ao lugar selecionado.
  Future<List<Map<String, dynamic>>> getExperiencesForPlace(
    Map<String, dynamic> place,
  ) async {
    if (GunduaApiClient.isConfigured) {
      final id = Uri.encodeComponent(getPlaceId(place));
      final data = await GunduaApiClient().get('/places/$id/experiences') as Map;
      return (data['items'] as List).whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)).toList();
    }
    final experiences = await getExperiences();
    final targetPlaceId = getPlaceId(place);
    final targetName = _normalizePlaceName(
      place['name']?.toString() ?? place['display_name']?.toString() ?? '',
    );

    return experiences.where((experience) {
      final experiencePlaceId = experience['placeId']?.toString() ?? '';

      if (targetPlaceId.isNotEmpty &&
          experiencePlaceId.isNotEmpty &&
          experiencePlaceId == targetPlaceId) {
        return true;
      }

      // Compatibilidade com publicações antigas sem placeId.
      final experienceName = _normalizePlaceName(
        experience['placeName']?.toString() ?? '',
      );
      return experienceName.isNotEmpty &&
          targetName.isNotEmpty &&
          experienceName == targetName;
    }).toList();
  }

  /// Elimina uma experiência através do seu identificador.
  Future<void> deleteExperience(Map<String, dynamic> experience) async {
    if (GunduaApiClient.isConfigured) {
      final id = experience['id']?.toString() ?? '';
      if (id.isEmpty) throw ArgumentError('Experiência não identificada.');
      await GunduaApiClient().delete(
        '/me/experiences/${Uri.encodeComponent(id)}',
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final experiences = await getExperiences();
    final id = experience['id']?.toString();

    experiences.removeWhere((item) => item['id']?.toString() == id);
    await prefs.setString(_experiencesKey, jsonEncode(experiences));
  }

  static String _normalizePlaceName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
