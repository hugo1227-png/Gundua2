import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proto_2/theme/gundua_theme.dart';
import 'package:proto_2/widgets/place_skeleton.dart';

void main() {
  testWidgets('GUNDUA shows a list skeleton without fake places', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: GunduaTheme.light(),
      home: const Scaffold(body: PlaceSkeleton()),
    ));

    expect(find.byType(PlaceSkeleton), findsOneWidget);
    expect(find.textContaining('Localização por definir'), findsNothing);
  });

  testWidgets('GUNDUA shows a compact carousel skeleton', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: GunduaTheme.light(),
      home: const Scaffold(body: SizedBox(
        height: 265,
        child: PlaceSkeleton(compact: true),
      )),
    ));

    expect(find.byType(PlaceSkeleton), findsOneWidget);
  });
}
