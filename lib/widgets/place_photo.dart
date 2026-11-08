import 'package:flutter/material.dart';
import '../theme/gundua_theme.dart';

/// Displays a real place photo when available; never substitutes a fake image.
class PlacePhoto extends StatelessWidget {
  const PlacePhoto({super.key, this.url, this.imageFuture});
  final String? url;
  final Future<String?>? imageFuture;

  @override
  Widget build(BuildContext context) {
    if (url?.isNotEmpty == true) return _network(url!);
    if (imageFuture == null) return const ColoredBox(color: GunduaTheme.image);
    return FutureBuilder<String?>(
      future: imageFuture,
      builder: (context, snapshot) {
        final imageUrl = snapshot.data;
        if (imageUrl?.isNotEmpty == true) return _network(imageUrl!);
        return ColoredBox(
          color: GunduaTheme.image,
          child: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)))
              : const SizedBox.expand(),
        );
      },
    );
  }

  Widget _network(String imageUrl) => Image.network(
    imageUrl, fit: BoxFit.cover,
    loadingBuilder: (context, child, progress) => progress == null
        ? child
        : const ColoredBox(color: GunduaTheme.image,
            child: Center(child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)))),
    errorBuilder: (context, error, stackTrace) =>
        const ColoredBox(color: GunduaTheme.image),
  );
}
