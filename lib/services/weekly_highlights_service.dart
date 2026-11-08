import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'gundua_api_client.dart';

/// Histórico de visualizações do próprio dispositivo. Não representa
/// estatísticas globais de visitantes nem lugares físicos frequentados.
class WeeklyHighlightsService {
  static const _key = 'gundua_weekly_place_views';

  Future<void> recordView(Map<String, dynamic> place, {DateTime? at}) async {
    if (GunduaApiClient.isConfigured && await GunduaApiClient().hasSession) {
      await GunduaApiClient().post('/me/views', {'place': place});
    }
    final prefs = await SharedPreferences.getInstance();
    final now = at ?? DateTime.now();
    final recent = await _events(now);
    recent.add({'time': now.toIso8601String(), 'place': place});
    await prefs.setString(_key, jsonEncode(recent.take(500).toList()));
  }

  /// A API conta marcações explícitas de visitas de todos os participantes.
  /// Não mede presença GPS nem número físico de visitantes.
  Future<Map<String, dynamic>?> communityMostVisited() async {
    if (!GunduaApiClient.isConfigured) return null;
    final data = await GunduaApiClient().get('/analytics/weekly?metric=visits') as Map;
    final result = data['result'];
    if (result is! Map) return null;
    final place = result['place'];
    if (place is! Map) return null;
    return {
      ...Map<String, dynamic>.from(place),
      'weeklyCommunityVisitCount': result['count'],
    };
  }

  Future<Map<String, dynamic>?> mostViewedByMe({DateTime? at}) async {
    final events = await _events(at ?? DateTime.now());
    final counts = <String, int>{};
    final places = <String, Map<String, dynamic>>{};
    for (final event in events) {
      final place = event['place'];
      if (place is! Map) continue;
      final data = Map<String, dynamic>.from(place);
      final id = (data['placeId'] ?? data['place_id'] ??
          '${data['name']}_${data['latitude']}_${data['longitude']}').toString();
      counts[id] = (counts[id] ?? 0) + 1;
      places[id] = data;
    }
    if (counts.isEmpty) return null;
    final best = counts.keys.reduce((a, b) =>
        counts[a]! >= counts[b]! ? a : b);
    return {...places[best]!, 'weeklyViewCountOnDevice': counts[best]};
  }

  Future<List<Map<String, dynamic>>> _events(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final since = now.subtract(const Duration(days: 7));
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e))
          .where((event) {
            final date = DateTime.tryParse((event['time'] ?? '').toString());
            return date != null && !date.isBefore(since) && !date.isAfter(now);
          }).toList();
    } catch (_) {
      return [];
    }
  }
}
