import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/place.dart';
import '../services/location_service.dart';
import '../services/place_service.dart';
import 'place_details_screen.dart';
import '../theme/gundua_theme.dart';
import '../widgets/location_picker.dart';

class NearbyMapScreen extends StatefulWidget {
  const NearbyMapScreen({super.key});

  @override
  State<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends State<NearbyMapScreen> {
  static const Color background = GunduaTheme.canvas;
  static const Color textColor = GunduaTheme.ink;
  static const Color secondaryColor = GunduaTheme.muted;
  static const Color accentColor = GunduaTheme.accent;
  static const int _radiusMeters = 5000;

  static const List<_PlaceCategory> _categories = [
    _PlaceCategory('Restaurantes', 'catering.restaurant', Icons.restaurant),
    _PlaceCategory('Monumentos', 'tourism.sights', Icons.account_balance),
    _PlaceCategory('Museus', 'entertainment.museum', Icons.museum),
    _PlaceCategory('Natureza', 'natural,leisure.park', Icons.park),
    _PlaceCategory('Cultura', 'entertainment.culture', Icons.theater_comedy),
    _PlaceCategory('Praias', 'beach', Icons.beach_access),
  ];

  final PlaceService _placeService = PlaceService();
  final MapController _mapController = MapController();
  final Set<String> _selectedCategories = _categories
      .map((category) => category.label)
      .toSet();

  List<Place> _places = [];
  LatLng? _userPosition;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNearbyPlaces();
  }

  Future<void> _chooseLocation() async {
    final chosen = await LocationPicker.show(context);
    if (!mounted || chosen == null) return;
    setState(() => _userPosition = LatLng(chosen.latitude, chosen.longitude));
    await _loadNearbyPlaces();
  }

  Future<void> _loadNearbyPlaces() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final center = _userPosition ?? await _getUserPosition();
      final activeCategories = _categories
          .where((category) => _selectedCategories.contains(category.label))
          .toList();

      final results = await Future.wait(
        activeCategories.map((category) {
          return _placeService.getNearbyPlacesByCategory(
            latitude: center.latitude,
            longitude: center.longitude,
            radiusMeters: _radiusMeters,
            category: category.apiCategory,
            limit: 3,
          );
        }),
      );

      final places = <Place>[];
      final seenPlaceIds = <String>{};

      for (var index = 0; index < results.length; index++) {
        final category = activeCategories[index];
        final categoryPlaces =
            results[index].map((result) {
              final data = Map<String, dynamic>.from(result);
              data['categoryLabel'] = category.label;
              final place = Place.fromMap(data);
              final distance = Geolocator.distanceBetween(
                center.latitude,
                center.longitude,
                place.latitude,
                place.longitude,
              );
              return place.copyWith(distanceMeters: distance);
            }).toList()..sort((first, second) {
              final firstVisits = first.visitCount ?? 0;
              final secondVisits = second.visitCount ?? 0;
              if (firstVisits != secondVisits) {
                return secondVisits.compareTo(firstVisits);
              }
              return (first.distanceMeters ?? 0).compareTo(second.distanceMeters ?? 0);
            });

        for (final place in categoryPlaces.take(3)) {
          if (seenPlaceIds.add(place.id)) places.add(place);
        }
      }

