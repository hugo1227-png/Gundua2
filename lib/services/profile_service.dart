import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gundua_api_client.dart';

/// Stores a lightweight, device-local profile.
/// This is not a replacement for a secure server-side authentication provider.
class ProfileService {
  static const String _nameKey = 'gundua_profile_name';
  static const String _bioKey = 'gundua_profile_bio';
  static const String _usernameKey = 'gundua_profile_username';
  static const String _interestsKey = 'gundua_profile_interests';
  static const String _avatarKey = 'gundua_profile_avatar';
  static const String _locationKey = 'gundua_profile_location';
  static const String _emailKey = 'gundua_profile_email';
  static const String _saltKey = 'gundua_local_auth_salt';
  static const String _passwordHashKey = 'gundua_local_auth_hash';
  static const String _loggedInKey = 'gundua_local_auth_logged_in';

  Future<Map<String, String>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_nameKey) ?? 'Viajante',
      'bio': prefs.getString(_bioKey) ?? 'A descobrir lugares e experiências.',
      'location': prefs.getString(_locationKey) ?? '',
      'email': prefs.getString(_emailKey) ?? '',
      'username': prefs.getString(_usernameKey) ?? '',
      'interests': prefs.getString(_interestsKey) ?? '',
      'avatar': prefs.getString(_avatarKey) ?? '',
    };
  }

  Future<bool> hasLocalAccount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_passwordHashKey) && prefs.containsKey(_emailKey);
  }

  Future<bool> isLoggedIn() async {
    if (GunduaApiClient.isConfigured) {
      return GunduaApiClient().hasSession;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedInKey) ?? false;
  }

  Future<void> createLocalAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();

    if (cleanName.isEmpty) {
      throw ArgumentError('Indica o teu nome.');
    }
    if (!_isValidEmail(cleanEmail)) {
      throw ArgumentError('Indica um email válido.');
    }
    if (password.length < 8) {
      throw ArgumentError('A palavra-passe deve ter pelo menos 8 caracteres.');
    }

    if (GunduaApiClient.isConfigured) {
      final api = GunduaApiClient();
      final data = await api.post('/auth/register', {
        'name': cleanName,
        'email': cleanEmail,
        'password': password,
      }) as Map<String, dynamic>;
      await api.saveSession(data['token'] as String);
      await _cacheServerUser(Map<String, dynamic>.from(data['user'] as Map));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final existingEmail = prefs.getString(_emailKey);
    if (existingEmail != null && existingEmail.isNotEmpty) {
      throw StateError('Já existe uma conta guardada.');
    }

    final salt = _createSalt();
    final hash = _hashPassword(password, salt);
    final saved = await Future.wait([
      prefs.setString(_nameKey, cleanName),
      prefs.setString(_bioKey, 'A descobrir lugares e experiências.'),
      prefs.setString(_locationKey, ''),
      prefs.setString(_emailKey, cleanEmail),
      prefs.setString(_saltKey, salt),
      prefs.setString(_passwordHashKey, hash),
      prefs.setBool(_loggedInKey, true),
    ]);

    if (saved.any((value) => !value)) {
      throw Exception('Não foi possível guardar a conta neste dispositivo.');
    }
  }

  Future<bool> signInLocally({
    required String email,
    required String password,
  }) async {
    if (GunduaApiClient.isConfigured) {
      final api = GunduaApiClient();
      try {
        final data = await api.post('/auth/login', {
          'email': email.trim().toLowerCase(),
          'password': password,
        }) as Map<String, dynamic>;
        await api.saveSession(data['token'] as String);
        await _cacheServerUser(Map<String, dynamic>.from(data['user'] as Map));
        return true;
      } on GunduaApiException catch (error) {
        if (error.statusCode == 401) return false;
        rethrow;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_emailKey);
    final salt = prefs.getString(_saltKey);
    final savedHash = prefs.getString(_passwordHashKey);

    if (savedEmail == null || salt == null || savedHash == null) {
      return false;
    }
    if (savedEmail != email.trim().toLowerCase()) {
      return false;
    }
    if (_hashPassword(password, salt) != savedHash) {
      return false;
    }

    await prefs.setBool(_loggedInKey, true);
    return true;
  }

  Future<void> signOut() async {
    if (GunduaApiClient.isConfigured) {
      final api = GunduaApiClient();
      try {
        await api.post('/auth/logout');
      } catch (_) {
        // Mesmo sem ligação, o utilizador consegue encerrar a sessão local.
      } finally {
        await api.clearSession();
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, false);
  }

  Future<void> updateProfile({
    required String name,
    required String bio,
    String location = '',
    String? username,
    String? interests,
    String? avatarBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('O nome não pode estar vazio.');
    }
    if (username != null && username.trim().isNotEmpty &&
        !RegExp(r'^[a-zA-Z0-9_.]{3,24}$').hasMatch(username.trim())) {
      throw ArgumentError('O nome deve ter 3 a 24 caracteres (letras, números e _)..');
    }

    if (GunduaApiClient.isConfigured) {
      await GunduaApiClient().patch('/me', {
        'name': cleanName,
        'bio': bio.trim(),
        'location': location.trim(),
        if (username != null) 'username': username.trim(),
        if (interests != null) 'interests': interests.trim(),
        'avatar': ?avatarBase64,
      });
    }
    final values = await Future.wait([
      prefs.setString(_nameKey, cleanName),
      prefs.setString(_bioKey, bio.trim()),
      prefs.setString(_locationKey, location.trim()),
    ]);
    if (username != null) {
      values.add(await prefs.setString(_usernameKey, username.trim()));
    }
    if (interests != null) {
      values.add(await prefs.setString(_interestsKey, interests.trim()));
    }
    if (avatarBase64 != null) {
      values.add(await prefs.setString(_avatarKey, avatarBase64));
    }
    if (values.any((value) => !value)) {
      throw Exception('Não foi possível guardar o perfil.');
    }
  }

  Future<void> _cacheServerUser(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_nameKey, (data['name'] ?? '').toString()),
      prefs.setString(_emailKey, (data['email'] ?? '').toString()),
      prefs.setString(_usernameKey, (data['username'] ?? '').toString()),
      prefs.setString(_bioKey, (data['bio'] ?? '').toString()),
      prefs.setString(_locationKey, (data['location'] ?? '').toString()),
      prefs.setString(_interestsKey, (data['interests'] ?? '').toString()),
      prefs.setString(_avatarKey, (data['avatar'] ?? '').toString()),
      prefs.setBool(_loggedInKey, true),
    ]);
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  String _createSalt() {
    final random = Random.secure();
    return List<int>.generate(24, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  String _hashPassword(String password, String salt) {
    // PBKDF2-HMAC-SHA256: deliberately slower than a single SHA-256 pass.
    const iterations = 120000;
    final hmac = Hmac(sha256, utf8.encode(password));
    final saltBytes = _decodeHex(salt);
    final block = [...saltBytes, 0, 0, 0, 1];
    var u = hmac.convert(block).bytes;
    final output = Uint8List.fromList(u);

    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var byte = 0; byte < output.length; byte++) {
        output[byte] ^= u[byte];
      }
    }

    return output
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  List<int> _decodeHex(String value) {
    final bytes = <int>[];
    for (var i = 0; i + 1 < value.length; i += 2) {
      bytes.add(int.parse(value.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
