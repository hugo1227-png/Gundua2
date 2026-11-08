import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cliente REST comum à app. Sem GUNDUA_API_URL, a alfa continua em modo local.
/// O servidor deve estar acessível pelo próprio dispositivo (não apenas pelo Mac).
class GunduaApiClient {
  static const String baseUrl = String.fromEnvironment('GUNDUA_API_URL');
  static const String _tokenKey = 'gundua_api_session';

  static bool get isConfigured => baseUrl.trim().isNotEmpty;

  Future<bool> get hasSession async {
    if (!isConfigured) return false;
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_tokenKey) ?? '').isNotEmpty;
  }

  Future<void> saveSession(String token) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_tokenKey, token)) {
      throw StateError('Não foi possível guardar a sessão.');
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Usa a mesma sessão tanto na API como no proxy Google Places.
  Future<Map<String, String>> authorizationHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token == null || token.isEmpty
        ? <String, String>{}
        : <String, String>{'Authorization': 'Bearer $token'};
  }

  Future<dynamic> get(String path) => _request('GET', path);
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _request('POST', path, body);
  Future<dynamic> put(String path, [Map<String, dynamic>? body]) =>
      _request('PUT', path, body);
  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) =>
      _request('PATCH', path, body);
  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<dynamic> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = '$base$path';
    final uri = base.startsWith('/') ? Uri.base.resolve(url) : Uri.parse(url);
    final request = http.Request(method, uri);
    request.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final client = http.Client();
    try {
      final stream = await client.send(request).timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(stream);
      final payload = response.body.isEmpty ? null : jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = payload is Map ? payload['error']?.toString() : null;
        throw GunduaApiException(
          response.statusCode,
          message ?? 'Erro de comunicação.',
        );
      }
      return payload;
    } on GunduaApiException {
      rethrow;
    } catch (error) {
      throw StateError('Sem ligação ao servidor,');
    } finally {
      client.close();
    }
  }
}

class GunduaApiException implements Exception {
  final int statusCode;
  final String message;

  const GunduaApiException(this.statusCode, this.message);

  @override
  String toString() => 'API ($statusCode): $message';
}