      if (!mounted) return;
      setState(() {
        _userPosition = center;
        _places = places;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Não foi possível carregar o mapa. Escolhe uma localização e tenta novamente.';
      });
    }
  }

  Future<LatLng> _getUserPosition() async {
    final selected = await LocationPreferenceService().getSelected();
    if (selected != null) return LatLng(selected.latitude, selected.longitude);
    throw StateError('Define uma localização para explorar o mapa.');
  }

  Future<void> _toggleCategory(_PlaceCategory category) async {
    setState(() {
      if (_selectedCategories.contains(category.label)) {
        _selectedCategories.remove(category.label);
      } else {
        _selectedCategories.add(category.label);
      }
    });
    await _loadNearbyPlaces();
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Restaurantes':
        return Icons.restaurant;
      case 'Monumentos':
        return Icons.account_balance;
      case 'Museus':
        return Icons.museum;
      case 'Natureza':
        return Icons.park;
      case 'Cultura':
        return Icons.theater_comedy;
      case 'Praias':
        return Icons.beach_access;
      default:
        return Icons.place;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Restaurantes':
        return const Color(0xFFE67E22);
      case 'Monumentos':
        return const Color(0xFF5965A8);
      case 'Museus':
        return const Color(0xFF8E5EA2);
      case 'Natureza':
        return const Color(0xFF4D936B);
      case 'Cultura':
        return const Color(0xFFB45D79);
      case 'Praias':
        return const Color(0xFF3D91B8);
      default:
        return accentColor;
    }
  }

  void _showPlace(Place place) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 145,
                  width: double.infinity,
                  child: place.imageUrl != null && place.imageUrl!.isNotEmpty
                      ? Image.network(
                          place.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _previewPlaceholder(),
                        )
                      : FutureBuilder<String?>(
                          future: _placeService.searchPlaceImage(place.name),
                          builder: (context, snapshot) {
                            final imageUrl = snapshot.data;
                            if (imageUrl == null || imageUrl.isEmpty) {
                              return _previewPlaceholder();
                            }
                            return Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _previewPlaceholder(),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      place.name,
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                '${place.category} · ${place.address}',
                style: const TextStyle(color: secondaryColor, fontSize: 12),
              ),
              if (place.distanceMeters != null) ...[
                const SizedBox(height: 5),
                Text(
                  _formatDistance(place.distanceMeters),
                  style: const TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (place.visitCount != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${place.visitCount} visitas registadas',
                  style: const TextStyle(color: secondaryColor, fontSize: 11),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PlaceDetailsScreen(place: place.toMap()),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: textColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Ver detalhes'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _previewPlaceholder() => const ColoredBox(
        color: Color(0xFFEDEEEF),
        child: Center(
          child: Icon(Icons.landscape_outlined, color: secondaryColor, size: 34),
        ),
      );

  String _formatDistance(double? meters) {
    if (meters == null) return 'Perto de ti';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: textColor,
        elevation: 0,
        title: const Text(
          'Lugares perto de mim',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 4, 18, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Até 3 lugares por categoria; a ordenação usa visitas quando essa métrica existe e, caso contrário, proximidade.',
                style: TextStyle(color: secondaryColor, fontSize: 11, height: 1.35),
              ),
            ),
          ),
          SizedBox(
            height: 58,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final selected = _selectedCategories.contains(category.label);
                return FilterChip(
                  selected: selected,
                  label: Text(category.label),
                  avatar: Icon(category.icon, size: 17),
                  onSelected: (_) => _toggleCategory(category),
                  selectedColor: const Color(0xFFFFE8E8),
                  checkmarkColor: accentColor,
                  side: BorderSide(
                    color: selected ? accentColor : const Color(0xFFEDEEEF),
                  ),
                  labelStyle: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  backgroundColor: Colors.white,
                );
              },
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (_userPosition != null)
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _userPosition!,
                      initialZoom: 12,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.gundua.proto2',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userPosition!,
                            width: 42,
                            height: 42,
                            child: const Icon(
                              Icons.my_location,
                              color: Color(0xFF2869D8),
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: _places.map((place) {
                          return Marker(
                            point: LatLng(place.latitude, place.longitude),
                            width: 48,
                            height: 52,
                            child: GestureDetector(
                              onTap: () => _showPlace(place),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _categoryColor(place.category),
                                  borderRadius: BorderRadius.circular(17),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x22000000),
                                      blurRadius: 7,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _categoryIcon(place.category),
                                  color: Colors.white,
                                  size: 23,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('© OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  )
                else
                  const SizedBox.expand(),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: accentColor),
                  ),
                if (_errorMessage != null && !_isLoading)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_off_outlined,
                            color: accentColor,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: textColor),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _chooseLocation,
                            icon: const Icon(Icons.place_outlined),
                            label: const Text('Escolher localização'),
                          ),
                          TextButton(
                            onPressed: _loadNearbyPlaces,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!_isLoading && _errorMessage == null)
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(color: Color(0x16000000), blurRadius: 10),
                        ],
                      ),
                      child: Text(
                        '${_places.length} lugares · até 3 por categoria · 5 km',
                        style: const TextStyle(
                          color: textColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceCategory {
  final String label;
  final String apiCategory;
  final IconData icon;

  const _PlaceCategory(this.label, this.apiCategory, this.icon);
}
