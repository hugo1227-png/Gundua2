import 'dart:convert';

import 'package:http/http.dart' as http;

/// Obtém descrições da Wikipédia e fotografias do Wikimedia Commons.
class TourismService {
  static const Duration _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>?> getPlaceInformation(String placeName) async {
    final query = placeName.trim();
    if (query.isEmpty) return null;

    // A pesquisa usa a Action API, por isso inclui origin=* para CORS.
    final searchUri = Uri.https('pt.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'list': 'search',
      'srsearch': query,
      'srlimit': '1',
      'format': 'json',
      'origin': '*',
    });

    try {
      final searchResponse = await http.get(searchUri).timeout(_timeout);

      if (searchResponse.statusCode != 200) {
        throw Exception('Não foi possível pesquisar na Wikipédia.');
      }

      final searchData = _decodeJson(searchResponse.body);
      final results = searchData['query']?['search'];
      if (results is! List || results.isEmpty) return null;

      final firstResult = results.first;
      if (firstResult is! Map<String, dynamic>) return null;

      final title = firstResult['title']?.toString().trim() ?? '';
      if (title.isEmpty) return null;

      final encodedTitle = Uri.encodeComponent(title.replaceAll(' ', '_'));
      final summaryUri = Uri.parse(
        'https://pt.wikipedia.org/api/rest_v1/page/summary/$encodedTitle',
      );

      final summaryResponse = await http.get(summaryUri).timeout(_timeout);

      if (summaryResponse.statusCode == 404) return null;
      if (summaryResponse.statusCode != 200) {
        throw Exception('Não foi possível carregar a descrição do lugar.');
      }

      final summary = _decodeJson(summaryResponse.body);
      if (summary['type'] == 'disambiguation') return null;

      return summary;
    } on http.ClientException {
      throw Exception('Não foi possível estabelecer ligação à Wikipédia.');
    } on FormatException {
      throw Exception('A Wikipédia devolveu uma resposta inválida.');
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception('Ocorreu um erro ao obter informação turística.');
    }
  }

  Future<List<Map<String, dynamic>>> searchPlaceImages(String placeName) async {
    final query = placeName.trim();
    if (query.isEmpty) return [];

    // A Action API do Commons também precisa de origin=* em pedidos CORS.
    final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': query,
      'gsrnamespace': '6',
      'gsrlimit': '8',
      'gsrwhat': 'text',
      'prop': 'imageinfo',
      'iiprop': 'url|extmetadata',
      'iiurlwidth': '1000',
      'format': 'json',
      'origin': '*',
    });

    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw Exception('Não foi possível carregar as fotografias.');
      }

      final data = _decodeJson(response.body);
      final pages = data['query']?['pages'];
      if (pages is! Map<String, dynamic>) return [];

      final images = <Map<String, dynamic>>[];

      for (final pageValue in pages.values) {
        if (pageValue is! Map<String, dynamic>) continue;

        final imageInfoList = pageValue['imageinfo'];
        if (imageInfoList is! List || imageInfoList.isEmpty) continue;

        final imageInfo = imageInfoList.first;
        if (imageInfo is! Map<String, dynamic>) continue;

        final metadataValue = imageInfo['extmetadata'];
        final metadata = metadataValue is Map<String, dynamic>
            ? metadataValue
            : <String, dynamic>{};

        final imageUrl =
            imageInfo['thumburl']?.toString() ??
            imageInfo['url']?.toString() ??
            '';
        if (!_isHttpUrl(imageUrl)) continue;

        images.add({
          'title': pageValue['title']?.toString() ?? 'Fotografia',
          'imageUrl': imageUrl,
          'descriptionUrl': imageInfo['descriptionurl']?.toString() ?? '',
          'artist': _metadataValue(metadata, 'Artist'),
          'credit': _metadataValue(metadata, 'Credit'),
          'license': _metadataValue(metadata, 'LicenseShortName'),
          'licenseUrl': _metadataValue(metadata, 'LicenseUrl'),
        });
      }

      return images;
    } on http.ClientException {
      throw Exception(
        'Não foi possível estabelecer ligação ao Wikimedia Commons.',
      );
    } on FormatException {
      throw Exception('O Wikimedia Commons devolveu uma resposta inválida.');
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception('Ocorreu um erro ao carregar as fotografias.');
    }
  }

  Map<String, dynamic> _decodeJson(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Formato JSON inválido.');
    }
    return decoded;
  }

  String _metadataValue(Map<String, dynamic> metadata, String key) {
    final entry = metadata[key];
    if (entry is! Map<String, dynamic>) return '';

    final value = entry['value']?.toString() ?? '';
    return value
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}
