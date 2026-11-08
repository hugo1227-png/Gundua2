import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../services/place_service.dart';

/// Modal única para Home e Explore: GPS ou pesquisa manual de localidade.
class LocationPicker {
  static Future<AppLocation?> show(BuildContext context) {
    return showModalBottomSheet<AppLocation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _LocationPickerSheet(),
    );
  }
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet();

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _controller = TextEditingController();
  final _places = PlaceService();
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() { _busy = true; _error = null; });
    try {
      final position = await LocationService.getCurrentPosition();
      String label = 'Perto de ti';
      try {
        label = await _places.getLocationName(
          latitude: position.latitude,
          longitude: position.longitude,
        ) ?? label;
      } catch (_) {
        // GPS válido mesmo que a geocodificação inversa falhe.
      }
      final location = AppLocation(
        label: label,
        latitude: position.latitude,
        longitude: position.longitude,
        isDeviceLocation: true,
      );
      await LocationPreferenceService().save(location);
      if (mounted) Navigator.of(context).pop(location);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _searchCity() async {
    final text = _controller.text.trim();
    if (text.length < 2) {
      setState(() => _error = 'Escreve o nome de uma cidade ou bairro.');
      return;
    }
    setState(() { _busy = true; _error = null; _results = []; });
    try {
      final results = await _places.searchPlaces(text);
      if (!mounted) return;
      setState(() {
        _results = results.where((place) =>
            place['latitude'] is num && place['longitude'] is num).toList();
        if (_results.isEmpty) _error = 'Não encontrámos essa localidade.';
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose(Map<String, dynamic> place) async {
    final location = AppLocation(
      label: (place['name'] ?? place['location'] ?? _controller.text).toString(),
      latitude: (place['latitude'] as num).toDouble(),
      longitude: (place['longitude'] as num).toDouble(),
      isDeviceLocation: false,
    );
    await LocationPreferenceService().save(location);
    if (mounted) Navigator.of(context).pop(location);
  }

  String _message(Object error) => error.toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 22, right: 22, top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom - 70)
            .clamp(220.0, MediaQuery.sizeOf(context).height * .58).toDouble(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Onde queres descobrir?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Usa o GPS ou escolhe uma localidade manualmente.',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _useGps,
              icon: const Icon(Icons.my_location),
              label: const Text('Usar a minha localização'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchCity(),
                  decoration: const InputDecoration(
                    hintText: 'Cidade, país ou bairro',
                    prefixIcon: Icon(Icons.place_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _busy ? null : _searchCity,
                icon: const Icon(Icons.search),
              ),
            ]),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final place = _results[index];
                  return ListTile(
                    leading: const Icon(Icons.location_city_outlined),
                    title: Text((place['name'] ?? 'Localidade').toString()),
                    subtitle: Text((place['location'] ?? '').toString(),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => _choose(place),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
