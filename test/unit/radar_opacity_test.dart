import 'package:cwb_flutter/features/radar/radar_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer newContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('opacity defaults to 60 % and a set value survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = newContainer();
    expect(await first.read(radarOpacityProvider.future), radarOpacityDefaultPercent);

    await first.read(radarOpacityProvider.notifier).set(80);

    expect((await SharedPreferences.getInstance()).getInt(RadarOpacity.key), 80);
    expect(await newContainer().read(radarOpacityProvider.future), 80);
  });

  test('a corrupt stored opacity is an error, and set() overwrites it', () async {
    for (final corrupt in <Object>[55, 0, 110, '60']) {
      SharedPreferences.setMockInitialValues({RadarOpacity.key: corrupt});
      final container = newContainer();
      await expectLater(container.read(radarOpacityProvider.future), throwsA(isA<StoredRadarOpacityException>()),
          reason: 'stored $corrupt');

      await container.read(radarOpacityProvider.notifier).set(30);

      expect(container.read(radarOpacityProvider).value, 30);
      expect((await SharedPreferences.getInstance()).getInt(RadarOpacity.key), 30);
    }
  });
}
