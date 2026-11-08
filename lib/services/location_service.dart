import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gundua_api_client.dart';


class LocationService {
  static Future<Position> getCurrentPosition() async {
    if (kIsWeb && !_secureBrowserContext) {
      throw StateError(
        'Não foi possível aceder ao GPS. Muda para uma ligação segura (HTTPS) ou altera a rede. '
      );
    }

    try {
      // Alguns navegadores não implementam a Permissions API e devolvem
      // «denied» mesmo quando getCurrentPosition pode solicitar autorização.
      if (!kIsWeb) {
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw StateError(
            'Os serviços de localização estão desligados. Activa-os nas definições.',
          );
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.unableToDetermine) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          throw StateError(
            'A permissão foi bloqueada. Autoriza a localização nas definições do dispositivo.',
          );
        }
        if (permission == LocationPermission.denied) {
          throw StateError('Sem permissão de localização. Escolhe uma cidade.');
        }
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 22),
        ),
      );
    } on TimeoutException {
      throw StateError('Sem sinal de GPS. Tenta de novo ou seleciona uma cidade.');
    } on PermissionDeniedException {
      throw StateError('Sem acesso à localização. Dá permissão no navegador ou escolhe uma cidade..');
    } on LocationServiceDisabledException {
      throw StateError('A localização está desactivada nas definições do dispositivo.');
    }
  }

  static bool get _secureBrowserContext {
    final url = Uri.base;
    return url.scheme == 'https' ||
        url.host == 'localhost' || url.host == '127.0.0.1';
  }
}

class AppLocation {
  final String label;
  final double latitude;
  final double longitude;
  final bool isDeviceLocation;

  const AppLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.isDeviceLocation,
  });
}

/// Guarda a última localização escolhida, incluindo as escolhas manuais.
/// Não pede permissões automaticamente no arranque da aplicação.
class LocationPreferenceService {
  /// Uma fonte de estado partilhada por Home, Explore e o selector de local.
  /// A seleção é persistida no dispositivo e notifica as páginas abertas.
  static final ValueNotifier<AppLocation?> selection = ValueNotifier(null);

  static const _key = 'gundua_selected_location';

  Future<AppLocation?> getSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_key);
    if (values == null || values.length != 4) {
      if (GunduaApiClient.isConfigured && await GunduaApiClient().hasSession) {
        final data = await GunduaApiClient().get('/me/location') as Map;
        final remote = data['location'];
        if (remote is Map) {
          final restored = AppLocation(
            label: remote['label'].toString(),
            latitude: (remote['latitude'] as num).toDouble(),
            longitude: (remote['longitude'] as num).toDouble(),
            isDeviceLocation: remote['isDeviceLocation'] == true,
          );
          await save(restored);
          return restored;
        }
      }
      if (selection.value != null) selection.value = null;
      return null;
    }
    final lat = double.tryParse(values[1]);
    final lon = double.tryParse(values[2]);
    if (lat == null || lon == null) return null;
    final restored = AppLocation(
      label: values[0],
      latitude: lat,
      longitude: lon,
      isDeviceLocation: values[3] == 'gps',
    );
    // Não emitir eventos quando as coordenadas já estão no estado global.
    if (selection.value?.latitude != restored.latitude ||
        selection.value?.longitude != restored.longitude ||
        selection.value?.label != restored.label) {
      selection.value = restored;
    }
    return restored;
  }

  Future<void> save(AppLocation location) async {
    if (GunduaApiClient.isConfigured && await GunduaApiClient().hasSession) {
      await GunduaApiClient().put('/me/location', {
        'label': location.label,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'isDeviceLocation': location.isDeviceLocation,
      });
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = await prefs.setStringList(_key, [
      location.label, location.latitude.toString(),
      location.longitude.toString(),
      location.isDeviceLocation ? 'gps' : 'manual',
    ]);
    if (!stored) throw StateError('Não foi possível guardar a localização.');
    selection.value = location;
  }

  /// O local é mantido ao mudar de aba e eliminado apenas no logout.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    selection.value = null;
  }
}
