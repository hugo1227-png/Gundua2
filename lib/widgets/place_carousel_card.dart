import 'package:flutter/material.dart';

import '../models/place.dart';
import 'place_result_tile.dart';
import 'place_photo.dart';
import '../theme/gundua_theme.dart';

/// Cartão compacto para coleções editoriais; resultados de pesquisa usam
/// PlaceResultTile em lista vertical para melhor leitura dos dados.
class PlaceCarouselCard extends StatelessWidget {
  const PlaceCarouselCard({
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

  @override
  Widget build(BuildContext context) {
    final distance = place.distanceMeters;
    final locality = place.locality?.isNotEmpty == true
        ? place.locality! : place.address;
    return Material(
      color: GunduaTheme.surface,
      borderRadius: BorderRadius.circular(GunduaTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                PlacePhoto(url: place.imageUrl, imageFuture: imageFuture),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white.withValues(alpha: .93),
                    shape: const CircleBorder(),
                    child: IconButton(
                      iconSize: 20,
                      tooltip: isFavorite ? 'Remover favorito' : 'Guardar favorito',
                      onPressed: favoriteBusy ? null : onFavorite,
                      icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? GunduaTheme.accent : Colors.black87),
                    ),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(PlaceResultTile.categoryName(place.category),
                  maxLines: 1, style: const TextStyle(color: GunduaTheme.accent,
                      fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(place.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, height: 1.2, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                if (locality.isNotEmpty)
                  Text(locality, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: GunduaTheme.muted)),
                const SizedBox(height: 6),
                Row(children: [
                  if (place.rating != null) ...[
                    const Icon(Icons.star_rounded, color: Color(0xFFE2A827), size: 15),
                    Text(place.rating!.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                    const SizedBox(width: 6),
                  ],
                  if (distance != null)
                    Expanded(child: Text(distance < 1000
                      ? '${distance.round()} m' : '${(distance / 1000).toStringAsFixed(1)} km',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 12, color: GunduaTheme.muted))),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
