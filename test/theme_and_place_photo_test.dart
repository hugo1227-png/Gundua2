import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proto_2/theme/gundua_theme.dart';
import 'package:proto_2/widgets/place_photo.dart';

void main() {
  testWidgets('GUNDUA uses the primary accent and a quiet image fallback', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: GunduaTheme.light(),
      home: const Scaffold(body: SizedBox(width: 200, height: 140, child: PlacePhoto())),
    ));
    expect(Theme.of(tester.element(find.byType(PlacePhoto))).colorScheme.primary,
        GunduaTheme.accent);
    expect(find.byType(ColoredBox), findsWidgets);
  });
}
