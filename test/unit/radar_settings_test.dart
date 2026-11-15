import 'package:petrichor/core/constants/app_constants.dart';
import 'package:petrichor/core/storage/stored_setting.dart';
import 'package:petrichor/features/radar/radar_playback.dart';
import 'package:petrichor/features/radar/radar_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/container.dart';

Future<(Duration, int, bool, int)> read(ProviderContainer c, RadarGroup g) async => (
      await c.read(radarWindowProvider(g).future),
      await c.read(radarFpsProvider(g).future),
      await c.read(radarRepeatProvider(g).future),
      await c.read(radarOpacityProvider(g).future),
    );

void main() {
  test('fresh install: each group opens at its own window and fps, 60 % opacity', () async {
    SharedPreferences.setMockInitialValues({});
    final c = newContainer();
    expect(await read(c, RadarGroup.taiwan), (const Duration(hours: 6), 8, true, 60));
    expect(await read(c, RadarGroup.regional), (const Duration(hours: 4), 12, true, 60));
    expect(radarGroupOf(AppConstants.radarTaiwan), RadarGroup.taiwan);
    for (final id in [AppConstants.radarShulin, AppConstants.radarNantun, AppConstants.radarLinyuan]) {
      expect(radarGroupOf(id), RadarGroup.regional);
    }
  });

  test('a change stays in its group and survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = newContainer();
    await read(first, RadarGroup.taiwan);
    await first.read(radarWindowProvider(RadarGroup.taiwan).notifier).set(const Duration(hours: 12));
    await first.read(radarFpsProvider(RadarGroup.taiwan).notifier).set(24);
    await first.read(radarRepeatProvider(RadarGroup.taiwan).notifier).set(false);
    await first.read(radarOpacityProvider(RadarGroup.taiwan).notifier).set(80);

    final second = newContainer();
    expect(await read(second, RadarGroup.taiwan), (const Duration(hours: 12), 24, false, 80));
    expect(await read(second, RadarGroup.regional), (const Duration(hours: 4), 12, true, 60));
  });

  test('a corrupt stored value is an error, and set() overwrites it', () async {
    const group = RadarGroup.regional;
    final cases = <(String, Object, Future<void> Function(ProviderContainer), Object)>[
      ('radar.regional.opacity', 55, (c) => c.read(radarOpacityProvider(group).notifier).set(30), radarOpacityProvider(group)),
      ('radar.regional.fps', 5, (c) => c.read(radarFpsProvider(group).notifier).set(2), radarFpsProvider(group)),
      ('radar.regional.repeat', 2, (c) => c.read(radarRepeatProvider(group).notifier).set(false), radarRepeatProvider(group)),
      ('radar.regional.windowMinutes', '240', (c) => c.read(radarWindowProvider(group).notifier).set(const Duration(hours: 1)),
          radarWindowProvider(group)),
    ];
    for (final (key, corrupt, set, provider) in cases) {
      SharedPreferences.setMockInitialValues({key: corrupt});
      final container = newContainer();
      final p = provider as AsyncNotifierProvider;
      await expectLater(container.read(p.future), throwsA(isA<StoredSettingException>()), reason: key);

      await set(container);

      expect(container.read(p).hasError, isFalse, reason: key);
      expect((await SharedPreferences.getInstance()).getInt(key), isNotNull, reason: key);
    }
  });
}
