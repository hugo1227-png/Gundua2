import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/gundua_theme.dart';

import '../models/place.dart';
import '../services/curated_places_service.dart';
import '../services/favorites_service.dart';
import '../services/location_service.dart';
import '../services/place_search_service.dart';
import '../services/place_service.dart';
import '../services/recently_viewed_service.dart';
import 'nearby_map_screen.dart';
import 'place_details_screen.dart';
import '../widgets/location_picker.dart';
import '../widgets/place_result_tile.dart';
import '../widgets/place_carousel_card.dart';
import '../widgets/place_skeleton.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    this.initialQuery,
    this.initialQueryToken = 0,
    this.refreshToken = 0,
  });

  final String? initialQuery;
  final int initialQueryToken;
  final int refreshToken;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const Color background = GunduaTheme.canvas;
  static const Color textColor = GunduaTheme.ink;
  static const Color secondaryColor = GunduaTheme.muted;
  static const Color accentColor = GunduaTheme.accent;

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final PlaceSearchService _searchService = PlaceSearchService();
  final SearchHistoryService _historyService = SearchHistoryService();
  final PlaceService _placeService = PlaceService();
  final FavoritesService _favoritesService = FavoritesService();
  final RecentlyViewedService _recentlyViewedService = RecentlyViewedService();

  static const List<String> _categories = [
    'Todos',
    'Restaurantes',
    'Monumentos',
    'Museus',
    'Natureza',
    'Cultura',
    'Praias',
    'Praças',
  ];

  String _selectedCategory = 'Todos';
  AppLocation? _selectedLocation;
  int _radiusMeters = 20000;
  String _currentLocation = 'a tua localização';
  List<Map<String, String>> _recentSearches = [];
  List<Place> _searchResults = [];
  List<Place> _bestRatedPlaces = [];
  List<Place> _newPlaces = [];
  List<Place> _topPlaces = [];
  List<Place> _hiddenGems = CuratedPlacesService.lisbonHiddenGems
      .map(Place.fromMap)
      .toList();
  final Set<String> _favoriteIds = {};
  final Set<String> _loadingFavoriteIds = {};
  final Map<String, Future<String?>> _imageFutures = {};

  bool _hasSearched = false;
  bool _openingPlace = false;
  bool _isSearching = false;
  bool _isLoadingCollections = false;
  bool _isLoadingRatings = false;
  String? _searchError;
  String? _collectionError;
  int _searchRequestId = 0;
  int _collectionRequestId = 0;
  final LocationPreferenceService _locationPreferences = LocationPreferenceService();

  @override
  void initState() {
    super.initState();
    LocationPreferenceService.selection.addListener(_onSharedLocationChanged);
    _loadHistory();
    _loadFavorites();
    _restoreSelection();
    if ((widget.initialQuery ?? '').trim().isNotEmpty) {
      _placeController.text = widget.initialQuery!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSearch();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadFavorites();
      if (_selectedLocation != null) {
        _loadNearbyCollections(location: _selectedLocation);
      }
    }
    if (oldWidget.initialQueryToken != widget.initialQueryToken &&
        (widget.initialQuery ?? '').trim().isNotEmpty) {
      _placeController.text = widget.initialQuery!.trim();
      _selectedCategory = 'Todos';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSearch();
      });
    }
  }

  @override
  void dispose() {
    _searchRequestId++;
    _collectionRequestId++;
    LocationPreferenceService.selection.removeListener(_onSharedLocationChanged);
    _locationController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  void _onSharedLocationChanged() {
    final selected = LocationPreferenceService.selection.value;
    if (!mounted || selected == null) return;
    if (_selectedLocation?.latitude == selected.latitude &&
        _selectedLocation?.longitude == selected.longitude &&
        _selectedLocation?.label == selected.label) {
      return;
    }
    setState(() {
      _selectedLocation = selected;
      _currentLocation = selected.label;
      _locationController.text = selected.label;
    });
    _loadNearbyCollections(location: selected);
    if (_hasSearched) _runSearch();
  }

  Future<void> _restoreSelection() async {
    final saved = await _locationPreferences.getSelected();
    if (!mounted || saved == null) return;
    if (_selectedLocation?.latitude == saved.latitude &&
        _selectedLocation?.longitude == saved.longitude) {
      return;
    }
    setState(() {
      _selectedLocation = saved;
      _currentLocation = saved.label;
      _locationController.text = saved.label;
    });
    await _loadNearbyCollections(location: saved);
  }

  Future<void> _chooseLocation() async {
    final location = await LocationPicker.show(context);
    if (!mounted || location == null) return;
    // O LocationPicker guarda e notifica Home/Explore automaticamente.
    // Evita um segundo pedido Geoapify para a mesma localização.
  }

  Future<AppLocation?> _resolveLocationText(String locationText) async {
    if (locationText.isEmpty ||
        locationText.toLowerCase() == _selectedLocation?.label.toLowerCase()) {
      return _selectedLocation;
    }
    final matches = await _placeService.searchPlaces(locationText);
    if (matches.isEmpty) {
      throw StateError('Não foi possível encontrar essa cidade ou bairro.');
    }
    final match = matches.first;
    final lat = match['latitude'];
    final lon = match['longitude'];
    if (lat is! num || lon is! num) {
      throw StateError('Localização não encontrada no mapa.');
    }
    final location = AppLocation(
      label: (match['name'] ?? locationText).toString(),
      latitude: lat.toDouble(), longitude: lon.toDouble(),
      isDeviceLocation: false,
    );
    await _locationPreferences.save(location);
    return location;
  }

  Future<void> _loadHistory() async {
    final history = await _historyService.getRecentSearches();
    if (mounted) setState(() => _recentSearches = history);
  }

  Future<void> _loadFavorites() async {
    try {
      final saved = await _favoritesService.getFavorites();
      if (!mounted) return;
      setState(() {
        _favoriteIds
          ..clear()
          ..addAll(saved.map(_favoritesService.getPlaceId));
      });
    } catch (error) {
      debugPrint('Erro ao carregar favoritos: $error');
    }
  }

  Future<void> _runSearch({String? placeQuery, String? locationQuery}) async {
    final requestId = ++_searchRequestId;
    final placeText = (placeQuery ?? _placeController.text).trim();
    final locationText = (locationQuery ?? _locationController.text).trim();
    final finalPlaceQuery = placeText;

    if (finalPlaceQuery.isEmpty && locationText.isEmpty && _selectedCategory == 'Todos') {
      setState(() {
        _hasSearched = false;
        _searchResults = [];
        _searchError = null;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _hasSearched = true;
      _isSearching = true;
      _searchResults = [];
      _searchError = null;
    });

    try {
      await _historyService.add(
        placeQuery: finalPlaceQuery,
        locationQuery: locationText,
      );
      final resolved = await _resolveLocationText(locationText);
      if (!mounted || requestId != _searchRequestId) return;
      final results = await _searchService.search(
        placeQuery: finalPlaceQuery,
        locationQuery: resolved == null ? locationText : '',
        category: _selectedCategory,
        nearbyLocation: resolved,
        radiusMeters: _radiusMeters,
      );
      if (!mounted || requestId != _searchRequestId) return;

      setState(() {
        _searchResults = results.map(Place.fromMap).toList();
        _isSearching = false;
        if (results.isEmpty) {
          _searchError = 'Sem resultados. Experimenta pesquisar outro nome ou local.';
        }
      });
      _loadHistory();
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isSearching = false;
        _searchError = 'Não foi possível concluir a pesquisa. Tenta novamente.';
      });
    }
  }

  void _selectRecentSearch(Map<String, String> search) {
    _placeController.text = search['placeQuery'] ?? '';
    _locationController.text = search['locationQuery'] ?? '';
    _selectedCategory = 'Todos';
    _runSearch();
  }

  Future<void> _clearHistory() async {
    await _historyService.clear();
    if (mounted) setState(() => _recentSearches = []);
  }

  Future<void> _loadNearbyCollections({AppLocation? location}) async {
    final requestId = ++_collectionRequestId;
    final selected = location ?? _selectedLocation;
    if (selected == null) {
      await _chooseLocation();
      return;
    }
    setState(() {
      _isLoadingCollections = true;
      _isLoadingRatings = true;
      _bestRatedPlaces = [];
      _collectionError = null;
    });

    try {
      final nearby = await _placeService.getNearbyPlaces(
        latitude: selected.latitude,
        longitude: selected.longitude,
        radiusMeters: 20000,
        limit: 100,
        categoryFilter: 'tourism,entertainment,leisure.park,beach,catering.restaurant',
      );

      final recent = await _recentlyViewedService.getRecentlyViewed();
      final recentlyViewedIds = recent.map(_favoritesService.getPlaceId).toSet();
      final places = <Place>[];
      final seen = <String>{};

      for (final item in nearby) {
        final place = Place.fromMap(item);
        if (place.latitude == 0 && place.longitude == 0) continue;
        if (!seen.add(place.id)) continue;
        final distance = Geolocator.distanceBetween(
          selected.latitude,
          selected.longitude,
          place.latitude,
          place.longitude,
        );
        if (distance > 20000) continue;
        places.add(place.copyWith(distanceMeters: distance));
      }
      places.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));

      if (!mounted || requestId != _collectionRequestId) return;
      setState(() {
        _currentLocation = selected.label;
        // Top 20 = lugares próximos ordenados por distância.
        // Novos = lugares ainda não vistos que NÃO estão no Top 20.
        _topPlaces = places.take(20).toList();
        final topIds = _topPlaces.map((p) => p.id).toSet();
        _newPlaces = places.where((place) =>
            !topIds.contains(place.id) &&
            !recentlyViewedIds.contains(_favoritesService.getPlaceId(place.toMap())))
            .take(20).toList();
        _hiddenGems = CuratedPlacesService.lisbonHiddenGems.map((item) {
          final place = Place.fromMap(item);
          final distance = Geolocator.distanceBetween(
            selected.latitude,
            selected.longitude,
            place.latitude,
            place.longitude,
          );
          return place.copyWith(distanceMeters: distance);
        }).toList();
        _isLoadingCollections = false;
      });
      // Geoapify results stay usable while ratings load (or fail).
      unawaited(_loadRatings(selected, requestId));
    } catch (error) {
      if (!mounted || requestId != _collectionRequestId) return;
      setState(() {
        _isLoadingCollections = false;
        _isLoadingRatings = false;
        _collectionError = 'Não foi possível carregar os lugares. Tenta novamente.';
      });
    }
  }

  Future<void> _loadRatings(AppLocation selected, int requestId) async {
    try {
      final rated = await _placeService.getGoogleTopRatedPlaces(
        latitude: selected.latitude,
        longitude: selected.longitude,
        radiusMeters: 20000,
        limit: 20,
      );
      if (!mounted || requestId != _collectionRequestId) return;
      setState(() {
        _bestRatedPlaces = rated.map((item) {
          final place = Place.fromMap(item);
          final distance = Geolocator.distanceBetween(
            selected.latitude, selected.longitude,
            place.latitude, place.longitude,
          );
          return place.copyWith(distanceMeters: distance);
        }).toList();
        _isLoadingRatings = false;
      });
    } catch (error) {
      if (!mounted || requestId != _collectionRequestId) return;
      setState(() {
        _isLoadingRatings = false;
        _collectionError = error is PlaceRatingsUnavailable
            ? error.message : 'Classificações indisponíveis de momento.';
      });
    }
  }

  Future<String?> _loadImage(Place place) => _imageFutures.putIfAbsent(
        place.id,
        () => _placeService.searchPlaceImage(place.name),
      );

  Future<void> _toggleFavorite(Place place) async {
    final id = _favoritesService.getPlaceId(place.toMap());
    if (_loadingFavoriteIds.contains(id)) return;
    setState(() => _loadingFavoriteIds.add(id));
    try {
      final isFavorite = await _favoritesService.toggleFavorite(place.toMap());
      if (!mounted) return;
      setState(() {
        if (isFavorite) {
          _favoriteIds.add(id);
        } else {
          _favoriteIds.remove(id);
        }
        _loadingFavoriteIds.remove(id);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingFavoriteIds.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível atualizar o favorito.')),
      );
    }
  }

  Future<void> _openPlace(Place place) async {
    if (_openingPlace) return;
    _openingPlace = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: place.toMap())),
      );
      if (mounted) await _loadFavorites();
    } catch (error, stackTrace) {
      debugPrint('GUNDUA detalhes: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir este local.')),
        );
      }
    } finally {
      _openingPlace = false;
    }
  }

  Widget _placeListTile(Place place) {
    final id = _favoritesService.getPlaceId(place.toMap());
    return PlaceResultTile(
      place: place,
      imageFuture: _loadImage(place),
      isFavorite: _favoriteIds.contains(id),
      favoriteBusy: _loadingFavoriteIds.contains(id),
      onFavorite: () => _toggleFavorite(place),
      onTap: () => _openPlace(place),
    );
  }

  Widget _section(String title, String subtitle, List<Place> places,
      {String? emptyMessage}) {
    final filtered = places.where((place) => PlaceSearchService.matchesCategory(
        place.toMap(), _selectedCategory)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 27, 22, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: textColor,
              fontSize: 20, fontWeight: FontWeight.w700)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: secondaryColor, fontSize: 12)),
          ],
        ]),
      ),
      if (filtered.isEmpty && _isLoadingCollections)
        SizedBox(
          height: 265,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, _) => const PlaceSkeleton(compact: true),
          ),
        )
      else if (filtered.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text(emptyMessage ?? 'Ainda sem lugares nesta categoria.',
            style: const TextStyle(color: secondaryColor, fontSize: 12)),
        )
      else
        SizedBox(
          height: 265,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final place = filtered[index];
              final id = _favoritesService.getPlaceId(place.toMap());
              return SizedBox(
                width: 216,
                child: PlaceCarouselCard(
                  place: place,
                  onTap: () => _openPlace(place),
                  onFavorite: () => _toggleFavorite(place),
                  isFavorite: _favoriteIds.contains(id),
                  favoriteBusy: _loadingFavoriteIds.contains(id),
                  imageFuture: _loadImage(place),
                ),
              );
            },
          ),
        ),
    ]);
  }

  Widget _searchResultList() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(22, 15, 22, 25),
        child: Column(children: [
          PlaceSkeleton(),
          SizedBox(height: 12),
          PlaceSkeleton(),
          SizedBox(height: 12),
          PlaceSkeleton(),
        ]),
      );
    }
    if (_searchError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_searchError!, style: const TextStyle(color: secondaryColor, fontSize: 13)),
      );
    }
    if (_searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        child: Text('Não encontrámos lugares. Tenta outro nome.',
            style: TextStyle(color: secondaryColor)),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 15, 22, 25),
      itemCount: _searchResults.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _placeListTile(_searchResults[index]),
    );
  }

  String _recentLabel(Map<String, String> item) {
    final place = item['placeQuery'] ?? '';
    final location = item['locationQuery'] ?? '';
    if (place.isEmpty) return location;
    if (location.isEmpty) return place;
    return '$place · $location';
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
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Explorar lugares', style: TextStyle(
                            color: textColor, fontSize: 32, height: 1.14,
                            fontWeight: FontWeight.w700, letterSpacing: -.8)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Abrir mapa',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NearbyMapScreen())),
                      icon: const Icon(Icons.map_outlined, color: textColor),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    TextField(
                      controller: _locationController,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _runSearch(),
                      decoration: _searchDecoration('País, cidade ou bairro', Icons.location_on_outlined),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _placeController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _runSearch(),
                      decoration: _searchDecoration('Monumento, museu, natureza...', Icons.search).copyWith(
                        suffixIcon: IconButton(
                          tooltip: 'Pesquisar',
                          onPressed: _isSearching ? null : _runSearch,
                          icon: const Icon(Icons.arrow_forward, color: textColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoadingCollections ? null : _chooseLocation,
                        icon: _isLoadingCollections
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location_outlined, size: 17),
                        label: Text(_isLoadingCollections ? 'A procurar...' : _selectedLocation == null ? 'Escolher localização' : 'Localização: ${_selectedLocation!.label}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: const BorderSide(color: Color(0xFFE4E4E4)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 7),
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final selected = category == _selectedCategory;
                          return ChoiceChip(
                            label: Text(category),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _selectedCategory = category);
                              if (category == 'Todos' &&
                                  _placeController.text.trim().isEmpty) {
                                setState(() {
                                  _hasSearched = false;
                                  _searchResults = [];
                                });
                              } else if (_selectedLocation == null &&
                                  _locationController.text.trim().isEmpty) {
                                _chooseLocation();
                              } else {
                                _runSearch();
                              }
                            },
                            labelStyle: TextStyle(
                              color: selected ? accentColor : textColor,
                              fontWeight: FontWeight.w600),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Raio: ', style: TextStyle(fontSize: 12, color: secondaryColor)),
                        for (final km in [5, 10, 20])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('$km km'),
                              selected: _radiusMeters == km * 1000,
                              onSelected: (_) {
                                setState(() => _radiusMeters = km * 1000);
                                if (_hasSearched) _runSearch();
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_recentSearches.isNotEmpty && !_hasSearched)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 25, 22, 8),
                      child: Row(
                        children: [
                          const Expanded(child: Text('Pesquisas recentes', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700))),
                          TextButton(onPressed: _clearHistory, child: const Text('Limpar', style: TextStyle(color: accentColor))),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        scrollDirection: Axis.horizontal,
                        itemCount: _recentSearches.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => ActionChip(
                          avatar: const Icon(Icons.history, size: 15),
                          label: Text(_recentLabel(_recentSearches[index]), maxLines: 1, overflow: TextOverflow.ellipsis),
                          onPressed: () => _selectRecentSearch(_recentSearches[index]),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFEDEEEF)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_hasSearched)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 25, 22, 0),
                      child: Text('Resultados da pesquisa', style: const TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                    _searchResultList(),
                  ],
                ),
              )
            else ...[
              if (_collectionError != null && _bestRatedPlaces.isEmpty && !_isLoadingRatings)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                    child: Row(children: [
                      Expanded(child: Text(_collectionError!,
                        style: const TextStyle(color: secondaryColor, fontSize: 13))),
                      if (_selectedLocation != null)
                        TextButton(onPressed: () {
                          setState(() { _collectionError = null; _isLoadingRatings = true; });
                          unawaited(_loadRatings(_selectedLocation!, _collectionRequestId));
                        }, child: const Text('Tentar novamente')),
                    ]),
                  ),
                ),
              SliverToBoxAdapter(
                child: _section(
                  'Melhor classificados',
                  '', 
                  _bestRatedPlaces,
                  emptyMessage: _isLoadingRatings
                      ? 'A carregar classificações...'
                      : 'Classificações indisponíveis de momento.' 
                ),
              ),
              SliverToBoxAdapter(
                child: _section(
                  'Novos lugares para ti',
                  '', 
                  _newPlaces,
                ),
              ),
              SliverToBoxAdapter(
                child: _section(
                  'Top 20 $_currentLocation',
                  '', 
                  _topPlaces,
                ),
              ),
              SliverToBoxAdapter(
                child: _section(
                  'Hidden Gems',
                  '', 
                  _hiddenGems,
                ),
              ),
              if (_collectionError != null && _topPlaces.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
                    child: Text(_collectionError!, style: const TextStyle(color: secondaryColor, fontSize: 13)),
                  ),
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 138)),
          ],
        ),
      ),
    );
  }

  InputDecoration _searchDecoration(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: secondaryColor, fontSize: 12),
        prefixIcon: Icon(icon, color: textColor, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFEDEEEF))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: textColor)),
      );
}
