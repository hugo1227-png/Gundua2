import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/experiences_service.dart';
import '../services/favorites_service.dart';
import '../services/tourism_service.dart';
import '../services/visited_places_service.dart';
import '../services/recently_viewed_service.dart';
import '../services/weekly_highlights_service.dart';
import '../services/local_reviews_service.dart';
import 'experiences_screen.dart';
import '../theme/gundua_theme.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> place;

  const PlaceDetailsScreen({super.key, required this.place});

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  static const Color background = GunduaTheme.canvas;
  static const Color textColor = GunduaTheme.ink;
  static const Color secondaryColor = GunduaTheme.muted;
  static const Color accentColor = GunduaTheme.accent;
  static const Color borderColor = GunduaTheme.line;

  final FavoritesService _favoritesService = FavoritesService();
  final VisitedPlacesService _visitedPlacesService = VisitedPlacesService();
  final ExperiencesService _experiencesService = ExperiencesService();
  final TourismService _tourismService = TourismService();
  final RecentlyViewedService _recentlyViewedService = RecentlyViewedService();
  final LocalReviewsService _localReviews = LocalReviewsService();
  Map<String, dynamic>? _myReview;

  late Future<Map<String, dynamic>?> _informationFuture;
  late Future<List<Map<String, dynamic>>> _imagesFuture;
  late Future<List<Map<String, dynamic>>> _experiencesFuture;

  bool _isFavorite = false;
  bool _isVisited = false;
  bool _isLoadingVisited = true;
  bool _isSavingVisit = false;
  bool _isLoadingFavorite = true;
  bool _isSavingFavorite = false;

  String get _placeName {
    final name = widget.place['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;

    final displayName = widget.place['display_name']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(',').first.trim();
    }
    return 'Destino';
  }

  String get _tourismSearchName {
    final country = widget.place['country']?.toString().trim() ?? '';
    if (country.isEmpty || country.toLowerCase() == _placeName.toLowerCase()) {
      return _placeName;
    }
    return '$_placeName, $country';
  }

  @override
  void initState() {
    super.initState();
    _loadPlaceContent();
    _saveRecentlyViewed();
    _loadFavoriteStatus();
    _loadVisitedStatus();
    _loadMyReview();
  }

  Future<void> _saveRecentlyViewed() async {
    try {
      await _recentlyViewedService.addPlace(widget.place);
      await WeeklyHighlightsService().recordView(widget.place);
    } catch (error) {
      debugPrint('Erro ao guardar histórico de lugares: $error');
    }
  }

  void _loadPlaceContent() {
    _informationFuture = _tourismService.getPlaceInformation(
      _tourismSearchName,
    );
    _imagesFuture = _tourismService.searchPlaceImages(_tourismSearchName);
    _experiencesFuture = _experiencesService.getExperiencesForPlace(
      widget.place,
    );
  }

  void _reloadPlaceContent() {
    setState(_loadPlaceContent);
  }

  Future<void> _loadFavoriteStatus() async {
    try {
      final favorite = await _favoritesService.isFavorite(widget.place);
      if (!mounted) return;

      setState(() {
        _isFavorite = favorite;
        _isLoadingFavorite = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingFavorite = false);
    }
  }

  Future<void> _loadVisitedStatus() async {
    try {
      final visited = await _visitedPlacesService.isVisited(widget.place);
      if (!mounted) return;

      setState(() {
        _isVisited = visited;
        _isLoadingVisited = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingVisited = false);
    }
  }

  Future<void> _toggleVisited() async {
    if (_isSavingVisit || _isLoadingVisited) return;

    setState(() => _isSavingVisit = true);

    try {
      final result = await _visitedPlacesService.toggleVisited(widget.place);
      if (!mounted) return;

      setState(() {
        _isVisited = result;
        _isSavingVisit = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? 'Lugar marcado como visitado.'
                : 'Lugar removido dos visitados.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _isSavingVisit = false);
      debugPrint('Erro ao actualizar visita: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível actualizar a visita.')),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isSavingFavorite || _isLoadingFavorite) return;

    setState(() => _isSavingFavorite = true);

    try {
      final result = await _favoritesService.toggleFavorite(widget.place);
      if (!mounted) return;

      setState(() {
        _isFavorite = result;
        _isSavingFavorite = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result ? 'Adicionado aos favoritos.' : 'Removido dos favoritos.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _isSavingFavorite = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível actualizar os favoritos.'),
        ),
      );
    }
  }

  Future<void> _createExperience() async {
    final published = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateExperienceScreen(initialPlace: widget.place),
      ),
    );

    if (!mounted || published != true) return;

    setState(() {
      _experiencesFuture = _experiencesService.getExperiencesForPlace(
        widget.place,
      );
    });
  }

  Future<void> _openDirections() async {
    final latitude = widget.place['latitude'] ?? widget.place['lat'];
    final longitude = widget.place['longitude'] ?? widget.place['lon'];
    if (latitude is! num || longitude is! num) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este lugar não tem coordenadas disponíveis.'),
        ),
      );
      return;
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${latitude.toDouble()},${longitude.toDouble()}',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callPlace() async {
    final phone = widget.place['phone']?.toString().trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não existe contacto telefónico disponível.'),
        ),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  Future<void> _bookPlace() async {
    final bookingUrl = (widget.place['booking_url'] ??
            widget.place['bookingUrl'] ??
            widget.place['website'] ??
            widget.place['url'])
        ?.toString()
        .trim();
    final uri = bookingUrl != null && bookingUrl.isNotEmpty
        ? Uri.tryParse(bookingUrl)
        : Uri.https('www.google.com', '/search', {
            'q': 'reservar $_placeName',
          });

    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não existe uma ligação de reserva disponível.')),
      );
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir a página de reserva.')),
        );
      }
    } catch (error) {
      debugPrint('Erro ao abrir reserva: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir a página de reserva.')),
      );
    }
  }

  Widget _buildOpeningHours() {
    final value = widget.place['opening_hours'] ??
        widget.place['openingHours'] ??
        widget.place['hours'];
    final lines = <String>[];

    if (value is String && value.trim().isNotEmpty) {
      lines.add(value.trim());
    } else if (value is List) {
      lines.addAll(value.map((item) => item.toString()));
    } else if (value is Map) {
      for (final entry in value.entries) {
        lines.add('${entry.key}: ${entry.value}');
      }
    }

    return _infoPanel(
      icon: Icons.schedule_outlined,
      title: 'Horário de funcionamento',
      child: lines.isEmpty
          ? const Text(
              'Horário não disponível. Confirma os horários junto do local antes da visita.',
              style: TextStyle(color: secondaryColor, fontSize: 13, height: 1.5),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines
                  .map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(line, style: const TextStyle(color: textColor, fontSize: 13, height: 1.4)),
                      ))
                  .toList(),
            ),
    );
  }

  Future<void> _loadMyReview() async {
    final id = (widget.place['placeId'] ?? widget.place['place_id'] ??
        '${widget.place['name']}_${widget.place['latitude']}_${widget.place['longitude']}').toString();
    final review = await _localReviews.forPlace(id);
    if (mounted) setState(() => _myReview = review);
  }

  Future<void> _writeReview() async {
    int rating = (_myReview?['rating'] as num?)?.toInt() ?? 5;
    final comment = TextEditingController(text: (_myReview?['comment'] ?? '').toString());
    final save = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Avaliar este lugar'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(children: [for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i estrelas',
                onPressed: () => update(() => rating = i),
                icon: Icon(i <= rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFE2A827)),
              ),
            ]),
            TextField(controller: comment, maxLines: 4,
                maxLength: 600,
                decoration: const InputDecoration(
                    labelText: 'A tua experiência', border: OutlineInputBorder())),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (save == true) {
      try {
        await _localReviews.save(place: widget.place,
            rating: rating, comment: comment.text);
        await _loadMyReview();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível guardar a avaliação.')),
          );
        }
      }
    }
    // Evita descartar o controlador enquanto a rota termina a animação.
    Future<void>.delayed(const Duration(milliseconds: 350), comment.dispose);
  }

  Widget _buildReviews() {
    final rating = widget.place['rating'];
    final reviewCount = widget.place['reviewCount'] ??
        widget.place['userRatingCount'] ??
        widget.place['user_ratings_total'];
    final reviews = widget.place['reviews'];

    return _infoPanel(
      icon: Icons.reviews_outlined,
      title: 'Avaliações',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_myReview != null) ...[
            Text('A tua avaliação · ★ ${_myReview!['rating']}/5',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text((_myReview!['comment'] ?? '').toString()),
            const SizedBox(height: 14),
          ],
          OutlinedButton.icon(
            onPressed: _writeReview,
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(_myReview == null ? 'Avaliar este lugar' : 'Editar a tua avaliação'),
          ),
          const SizedBox(height: 12),
          if (rating is num)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFFB400), size: 19),
                  const SizedBox(width: 5),
                  Text(rating.toStringAsFixed(1), style: const TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Text(reviewCount == null ? 'Classificação disponível' : '$reviewCount avaliações', style: const TextStyle(color: secondaryColor, fontSize: 12)),
                ],
              ),
            ),
          if (reviews is List && reviews.isNotEmpty)
            ...reviews.take(3).whereType<Map>().map((review) {
              final author = (review['author_name'] ?? review['author'] ?? 'Visitante').toString();
              final content = (review['text'] ?? review['comment'] ?? '').toString();
              final reviewRating = review['rating'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(author, style: const TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w700))),
                        if (reviewRating is num) Text('★ ${reviewRating.toStringAsFixed(1)}', style: const TextStyle(color: secondaryColor, fontSize: 11)),
                      ],
                    ),
                    if (content.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(content, style: const TextStyle(color: secondaryColor, fontSize: 12, height: 1.45)),
                    ],
                  ],
                ),
              );
            })
          else if (rating is! num)
            const Text(
              'Ainda não existem avaliações disponíveis para este lugar.',
              style: TextStyle(color: secondaryColor, fontSize: 13, height: 1.5),
            )
          else
            const Text(
              'A classificação está disponível; os comentários ainda não foram fornecidos pela fonte de dados.',
              style: TextStyle(color: secondaryColor, fontSize: 12, height: 1.45),
            ),
        ],
      ),
    );
  }

  Widget _infoPanel({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 19),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Future<void> _sharePlace() async {
    final latitude = widget.place['latitude'] ?? widget.place['lat'];
    final longitude = widget.place['longitude'] ?? widget.place['lon'];
    final mapLink = latitude is num && longitude is num
        ? 'https://www.openstreetmap.org/?mlat=${latitude.toDouble()}&mlon=${longitude.toDouble()}'
        : '';
    final text = [
      _placeName,
      widget.place['location']?.toString() ?? '',
      mapLink,
    ].where((part) => part.isNotEmpty).join('\n');

    final renderBox = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        title: _placeName,
        sharePositionOrigin: renderBox == null
            ? null
            : renderBox.localToGlobal(Offset.zero) & renderBox.size,
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(child: _quickAction(icon: Icons.directions_outlined, label: 'Direcções', onTap: _openDirections)),
        const SizedBox(width: 6),
        Expanded(child: _quickAction(icon: Icons.call_outlined, label: 'Ligar', onTap: _callPlace)),
        const SizedBox(width: 6),
        Expanded(child: _quickAction(icon: Icons.share_outlined, label: 'Partilhar', onTap: _sharePlace)),
        const SizedBox(width: 6),
        Expanded(child: _quickAction(icon: Icons.event_available_outlined, label: 'Reservar', onTap: _bookPlace)),
      ],
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor,
        side: const BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 19),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Future<void> _openExternalLink(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir a ligação.')),
        );
      }
    } catch (error) {
      debugPrint('Erro ao abrir ligação externa: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir a ligação.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.place['location']?.toString() ?? '';
    final country = widget.place['country']?.toString() ?? '';
    final image = (widget.place['image'] ?? widget.place['image_url'])
        ?.toString();
    final latitude = widget.place['latitude'] ?? widget.place['lat'];
    final longitude = widget.place['longitude'] ?? widget.place['lon'];

    return Scaffold(
      backgroundColor: background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: background,
            foregroundColor: textColor,
            elevation: 0,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.95),
                  child: IconButton(
                    tooltip: 'Copiar informação do lugar',
                    onPressed: _sharePlace,
                    icon: const Icon(Icons.share_outlined, color: textColor),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.95),
                  child: IconButton(
                    tooltip: _isFavorite
                        ? 'Remover dos favoritos'
                        : 'Adicionar aos favoritos',
                    onPressed: _isLoadingFavorite || _isSavingFavorite
                        ? null
                        : _toggleFavorite,
                    icon: _isSavingFavorite
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accentColor,
                            ),
                          )
                        : Icon(
                            _isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: accentColor,
                          ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeaderImage(image),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (country.isNotEmpty)
                    Text(
                      country,
                      style: const TextStyle(
                        color: secondaryColor,
                        fontSize: 11,
                        
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if ((widget.place['categoryLabel'] ??
                          widget.place['category']) !=
                      null) ...[
                    const SizedBox(height: 8),
                    Text(
                      (widget.place['categoryLabel'] ??
                              widget.place['category']).toString(),
                      style: const TextStyle(
                        color: accentColor, fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    _placeName,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: secondaryColor,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            location,
                            style: const TextStyle(
                              color: secondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  _buildQuickActions(),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoadingVisited || _isSavingVisit
                          ? null
                          : _toggleVisited,
                      icon: _isSavingVisit
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isVisited
                                  ? Icons.check_circle
                                  : Icons.place_outlined,
                            ),
                      label: Text(
                        _isSavingVisit
                            ? 'A guardar visita...'
                            : _isVisited
                            ? 'Já visitado — desmarcar'
                            : 'Marcar como visitado',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _sectionTitle('Sobre o local'),
                  const SizedBox(height: 12),
                  _buildInformation(),
                  const SizedBox(height: 18),
                  _buildOpeningHours(),
                  const SizedBox(height: 18),
                  _buildReviews(),
                  const SizedBox(height: 28),
                  _sectionTitle('Fotografias'),
                  const SizedBox(height: 12),
                  _buildPhotoGallery(),
                  const SizedBox(height: 28),
                  _sectionTitle('Experiências da comunidade'),
                  const SizedBox(height: 12),
                  _buildCommunityExperiences(),
                  const SizedBox(height: 28),
                  _sectionTitle('Localização'),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _coordinateRow(
                          'Latitude',
                          latitude?.toString() ?? 'Não disponível',
                        ),
                        const Divider(height: 24),
                        _coordinateRow(
                          'Longitude',
                          longitude?.toString() ?? 'Não disponível',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Explorar mais lugares',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: textColor,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildHeaderImage(String? image) {
    if (_isHttpUrl(image)) {
      return Image.network(
        image!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildWikimediaHeaderImage(),
      );
    }
    return _buildWikimediaHeaderImage();
  }

  Widget _buildWikimediaHeaderImage() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _imagesFuture,
      builder: (context, snapshot) {
        final images = snapshot.data ?? [];
        if (images.isNotEmpty) {
          final imageUrl = images.first['imageUrl']?.toString();
          if (_isHttpUrl(imageUrl)) {
            return Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _imagePlaceholder(),
            );
          }
        }
        return _imagePlaceholder();
      },
    );
  }

  Widget _buildInformation() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _informationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingCard('A carregar informação turística...');
        }

        if (snapshot.hasError) {
          return _messageCard(
            'Não foi possível carregar a descrição da Wikipédia.',
            icon: Icons.cloud_off_outlined,
            actionLabel: 'Tentar novamente',
            onAction: _reloadPlaceContent,
          );
        }

        final information = snapshot.data;
        if (information == null) {
          return _messageCard(
            'Não encontrámos uma descrição da Wikipédia para este destino.',
            icon: Icons.info_outline,
          );
        }

        final description = information['extract']?.toString().trim() ?? '';
        final title = information['title']?.toString() ?? _placeName;
        final contentUrls = information['content_urls'];
        final desktop = contentUrls is Map<String, dynamic>
            ? contentUrls['desktop']
            : null;
        final sourceUrl = desktop is Map<String, dynamic>
            ? desktop['page']?.toString() ?? ''
            : '';

        if (description.isEmpty) {
          return _messageCard(
            'A Wikipédia não disponibilizou uma descrição para este destino.',
            icon: Icons.info_outline,
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Fonte: Wikipédia — $title',
                style: const TextStyle(color: secondaryColor, fontSize: 12),
              ),
              if (_isHttpUrl(sourceUrl))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openExternalLink(sourceUrl),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Ler mais na Wikipédia'),
                    style: TextButton.styleFrom(
                      foregroundColor: accentColor,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoGallery() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _imagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingCard('A carregar fotografias...');
        }

        if (snapshot.hasError) {
          return _messageCard(
            'Não foi possível carregar fotografias do Wikimedia Commons.',
            icon: Icons.cloud_off_outlined,
            actionLabel: 'Tentar novamente',
            onAction: _reloadPlaceContent,
          );
        }

        final images = snapshot.data ?? [];
        if (images.isEmpty) {
          return _messageCard(
            'Não encontrámos fotografias disponíveis para este destino.',
            icon: Icons.photo_outlined,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 282,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final image = images[index];
                  final imageUrl = image['imageUrl']?.toString() ?? '';
                  final artist = image['artist']?.toString().trim() ?? '';
                  final license = image['license']?.toString().trim() ?? '';
                  final sourceUrl = image['descriptionUrl']?.toString() ?? '';
                  final licenseUrl = image['licenseUrl']?.toString() ?? '';

                  return Container(
                    width: 255,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _isHttpUrl(imageUrl)
                              ? Image.network(
                                  imageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: const Color(0xFFEDEEEF),
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: secondaryColor,
                                        size: 34,
                                      ),
                                    ),
                                  ),
                                )
                              : _imagePlaceholder(),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(13, 10, 13, 9),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                artist.isEmpty
                                    ? 'Autor não indicado'
                                    : 'Autor: $artist',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: secondaryColor,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                license.isEmpty
                                    ? 'Licença: consultar fonte'
                                    : 'Licença: $license',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: secondaryColor,
                                  fontSize: 11,
                                ),
                              ),
                              if (_isHttpUrl(sourceUrl) ||
                                  _isHttpUrl(licenseUrl))
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    if (_isHttpUrl(sourceUrl))
                                      _smallLink(
                                        'Fonte e créditos',
                                        () => _openExternalLink(sourceUrl),
                                      ),
                                    if (_isHttpUrl(licenseUrl))
                                      _smallLink(
                                        'Licença',
                                        () => _openExternalLink(licenseUrl),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Fotografias obtidas através do Wikimedia Commons. Consulta a fonte para veres os créditos e as condições de utilização de cada imagem.',
              style: TextStyle(
                color: secondaryColor,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _smallLink(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: accentColor,
        padding: const EdgeInsets.only(top: 3),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _buildCommunityExperiences() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _experiencesFuture,
      builder: (context, snapshot) {
        Widget content;

        if (snapshot.connectionState == ConnectionState.waiting) {
          content = _loadingCard('A carregar experiências...');
        } else if (snapshot.hasError) {
          content = _messageCard(
            'Não foi possível carregar as experiências deste lugar.',
            icon: Icons.cloud_off_outlined,
          );
        } else {
          final experiences = snapshot.data ?? [];
          content = experiences.isEmpty
              ? _messageCard(
                  'Ainda não há partilhas por aqui. Deixa a primeira review!',
                  icon: Icons.photo_camera_back_outlined,
                )
              : Column(
                  children: experiences.map(_buildExperienceCard).toList(),
                );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            content,
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _createExperience,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Partilhar experiência neste lugar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: const BorderSide(color: borderColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExperienceCard(Map<String, dynamic> experience) {
    final title = experience['title']?.toString().trim() ?? '';
    final description = experience['description']?.toString().trim() ?? '';
    final author = ExperiencesService.getAuthorName(experience);
    final imageBase64 = experience['imageBase64']?.toString() ?? '';
    final createdAtRaw = experience['createdAt']?.toString() ?? '';
    final createdAt = DateTime.tryParse(createdAtRaw);
    final dateLabel = createdAt == null
        ? ''
        : '${createdAt.day.toString().padLeft(2, '0')}/'
              '${createdAt.month.toString().padLeft(2, '0')}/'
              '${createdAt.year}';

    Uint8List? imageBytes;
    if (imageBase64.isNotEmpty) {
      try {
        imageBytes = base64Decode(imageBase64);
      } on FormatException {
        imageBytes = null;
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageBytes != null)
            Image.memory(
              imageBytes,
              width: double.infinity,
              height: 190,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    description,
                    style: const TextStyle(
                      color: secondaryColor,
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      color: secondaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        author,
                        style: const TextStyle(
                          color: secondaryColor,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (dateLabel.isNotEmpty)
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: secondaryColor,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: secondaryColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageCard(
    String message, {
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: secondaryColor, size: 22),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: secondaryColor,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: accentColor,
                  padding: EdgeInsets.zero,
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isHttpUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFEDEEEF),
      width: double.infinity,
      child: const Center(
        child: Icon(Icons.landscape_outlined, size: 55, color: secondaryColor),
      ),
    );
  }

  Widget _coordinateRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: secondaryColor, fontSize: 13),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
