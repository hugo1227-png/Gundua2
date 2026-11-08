import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:proto_2/screens/profile_screen.dart';

void main() {
  testWidgets('Perfil abre As minhas experiências', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();

    final experiencesLink = find.text('Ver e partilhar experiências');
    await tester.ensureVisible(experiencesLink);
    await tester.tap(experiencesLink);
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(AppBar, 'As minhas experiências'),
      findsOneWidget,
    );
    expect(find.text('As tuas experiências começam aqui'), findsOneWidget);
  });
}
