import 'package:flutter/material.dart';

import '../theme/gundua_theme.dart';

/// Layout-matched loading states. They reserve space without fake place data.
class PlaceSkeleton extends StatelessWidget {
  const PlaceSkeleton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: 216,
        decoration: BoxDecoration(
          color: GunduaTheme.surface,
          borderRadius: BorderRadius.circular(GunduaTheme.cardRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Expanded(child: ColoredBox(color: GunduaTheme.image)),
          Padding(
            padding: const EdgeInsets.all(GunduaTheme.spaceMd),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _line(135),
              const SizedBox(height: GunduaTheme.spaceSm),
              _line(90),
            ]),
          ),
        ]),
      );
    }
    return Container(
      height: 148,
      decoration: BoxDecoration(
        color: GunduaTheme.surface,
        borderRadius: BorderRadius.circular(GunduaTheme.cardRadius),
      ),
      padding: const EdgeInsets.all(GunduaTheme.spaceMd),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(GunduaTheme.innerRadius),
          child: const SizedBox(width: 112, height: 124,
              child: ColoredBox(color: GunduaTheme.image)),
        ),
        const SizedBox(width: GunduaTheme.spaceLg),
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(80),
            const SizedBox(height: 10),
            _line(180),
            const SizedBox(height: 10),
            _line(120),
          ],
        )),
      ]),
    );
  }

  static Widget _line(double width) => Container(
    height: 10,
    width: width,
    decoration: BoxDecoration(
      color: GunduaTheme.image,
      borderRadius: BorderRadius.circular(5),
    ),
  );
}
