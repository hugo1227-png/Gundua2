import 'package:flutter_test/flutter_test.dart';
import 'package:proto_2/services/place_search_service.dart';
import 'package:proto_2/widgets/place_result_tile.dart';

void main() {
  test('reconhece pesquisa por categorias', () {
    expect(PlaceSearchService.categoryFromTerm('museus'), 'Museus');
    expect(PlaceSearchService.categoryFromTerm('Restaurantes'), 'Restaurantes');
    expect(PlaceSearchService.categoryFromTerm('Praça do Comércio'), isNull);
  });

  test('traduz categoria técnica para título legível', () {
    expect(PlaceResultTile.categoryName('catering.restaurant'), 'Restaurante');
    expect(PlaceResultTile.categoryName('entertainment.museum'), 'Museu');
  });
}
