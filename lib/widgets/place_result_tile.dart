import 'package:flutter/material.dart';

import '../models/place.dart';
import '../theme/gundua_theme.dart';
import 'place_photo.dart';

/// One reusable category-aware result, used in Explore and Favorites.
class PlaceResultTile extends StatelessWidget {
  const PlaceResultTile({
    super.key,
    required this.place,
    required this.onTap,
    required this.onFavorite,
    required this.isFavorite,
    this.imageFuture,
    this.favoriteBusy = false,
  });

  final Place place;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final bool isFavorite;
  final bool favoriteBusy;
  final Future<String?>? imageFuture;

  static String categoryName(String category) {
    final value = category.toLowerCase();
    if (value.contains('restaurant') || value.contains('catering')) {
      return 'Restaurante';
    }
    if (value.contains('museum') || value.contains('museu')) {
      return 'Museu';
    }
    if (value.contains('monument') || value.contains('heritage') || value.contains('historic')) {
      return 'Monumento';
    }
    if (value.contains('park') || value.contains('garden') || value.contains('natural')) {
      return 'Natureza';
    }
    if (value.contains('beach') || value.contains('praia')) {
      return 'Praia';
    }
    if (value.contains('culture') || value.contains('theatre')) {
      return 'Cultura';
    }
    if (value.contains('square') || value.contains('praça')) {
      return 'Praça';
    }
    if (value == 'ponto de interesse' || value.isEmpty) {
      return 'Ponto de interesse';
    }
    return category.replaceAll('_', ' ').split('.').last;
  }

  String? get _hours {
    final hours = place.openingHours;
    if (hours is String && hours.trim().isNotEmpty) {
      return hours;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final distance = place.distanceMeters;
    final distanceText = distance == null ? null :
        distance < 1000 ? '${distance.round()} m' : '${(distance / 1000).toStringAsFixed(1)} km';
    final category = categoryName(place.category);
    final locality = (place.locality?.trim().isNotEmpty == true)
        ? place.locality! : place.address;

    return Material(
      color: GunduaTheme.surface,
      borderRadius: BorderRadius.circular(GunduaTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(GunduaTheme.spaceMd),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(GunduaTheme.innerRadius),
                child: SizedBox(
                  width: 112,
                  height: 124,
                  child: PlacePhoto(url: place.imageUrl, imageFuture: imageFuture),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category,
                        style: const TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700, color: GunduaTheme.accent)),
                    const SizedBox(height: 5),
                    Text(place.name,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(locality.isEmpty ? 'Localização não disponível' : locality,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: GunduaTheme.muted)),
                    if (category == 'Restaurante' && place.cuisine?.isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Text('Cozinha: ${place.cuisine}', maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: GunduaTheme.muted)),
                    ],
                    if (category == 'Restaurante' && place.priceRange?.isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Text(place.priceRange!, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: GunduaTheme.muted)),
                    ],
                    if (category == 'Museu' && place.admission?.isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Text('Entrada: ${place.admission}', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: GunduaTheme.muted)),
                    ],
                    if (place.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Text(place.description!, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: GunduaTheme.muted)),
                    ],
                    if (_hours != null) ...[
                      const SizedBox(height: 6),
                      Text(_hours!, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: GunduaTheme.muted)),
                    ],
                    if (place.rating != null) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text('${place.rating!.toStringAsFixed(1)}${place.reviewCount == null ? '' : ' (${place.reviewCount})'}',
                            style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
                      ]),
                    ],
                    if (distanceText != null) ...[
                      const SizedBox(height: 6),
                      Text(distanceText, style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600, color: GunduaTheme.ink)),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavorite ? 'Remover dos favoritos' : 'Guardar nos favoritos',
                onPressed: favoriteBusy ? null : onFavorite,
                icon: favoriteBusy
                    ? const SizedBox(width: 17, height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? GunduaTheme.accent : GunduaTheme.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
