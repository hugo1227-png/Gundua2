import 'package:flutter_test/flutter_test.dart';
import 'package:proto_2/services/curated_places_service.dart';

void main() {
  test('a selecção de Lisboa contém dez lugares com coordenadas', () {
    final places = CuratedPlacesService.lisbonHiddenGems;

    expect(places, hasLength(10));
    expect(
      places.map((place) => place['name']),
      containsAll([
        'Reservatório da Mãe d’Água das Amoreiras',
        'Museu da Marioneta',
        'Feira da Ladra',
        'Museu Bordalo Pinheiro',
        'Estufa Fria',
      ]),
    );

    for (final place in places) {
      expect(place['latitude'], isA<double>());
      expect(place['longitude'], isA<double>());
      expect(place['locality'], isNotEmpty);
    }
  });
}
