import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/gundua_theme.dart';

import '../models/place.dart';
import '../services/curated_places_service.dart';
import '../services/favorites_service.dart';
import '../services/gundua_api_client.dart';
import '../services/location_service.dart';
import '../services/place_service.dart';
import '../services/recently_viewed_service.dart';
import '../services/weekly_highlights_service.dart';
import 'nearby_map_screen.dart';
import 'place_details_screen.dart';
import '../widgets/location_picker.dart';
import '../widgets/place_photo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onGoExplore, this.onSearch, this.refreshToken = 0});

  final VoidCallback? onGoExplore;
  final ValueChanged<String>? onSearch;
  final int refreshToken;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color background = GunduaTheme.canvas;
  static const Color textColor = GunduaTheme.ink;
  static const Color secondaryColor = GunduaTheme.muted;
  static const Color accentColor = GunduaTheme.accent;
  static const Color cardColor = Colors.white;
  // Centro de Lisboa: serve apenas para procurar o Top 100 de Lisboa,
  // nunca substitui a localização do utilizador.
  static const double lisbonLatitude = 38.7223;
  static const double lisbonLongitude = -9.1393;

  final TextEditingController _searchController = TextEditingController();
  final PlaceService _placeService = PlaceService();
  final FavoritesService _favoritesService = FavoritesService();
  final RecentlyViewedService _recentlyViewedService = RecentlyViewedService();

  List<Map<String, dynamic>> _recentlyViewedPlaces = [];
  List<Place> _hiddenGems = CuratedPlacesService.lisbonHiddenGems
      .map(Place.fromMap)
      .toList();
  List<Place> _topPlaces = [];
  List<Place> _ratedTopPlaces = [];
  Map<String, dynamic>? _weeklyPlace;
  String? _ratingsError;
  bool _loadingRatings = false;
  int _locationRequestId = 0;
  int _ratingsRequestId = 0;
  final Set<String> _favoritePlaceIds = {};
  final Map<String, Future<String?>> _imageFutures = {};

  String _locationName = 'Localização por definir';
  bool _loadingRecentlyViewed = true;
  bool _isLoadingNearby = false;
  AppLocation? _selectedLocation;
  int _homeTab = 0;
  bool _openingPlace = false;
  String? _nearbyError;

  @override
  void initState() {
    super.initState();
    LocationPreferenceService.selection.addListener(_onLocationChanged);
    _loadRatedPlaces();
    _loadWeeklyHighlight();
    _loadRecentlyViewed();
    _loadFavoriteIds();
    _restoreSelectedLocation();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadRecentlyViewed();
        _loadFavoriteIds();
      _loadWeeklyHighlight();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationRequestId++;
    _ratingsRequestId++;
    LocationPreferenceService.selection.removeListener(_onLocationChanged);
    super.dispose();
  }

  Future<void> _loadRecentlyViewed() async {
    try {
      final places = await _recentlyViewedService.getRecentlyViewed();
      if (!mounted) {
        return;
      }
      setState(() {
        _recentlyViewedPlaces = places;
        _loadingRecentlyViewed = false;
      });
    } catch (error) {
      debugPrint('Erro ao carregar histórico: $error');
      if (mounted) {
        setState(() => _loadingRecentlyViewed = false);
      }
    }
  }

  Future<void> _loadFavoriteIds() async {
    try {
      final favorites = await _favoritesService.getFavorites();
      if (!mounted) {
        return;
      }
      setState(() {
        _favoritePlaceIds
          ..clear()
          ..addAll(favorites.map(_favoritesService.getPlaceId));
      });
    } catch (error) {
      debugPrint('Erro ao carregar favoritos: $error');
    }
  }

  Future<void> _clearRecentlyViewed() async {
    await _recentlyViewedService.clear();
    if (!mounted) {
      return;
    }
    setState(() => _recentlyViewedPlaces = []);
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      widget.onGoExplore?.call();
      return;
    }
    FocusScope.of(context).unfocus();
    widget.onSearch?.call(query);
  }

  Future<void> _loadWeeklyHighlight() async {
    try {
      final place = GunduaApiClient.isConfigured
          ? await WeeklyHighlightsService().communityMostVisited()
          : await WeeklyHighlightsService().mostViewedByMe();
      if (mounted) {
        setState(() => _weeklyPlace = place);
      }
    } catch (error) {
      debugPrint('Não foi possível carregar o destaque semanal: $error');
    }
  }

  void _onLocationChanged() {
    final location = LocationPreferenceService.selection.value;
    if (!mounted || location == null) {
      return;
    }
    if (_selectedLocation?.latitude == location.latitude &&
        _selectedLocation?.longitude == location.longitude &&
        _selectedLocation?.label == location.label) {
      return;
    }
    setState(() => _selectedLocation = location);
    _loadNearbyContent(location: location);
  }

  Future<void> _restoreSelectedLocation() async {
    final location = await LocationPreferenceService().getSelected();
    if (!mounted || location == null) {
      return;
    }
    if (_selectedLocation?.latitude == location.latitude &&
        _selectedLocation?.longitude == location.longitude) {
      return;
    }
    setState(() => _selectedLocation = location);
    await _loadNearbyContent(location: location);
  }

  Future<void> _chooseLocation() async {
    await LocationPicker.show(context);
    // LocationPicker persiste a selecção; o listener actualiza as páginas.
  }

  Future<void> _loadNearbyContent({AppLocation? location}) async {
    final requestId = ++_locationRequestId;
    final selected = location ?? _selectedLocation;
    if (selected == null) {
      return;
    }

    setState(() {
      _isLoadingNearby = true;
      _locationName = selected.label;
      _nearbyError = null;
    });

    try {
      final nearby = await _placeService.getNearbyPlaces(
        latitude: selected.latitude,
        longitude: selected.longitude,
        radiusMeters: 20000,
        limit: 100,
        categoryFilter: 'tourism,entertainment,leisure.park,beach,catering.restaurant',
      );

      final places = <Place>[];
      final seen = <String>{};
      for (final item in nearby) {
        final place = Place.fromMap(item);
        if (place.latitude == 0 && place.longitude == 0) {
          continue;
        }
        if (!seen.add(place.id)) {
          continue;
        }
        final distance = Geolocator.distanceBetween(
          selected.latitude, selected.longitude,
          place.latitude, place.longitude,
        );
        if (distance <= 20000) {
          places.add(place.copyWith(distanceMeters: distance));
        }
      }
      places.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));

      final gems = _hiddenGems.map((place) {
        final distance = Geolocator.distanceBetween(
          selected.latitude, selected.longitude,
          place.latitude, place.longitude,
        );
        return place.copyWith(distanceMeters: distance);
      }).toList();

      if (!mounted || requestId != _locationRequestId) {
        return;
      }
      setState(() {
        _topPlaces = places.take(100).toList();
        _hiddenGems = gems;
        _isLoadingNearby = false;
      });
    } catch (error) {
      if (!mounted || requestId != _locationRequestId) {
        return;
      }
      setState(() {
        _isLoadingNearby = false;
        _nearbyError = 'Não foi possível carregar lugares próximos. Tenta novamente.';
      });
    }
  }

  Future<void> _loadRatedPlaces() async {
    final requestId = ++_ratingsRequestId;
    setState(() {
      _loadingRatings = true;
      _ratedTopPlaces = [];
      _ratingsError = null;
    });
    try {
      final rated = await _placeService.getGoogleTop100Places(
        latitude: lisbonLatitude,
        longitude: lisbonLongitude,
      );
      final places = rated.map(Place.fromMap).toList();
      if (!mounted || requestId != _ratingsRequestId) {
        return;
      }
      setState(() {
        _ratedTopPlaces = places;
        _loadingRatings = false;
      });
    } catch (error) {
      if (!mounted || requestId != _ratingsRequestId) {
        return;
      }
      setState(() {
        _loadingRatings = false;
        _ratingsError = error is PlaceRatingsUnavailable
            ? error.message : 'Classificações indisponíveis de momento.';
      });
    }
  }

  Widget _weeklyBanner() {
    final data = _weeklyPlace;
    final place = data == null ? null : Place.fromMap(data);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      child: Material(
        color: GunduaTheme.ink,
        borderRadius: BorderRadius.circular(GunduaTheme.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: data == null ? null : () => _openPlace(data),
          child: SizedBox(
            height: place == null ? 170 : 252,
            child: Stack(fit: StackFit.expand, children: [
              if (place != null) _placeImage(place),
              DecoratedBox(decoration: BoxDecoration(
                color: GunduaTheme.ink.withValues(alpha: place == null ? 1 : .70),
              )),
              Padding(
                padding: const EdgeInsets.all(GunduaTheme.spaceXl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Destaque da semana', style: TextStyle(
                      color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w600)),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        place?.name ?? 'Ainda sem destaques',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white,
                          fontSize: 25, height: 1.14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: GunduaTheme.spaceSm),
                      Text(
                        place == null
                            ? 'Os lugares que visitas vão aparecer aqui.'
                            : GunduaApiClient.isConfigured
                                ? 'Mais marcado como visitado na GUNDUA esta semana'
                                : 'O teu local mais visto esta semana',
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white,
                          fontSize: 13, height: 1.4),
                      ),
                      if (place != null) ...[
                        const SizedBox(height: GunduaTheme.spaceMd),
                        const Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Ver local', style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                        ]),
                      ],
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(Place place) async {
    final id = _favoritesService.getPlaceId(place.toMap());
    try {
      final saved = await _favoritesService.toggleFavorite(place.toMap());
      if (!mounted) {
        return;
      }
      setState(() {
        if (saved) {
          _favoritePlaceIds.add(id);
        } else {
          _favoritePlaceIds.remove(id);
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível guardar o favorito.')),
      );
    }
  }

  Future<String?> _loadImage(Place place) => _imageFutures.putIfAbsent(
        place.id,
        () => _placeService.searchPlaceImage(
          [place.name, place.locality ?? place.address]
              .where((part) => part.trim().isNotEmpty)
              .join(', '),
        ),
      );

  Future<void> _openPlace(Map<String, dynamic> place) async {
    if (_openingPlace) {
      return;
    }
    _openingPlace = true;
    final navigator = Navigator.of(context);
    try {
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => PlaceDetailsScreen(
            place: Map<String, dynamic>.from(place),
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      await _loadRecentlyViewed();
      await _loadFavoriteIds();
      await _loadWeeklyHighlight();
    } catch (error, stackTrace) {
      debugPrint('Não foi possível abrir os detalhes: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir este local.')),
      );
    } finally {
      _openingPlace = false;
    }
  }

  String _formatDistance(double? meters) {
    if (meters == null) {
      return 'Distância por calcular';
    }
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _locality(Place place) {
    if (place.locality?.trim().isNotEmpty == true) {
      return place.locality!;
    }
    final parts = place.address.split(',').map((part) => part.trim()).toList();
    return parts.length > 1 ? parts[parts.length - 2] : place.address;
  }

  Widget _sectionTitle(String title, String subtitle, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: textColor, fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(subtitle, style: const TextStyle(color: secondaryColor, fontSize: 12)),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }

  Widget _placeImage(Place place) => PlacePhoto(
    url: place.imageUrl,
    imageFuture: _loadImage(place),
  );

  Widget _buildGemCard(Place place) {
    final id = _favoritesService.getPlaceId(place.toMap());
    final isFavorite = _favoritePlaceIds.contains(id);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPlace(place.toMap()),
        splashColor: accentColor.withValues(alpha: 0.10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _placeImage(place),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: isFavorite ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _toggleFavorite(place),
                        icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? accentColor : textColor, size: 19),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  if (place.distanceMeters != null) ...[
                    Row(children: [
                      const Icon(Icons.near_me_outlined, color: accentColor, size: 13),
                      const SizedBox(width: 4),
                      Text(_formatDistance(place.distanceMeters),
                        style: const TextStyle(color: textColor, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 3),
                  ],
                  Text(_locality(place), maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: secondaryColor, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCard(Place place, int index) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPlace(place.toMap()),
        splashColor: accentColor.withValues(alpha: 0.10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _placeImage(place),
                  Positioned(
                    left: 9,
                    top: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(color: textColor, borderRadius: BorderRadius.circular(18)),
                      child: Text('#${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(_locality(place), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: secondaryColor, fontSize: 10)),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (place.rating != null) ...[
                      const Icon(Icons.star_rounded, color: Color(0xFFE2A827), size: 13),
                      Text(' ${place.rating!.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      const Spacer(),
                    ],
                    if (place.distanceMeters != null)
                      Text(_formatDistance(place.distanceMeters),
                        style: const TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationMessage() {
    final message = _nearbyError ?? 'Escolhe uma cidade ou permita o GPS.';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFEDEEEF))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: secondaryColor, fontSize: 12, height: 1.4)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _isLoadingNearby ? null : _chooseLocation,
            icon: _isLoadingNearby
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor))
                : const Icon(Icons.my_location_outlined, size: 17),
            label: Text(_isLoadingNearby ? 'A localizar...' : 'Escolher localização'),
            style: TextButton.styleFrom(foregroundColor: accentColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 16),
                child: Row(
                  children: [
                    const Text('gundua', style: TextStyle(color: textColor, fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -1)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Mapa de descoberta',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NearbyMapScreen())),
                      icon: const Icon(Icons.map_outlined, color: textColor),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                child: Row(
                  children: List.generate(2, (index) {
                    final selected = _homeTab == index;
                    final label = index == 0 ? 'For You' : 'Friends';
                    return Padding(
                      padding: const EdgeInsets.only(right: 26),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _homeTab = index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Column(children: [
                            Text(label, style: TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w700,
                              color: selected ? textColor : secondaryColor,
                            )),
                            const SizedBox(height: 7),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              height: 3, width: selected ? 54 : 0,
                              decoration: BoxDecoration(
                                color: accentColor, borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            if (_homeTab == 0) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submitSearch(),
                  decoration: InputDecoration(
                    hintText: 'Lugar, restaurante ou experiência',
                    hintStyle: const TextStyle(color: secondaryColor, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: textColor),
                    suffixIcon: IconButton(
                      tooltip: 'Pesquisar',
                      onPressed: _submitSearch,
                      icon: const Icon(Icons.arrow_forward, color: textColor),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFFEDEEEF))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: textColor)),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _weeklyBanner()),
            if (!_loadingRecentlyViewed && _recentlyViewedPlaces.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _sectionTitle(
                  'Vistos recentemente',
                  '',
                  action: TextButton(onPressed: _clearRecentlyViewed, child: const Text('Limpar', style: TextStyle(color: accentColor))),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 164,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    scrollDirection: Axis.horizontal,
                    itemCount: _recentlyViewedPlaces.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final place = _recentlyViewedPlaces[index];
                      final name = (place['name'] ?? 'Destino').toString();
                      final recentPlace = Place.fromMap(place);
                      final location = (place['locality'] ?? place['location'] ?? '').toString();
                      return SizedBox(
                        width: 150,
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openPlace(place),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _placeImage(recentPlace),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 3),
                                      Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: secondaryColor, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: _sectionTitle('$_locationName',
                  '',
                  action: IconButton(
                    tooltip: 'Alterar localização',
                    onPressed: _chooseLocation,
                    icon: const Icon(Icons.my_location_outlined, color: accentColor),
                  )),
            ),
            if (_topPlaces.isEmpty)
              SliverToBoxAdapter(child: _buildLocationMessage())
            else
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 232,
                  child: CarouselView(
                    onTap: (index) => _openPlace(_topPlaces[index].toMap()),
                    itemExtent: 205,
                    shrinkExtent: 185,
                    children: _topPlaces.take(100).toList().asMap().entries
                        .map((entry) => _buildTopCard(entry.value, entry.key)).toList(),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: _sectionTitle(
                'Top 100 em Lisboa',
                '',
              ),
            ),
            if (_ratedTopPlaces.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_loadingRatings) const LinearProgressIndicator(minHeight: 2)
                    else ...[
                      Text(_ratingsError ?? 'Ainda não há classificações disponíveis.',
                        style: const TextStyle(color: secondaryColor, fontSize: 13)),
                      if (_topPlaces.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Explora mais perto de ti.',
                          style: TextStyle(color: secondaryColor, fontSize: 12)),
                      ],
                      TextButton(onPressed: _loadRatedPlaces, child: const Text('Tentar novamente')),
                    ],
                  ]),
                ),
              )
            else
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 232,
                  child: CarouselView(
                    onTap: (index) => _openPlace(_ratedTopPlaces[index].toMap()),
                    itemExtent: 205,
                    shrinkExtent: 185,
                    children: _ratedTopPlaces.asMap().entries
                        .map((entry) => _buildTopCard(entry.value, entry.key)).toList(),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: _sectionTitle('Gundua recomenda', ''),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 270,
                child: CarouselView(
                  onTap: (index) => _openPlace(_hiddenGems[index].toMap()),
                  itemExtent: 238,
                  shrinkExtent: 210,
                  children: _hiddenGems.map(_buildGemCard).toList(),
                ),
              ),
            ),
            ],
            if (_homeTab == 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 65, 32, 48),
                  child: Column(children: [
                    const Icon(Icons.people_outline, size: 58, color: secondaryColor),
                    const SizedBox(height: 20),
                    const Text('Descobre com os teus amigos',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    const Text(
                      'As experiências dos teus amigos vão aparecer aqui quando esta funcionalidade estiver disponível.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, height: 1.5, color: secondaryColor),
                    ),
                  ]),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 138)),
          ],
        ),
      ),
    );
  }
}
