import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proto_2/services/local_reviews_service.dart';
import 'package:proto_2/services/weekly_highlights_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const museum = {'placeId': 'museum-1', 'name': 'Museu'};
  const square = {'placeId': 'square-1', 'name': 'Praça'};

  test('avaliações locais podem ser criadas, editadas e apagadas', () async {
    final service = LocalReviewsService();
    await service.save(place: museum, rating: 5, comment: 'Excelente');
    expect((await service.getReviews()).length, 1);
    await service.save(place: museum, rating: 4, comment: 'Muito bom');
    final updated = await service.forPlace('museum-1');
    expect(updated?['rating'], 4);
    expect((await service.getReviews()).length, 1);
    await service.delete('museum-1');
    expect(await service.getReviews(), isEmpty);
  });

  test('destaque semanal mostra apenas visualizações reais recentes', () async {
    final service = WeeklyHighlightsService();
    final now = DateTime(2026, 11, 7, 16);
    await service.recordView(museum, at: now.subtract(const Duration(days: 1)));
    await service.recordView(museum, at: now.subtract(const Duration(hours: 2)));
    await service.recordView(square, at: now.subtract(const Duration(hours: 3)));
    await service.recordView(square, at: now.subtract(const Duration(days: 10)));
    final highlight = await service.mostViewedByMe(at: now);
    expect(highlight?['name'], 'Museu');
    expect(highlight?['weeklyViewCountOnDevice'], 2);
  });
}
