import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proto_2/services/place_search_service.dart';

void main() {
  late SearchHistoryService history;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    history = SearchHistoryService();
  });

  test('guarda pesquisas recentes sem duplicados', () async {
    await history.add(placeQuery: 'Museu da Marioneta', locationQuery: 'Lisboa');
    await history.add(placeQuery: 'Museu da Marioneta', locationQuery: 'Lisboa');
    await history.add(placeQuery: 'Praias', locationQuery: 'Cascais');

    final result = await history.getRecentSearches();

    expect(result, hasLength(2));
    expect(result.first['placeQuery'], 'Praias');
    expect(result.last['placeQuery'], 'Museu da Marioneta');
  });

  test('limpa todo o histórico de pesquisas', () async {
    await history.add(placeQuery: 'Museu', locationQuery: 'Lisboa');
    await history.clear();

    expect(await history.getRecentSearches(), isEmpty);
  });

  test('mantém apenas as doze pesquisas mais recentes', () async {
    for (var index = 0; index < 15; index++) {
      await history.add(placeQuery: 'Lugar $index', locationQuery: 'Lisboa');
    }

    final result = await history.getRecentSearches();

    expect(result, hasLength(12));
    expect(result.first['placeQuery'], 'Lugar 14');
    expect(result.last['placeQuery'], 'Lugar 3');
  });
}
