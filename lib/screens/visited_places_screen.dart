import 'package:flutter/material.dart';

import '../services/visited_places_service.dart';
import 'place_details_screen.dart';

class VisitedPlacesScreen extends StatefulWidget {
  const VisitedPlacesScreen({super.key});

  @override
  State<VisitedPlacesScreen> createState() => _VisitedPlacesScreenState();
}

class _VisitedPlacesScreenState extends State<VisitedPlacesScreen> {
  static const Color background = Color(0xFFF8F9FA);
  static const Color textColor = Color(0xFF111111);
  static const Color secondaryColor = Color(0xFF767676);
  static const Color accentColor = Color(0xFFFF5A5F);

  final VisitedPlacesService _visitedPlacesService = VisitedPlacesService();

  List<Map<String, dynamic>> _places = [];
  bool _isLoading = true;
  bool _isRemoving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final places = await _visitedPlacesService.getVisitedPlaces();
      if (!mounted) return;

      setState(() {
        _places = places.reversed.toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Não foi possível carregar os lugares visitados.';
      });
      debugPrint('Erro ao carregar lugares visitados: $error');
    }
  }

  String _placeName(Map<String, dynamic> place) {
    final name = place['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;

    final displayName = place['display_name']?.toString().trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName.split(',').first.trim();
    }

    return 'Lugar sem nome';
  }

  String _placeLocation(Map<String, dynamic> place) {
    final location = place['location']?.toString().trim() ?? '';
    if (location.isNotEmpty) return location;

    final displayName = place['display_name']?.toString().trim() ?? '';
    if (displayName.isNotEmpty) return displayName;

    final latitude = (place['latitude'] ?? place['lat'])?.toString() ?? '';
    final longitude = (place['longitude'] ?? place['lon'])?.toString() ?? '';

    if (latitude.isNotEmpty && longitude.isNotEmpty) {
      return 'Coordenadas: $latitude, $longitude';
    }

    return 'Localização não disponível';
  }

  Map<String, dynamic> _preparePlace(Map<String, dynamic> place) {
    final address = place['address'];
    String country = place['country']?.toString() ?? '';

    if (country.isEmpty && address is Map) {
      country = address['country']?.toString() ?? '';
    }

    return {
      ...place,
      'name': _placeName(place),
      'location': _placeLocation(place),
      'country': country,
      'image': place['image'] ?? place['image_url'],
      'latitude': place['latitude'] ?? place['lat'],
      'longitude': place['longitude'] ?? place['lon'],
    };
  }

  Future<void> _openPlace(Map<String, dynamic> place) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceDetailsScreen(place: _preparePlace(place)),
      ),
    );

    if (mounted) await _loadPlaces();
  }

  Future<void> _removePlace(Map<String, dynamic> place) async {
    if (_isRemoving) return;

    setState(() => _isRemoving = true);

    try {
      await _visitedPlacesService.removeVisitedPlace(place);
      if (!mounted) return;

      final id = _visitedPlacesService.getPlaceId(place);
      setState(() {
        _places.removeWhere(
          (item) => _visitedPlacesService.getPlaceId(item) == id,
        );
        _isRemoving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lugar removido dos visitados.')),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _isRemoving = false);
      debugPrint('Erro ao remover lugar visitado: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível remover o lugar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Lugares visitados',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: textColor),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadPlaces,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: accentColor));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: secondaryColor,
              ),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: secondaryColor),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _loadPlaces,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_places.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.travel_explore_outlined,
                size: 62,
                color: secondaryColor,
              ),
              SizedBox(height: 16),
              Text(
                'Ainda não visitaste nenhum lugar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Quando marcares um lugar como visitado, ele aparecerá aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: accentColor,
      onRefresh: _loadPlaces,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        itemCount: _places.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 18),
              child: Text(
                'Os lugares que já descobriste.',
                style: TextStyle(color: secondaryColor, fontSize: 14),
              ),
            );
          }

          return _buildPlaceCard(_places[index - 1]);
        },
      ),
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
    final name = _placeName(place);
    final location = _placeLocation(place);
    final image = (place['image'] ?? place['image_url'])?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => _openPlace(place),
            child: Row(
              children: [
                SizedBox(
                  width: 112,
                  height: 112,
                  child: image != null && image.isNotEmpty
                      ? Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _photoPlaceholder(),
                        )
                      : _photoPlaceholder(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          location,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: secondaryColor,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.chevron_right, color: secondaryColor),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isRemoving ? null : () => _removePlace(place),
              icon: const Icon(
                Icons.delete_outline,
                color: accentColor,
                size: 19,
              ),
              label: const Text(
                'Remover do histórico',
                style: TextStyle(color: secondaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() {
    return const ColoredBox(
      color: Color(0xFFEDEEEF),
      child: Center(
        child: Icon(Icons.place_outlined, size: 34, color: secondaryColor),
      ),
    );
  }
}
