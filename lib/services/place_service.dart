import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'gundua_api_client.dart';

/// A failure to fetch ratings is not a failure to browse places.
class PlaceRatingsUnavailable implements Exception {
  const PlaceRatingsUnavailable([this.message = 'Classificações indisponíveis de momento.']);
  final String message;
  @override
  String toString() => message;
}

class PlaceService {
  static const String _apiKey = String.fromEnvironment('GEOAPIFY_API_KEY');

  static const String _geoapifyUrl =
      'https://api.geoapify.com/v1/geocode/search';

  static const String _wikimediaUrl = 'https://commons.wikimedia.org/w/api.php';

  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];
    if (GunduaApiClient.isConfigured) {
      final q = Uri.encodeQueryComponent(query.trim());
      final response = await GunduaApiClient().get('/geo/search?q=$q') as Map;
      return (response['items'] as List).whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)).toList();
    }
    _ensureApiKey();

    final uri = Uri.parse(_geoapifyUrl).replace(
      queryParameters: {
        'text': query.trim(),
        'format': 'json',
        'lang': 'pt',
        'limit': '10',
        'apiKey': _apiKey,
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'Geoapify (${response.statusCode}): ${_responseMessage(response.body)}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];

    return results.map((result) {
      final place = result as Map<String, dynamic>;

      return <String, dynamic>{
        ...place,
        'name': place['name'] ??
            place['address_line1'] ??
            place['city'] ??
            place['formatted'] ??
            'Lugar sem nome',
        'location': place['formatted'] ?? '',
        'display_name': place['formatted'] ?? '',
        'country': place['country'] ?? '',
        'locality': place['city'] ??
            place['town'] ??
            place['village'] ??
            place['suburb'] ??
            place['county'] ??
            place['state'],
        'latitude': place['lat'],
        'longitude': place['lon'],
        'lat': place['lat'],
        'lon': place['lon'],
        'placeId': place['place_id'],
        'phone': place['phone'] ?? place['contact:phone'],
        'opening_hours': place['opening_hours'],
        'website': place['website'] ?? place['contact:website'],
        'image': null,
      };
    }).toList();
  }

  /// Procura pontos de interesse turísticos em redor de uma coordenada.
  /// A ordenação por proximidade é feita pela API Geoapify.
  Future<List<Map<String, dynamic>>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    int limit = 20,
    String categoryFilter = 'tourism,leisure.park',
  }) async {
    if (GunduaApiClient.isConfigured) {
      final query = Uri(queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'radius': radiusMeters.toString(),
        'limit': limit.toString(),
        'categories': categoryFilter,
      }).query;
      final response = await GunduaApiClient().get('/geo/nearby?$query') as Map;
      return (response['items'] as List).whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)).toList();
    }
    _ensureApiKey();
    final uri = Uri.https('api.geoapify.com', '/v2/places', {
      'categories': categoryFilter,
      'filter': 'circle:$longitude,$latitude,$radiusMeters',
      'bias': 'proximity:$longitude,$latitude',
      'limit': limit.toString(),
      'lang': 'pt',
      'apiKey': _apiKey,
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'Geoapify (${response.statusCode}): ${_responseMessage(response.body)}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'A resposta dos lugares próximos é inválida.',
      );
    }

    final features = decoded['features'];
    if (features is! List) return [];

    final places = <Map<String, dynamic>>[];

    for (final feature in features) {
      if (feature is! Map) continue;

      final properties = feature['properties'];
      if (properties is! Map) continue;

      final place = Map<String, dynamic>.from(properties);
      final geometry = feature['geometry'];
      final coordinates = geometry is Map ? geometry['coordinates'] : null;

      final latitudeValue =
          place['lat'] ??
          (coordinates is List && coordinates.length > 1
              ? coordinates[1]
              : null);
      final longitudeValue =
          place['lon'] ??
          (coordinates is List && coordinates.isNotEmpty
              ? coordinates[0]
              : null);

      if (latitudeValue is! num || longitudeValue is! num) continue;

      final name =
          place['name'] ?? place['address_line1'] ?? place['formatted'];
      if (name == null || name.toString().trim().isEmpty) continue;

      final categories = place['categories'];

      places.add({
        ...place,
        'name': name.toString(),
        'location': place['formatted'] ?? place['address_line2'] ?? '',
        'country': place['country'] ?? '',
        'locality': place['city'] ?? place['town'] ?? place['village'] ?? place['suburb'] ?? place['county'],
        'phone': place['phone'] ?? place['contact:phone'],
        'opening_hours': place['opening_hours'],
        'website': place['website'] ?? place['contact:website'],
        'latitude': latitudeValue.toDouble(),
        'longitude': longitudeValue.toDouble(),
        'lat': latitudeValue.toDouble(),
        'lon': longitudeValue.toDouble(),
        'placeId': place['place_id'],
        'categories': categories is List ? List<dynamic>.from(categories) : const <String>[],
        'category': categories is List && categories.isNotEmpty
            ? categories.map((item) => item.toString()).reduce((a, b) =>
                a.split('.').length >= b.split('.').length ? a : b)
            : 'Ponto de interesse',
        'image': null,
      });
    }

    return places;
  }

  /// Consulta o Google Places exclusivamente através do servidor GUNDUA.
  /// Com GUNDUA_API_URL configurado, o endpoint é inferido automaticamente;
  /// GUNDUA_PLACES_PROXY_URL permite indicar um URL HTTPS explícito.
  Future<List<Map<String, dynamic>>> getGoogleTopRatedPlaces({
    required double latitude,
    required double longitude,
    int radiusMeters = 20000,
    int limit = 20,
    List<String> includedTypes = const [],
  }) async {
    const proxyOverride = String.fromEnvironment('GUNDUA_PLACES_PROXY_URL');
    final backendBase = GunduaApiClient.baseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    final endpoint = proxyOverride.trim().isNotEmpty
        ? proxyOverride.trim()
        : backendBase.isNotEmpty
            ? '$backendBase/places/google/nearby'
            : '';
    if (endpoint.isEmpty) {
      throw const PlaceRatingsUnavailable('Inicia sessão para ver classificações.');
    }
    final uri = endpoint.startsWith('/') ? Uri.base.resolve(endpoint) : Uri.parse(endpoint);
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const PlaceRatingsUnavailable();
    }
    // Evita pedidos HTTP bloqueados pelo Safari quando a app usa HTTPS.
    if (Uri.base.scheme == 'https' && uri.scheme != 'https') {
      throw const PlaceRatingsUnavailable();
    }

    late final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          ...await GunduaApiClient().authorizationHeaders(),
        },
        body: jsonEncode({
          'maxResultCount': limit.clamp(1, 20),
          if (includedTypes.isNotEmpty) 'includedTypes': includedTypes,
          'locationRestriction': {
            'circle': {
              'center': {'latitude': latitude, 'longitude': longitude},
              'radius': radiusMeters.toDouble(),
            },
          },
        }),
      ).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const PlaceRatingsUnavailable('Sem resposta das classificações. Tenta novamente.');
    } on http.ClientException {
      throw const PlaceRatingsUnavailable('Não foi possível ligar às classificações.');
    }

    if (response.statusCode == 401) {
      throw const PlaceRatingsUnavailable('Inicia sessão para ver classificações.');
    }
    if (response.statusCode == 429) {
      throw const PlaceRatingsUnavailable('Tenta consultar as classificações mais tarde.');
    }
    if (response.statusCode != 200) {
      throw const PlaceRatingsUnavailable();
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return [];
    final results = decoded['places'];
    if (results is! List) return [];

    final places = <Map<String, dynamic>>[];
    for (final item in results) {
      if (item is! Map) continue;
      final place = Map<String, dynamic>.from(item);
      final displayName = place['displayName'];
      final location = place['location'];
      if (displayName is! Map || location is! Map) continue;
      final lat = location['latitude'];
      final lon = location['longitude'];
      if (lat is! num || lon is! num) continue;
      final name = displayName['text']?.toString();
      if (name == null || name.isEmpty) continue;
      final types = place['types'];
      places.add({
        'name': name,
        'location': place['formattedAddress'] ?? '',
        'latitude': lat.toDouble(),
        'longitude': lon.toDouble(),
        'lat': lat.toDouble(),
        'lon': lon.toDouble(),
        'placeId': place['id'] ?? name,
        'category': types is List && types.isNotEmpty
            ? types.first.toString()
            : 'Ponto de interesse',
        'rating': place['rating'],
        'userRatingCount': place['userRatingCount'],
        'googleMapsUri': place['googleMapsUri'],
        'image': null,
      });
    }

    places.sort((a, b) {
      final ratingA = (a['rating'] as num?)?.toDouble() ?? 0;
      final ratingB = (b['rating'] as num?)?.toDouble() ?? 0;
      final byRating = ratingB.compareTo(ratingA);
      if (byRating != 0) return byRating;
      final countA = (a['userRatingCount'] as num?)?.toInt() ?? 0;
      final countB = (b['userRatingCount'] as num?)?.toInt() ?? 0;
      return countB.compareTo(countA);
    });
    return places;
  }

  /// Reúne lugares de sete classes distintas para uma lista de até 100.
  /// Google Nearby Search devolve no máximo 20 por pedido; a lista não é
  /// um ranking oficial global, mas uma selecção ordenada por avaliação.
  Future<List<Map<String, dynamic>>> getGoogleTop100Places({
    required double latitude,
    required double longitude,
    int radiusMeters = 20000,
  }) async {
    const categories = [
      'tourist_attraction', 'museum', 'restaurant', 'park',
      'art_gallery', 'church', 'beach',
    ];
    final byId = <String, Map<String, dynamic>>{};
    Object? firstError;
    for (final type in categories) {
      List<Map<String, dynamic>> batch;
      try {
        batch = await getGoogleTopRatedPlaces(
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radiusMeters,
          limit: 20,
          includedTypes: [type],
        );
      } on PlaceRatingsUnavailable catch (error) {
        firstError ??= error;
        break; 
      } catch (error) {
        firstError ??= error;
        continue;
      }
      for (final place in batch) {
        final id = (place['placeId'] ?? '').toString();
        final rating = (place['rating'] as num?)?.toDouble();
        if (id.isEmpty || rating == null || rating <= 0) continue;
        byId.putIfAbsent(id, () => place);
      }
    }
    if (byId.isEmpty && firstError != null) throw firstError;
    final results = byId.values.toList();
    // Penaliza estabelecimentos com apenas uma ou duas avaliações.
    double score(Map<String, dynamic> place) {
      final rating = (place['rating'] as num?)?.toDouble() ?? 0;
      final reviews = (place['userRatingCount'] as num?)?.toInt() ?? 0;
      const priorReviews = 50;
      const priorRating = 4.0;
      return (rating * reviews + priorRating * priorReviews) /
          (reviews + priorReviews);
    }
    results.sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      if (byScore != 0) return byScore;
      return ((b['userRatingCount'] as num?) ?? 0)
          .compareTo((a['userRatingCount'] as num?) ?? 0);
    });
    return results.take(100).toList();
  }

  /// Devolve até três lugares de uma categoria, dentro do raio indicado.
  /// A API ordena os resultados pela proximidade através do bias.
  Future<List<Map<String, dynamic>>> getNearbyPlacesByCategory({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required String category,
    int limit = 3,
  }) {
    return getNearbyPlaces(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      limit: limit,
      categoryFilter: category,
    );
  }

  /// Converte a posição GPS no nome da localidade mais próxima.
  Future<String?> getLocationName({
    required double latitude,
    required double longitude,
  }) async {
    _ensureApiKey();
    final uri = Uri.https('api.geoapify.com', '/v1/geocode/reverse', {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'format': 'json',
      'lang': 'pt',
      'apiKey': _apiKey,
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Geoapify (${response.statusCode}): ${_responseMessage(response.body)}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('A localização devolvida é inválida.');
    }

    final results = decoded['results'];
    if (results is! List || results.isEmpty) return null;

    final result = results.first;
    if (result is! Map) return null;

    final place = Map<String, dynamic>.from(result);
    final locality =
        place['city'] ??
        place['town'] ??
        place['village'] ??
        place['suburb'] ??
        place['county'] ??
        place['state'];

    final name = locality?.toString().trim();
    if (name != null && name.isNotEmpty) return name;

    final formatted = place['formatted']?.toString().trim();
    return formatted == null || formatted.isEmpty ? null : formatted;
  }

  Future<String?> searchPlaceImage(String query) async {
    try {
      final uri = Uri.parse(_wikimediaUrl).replace(
        queryParameters: {
          'action': 'query',
          'format': 'json',
          'generator': 'search',
          'gsrsearch': query,
          'gsrnamespace': '6',
          'gsrlimit': '5',
          'prop': 'imageinfo',
          'iiprop': 'url',
          'iiurlwidth': '600',
          'origin': '*',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final pages = data['query']?['pages'] as Map<String, dynamic>?;

      if (pages == null || pages.isEmpty) return null;

      for (final page in pages.values) {
        final imageInfo = page['imageinfo'] as List<dynamic>?;

        if (imageInfo == null || imageInfo.isEmpty) continue;

        final image = imageInfo.first as Map<String, dynamic>;
        final imageUrl = image['thumburl'] ?? image['url'];

        if (imageUrl != null) {
          return imageUrl.toString();
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  String _responseMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        final message = decoded['message'] ??
            (error is Map ? error['message'] : error) ??
            decoded['error_description'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
    } catch (_) {
      // A resposta pode não ser JSON.
    }
    final compact = body.trim();
    return compact.isEmpty ? 'Resposta vazia do servidor.' :
        compact.substring(0, compact.length > 240 ? 240 : compact.length);
  }

  void _ensureApiKey() {
    if (_apiKey.isEmpty) {
      throw StateError(
        'Configura GEOAPIFY_API_KEY com --dart-define antes de usar a pesquisa de lugares.',
      );
    }
  }
}
