import 'package:flutter/material.dart';

import '../models/place.dart';
import '../theme/gundua_theme.dart';
import '../services/favorites_service.dart';
import '../widgets/place_result_tile.dart';
import 'place_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, this.refreshToken = 0});
  final int refreshToken;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesService _service = FavoritesService();
  List<Map<String, dynamic>> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FavoritesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final favorites = await _service.getFavorites();
      if (mounted) {
        setState(() { _favorites = favorites; _loading = false; });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível carregar os favoritos.')),
        );
      }
    }
  }

  Future<void> _remove(Map<String, dynamic> place) async {
    try {
      await _service.removeFavorite(place);
      if (mounted) {
        await _load();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível remover.')),
        );
      }
    }
  }

  Future<void> _open(Map<String, dynamic> place) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlaceDetailsScreen(place: place)),
    );
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GunduaTheme.canvas,
      body: SafeArea(
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 28, 22, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Os teus favoritos',
                  style: TextStyle(fontSize: 30, letterSpacing: -.7,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _favorites.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite_border, size: 52, color: Colors.black38),
                            SizedBox(height: 14),
                            Text('Ainda não guardaste nenhum lugar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                            SizedBox(height: 7),
                            Text('Guarda lugares que queres conhecer.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
                        itemCount: _favorites.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _favorites[index];
                          return PlaceResultTile(
                            key: ValueKey(_service.getPlaceId(item)),
                            place: Place.fromMap(item),
                            isFavorite: true,
                            onTap: () => _open(item),
                            onFavorite: () => _remove(item),
                          );
                        },
                      ),
                    )),
        ]),
      ),
    );
  }
}
