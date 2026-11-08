import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proto_2/services/location_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('guarda uma localização manual sem inventar GPS', () async {
    final service = LocationPreferenceService();
    expect(await service.getSelected(), isNull);

    await service.save(const AppLocation(
      label: 'Lisboa',
      latitude: 38.7223,
      longitude: -9.1393,
      isDeviceLocation: false,
    ));
    final selected = await service.getSelected();
    expect(selected?.label, 'Lisboa');
    expect(selected?.latitude, closeTo(38.7223, 0.00001));
    expect(selected?.isDeviceLocation, isFalse);
  });

  test('a localização é partilhada e eliminada ao terminar a sessão', () async {
    final service = LocationPreferenceService();
    await service.save(const AppLocation(label: 'Porto',
        latitude: 41.15, longitude: -8.61, isDeviceLocation: false));
    expect(LocationPreferenceService.selection.value?.label, 'Porto');
    final otherScreen = LocationPreferenceService();
    expect((await otherScreen.getSelected())?.label, 'Porto');
    await service.clear();
    expect(LocationPreferenceService.selection.value, isNull);
    expect(await otherScreen.getSelected(), isNull);
  });
}
