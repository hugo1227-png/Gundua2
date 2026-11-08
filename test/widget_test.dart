import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:proto_2/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('A aplicação GUNDUA apresenta o ecrã de boas-vindas', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GunduaApp());

    expect(find.text('gundua'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('O mundo\nespera por ti.'), findsOneWidget);
    expect(find.text('Explorar sem iniciar sessão'), findsOneWidget);
  });
}
