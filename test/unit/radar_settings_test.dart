import 'package:petrichor/core/api/cwa_datasets.dart';
import 'package:petrichor/core/storage/stored_setting.dart';
import 'package:petrichor/features/radar/radar_playback.dart';
import 'package:petrichor/features/radar/radar_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/provider_container.dart';

Future<(Duration, int, bool, int)> read(ProviderContainer c, RadarSettingsGroup g) async => (
      await c.read(radarWindowProvider(g).future),
      await c.read(radarFramesPerSecondProvider(g).future),
      await c.read(radarRepeatProvider(g).future),
      await c.read(radarOpacityProvider(g).future),
    );

void main() {
  test('fresh install: each group opens at its own window and fps, 60 % opacity', () async {
    SharedPreferences.setMockInitialValues({});
    final c = newContainer();
    expect(await read(c, RadarSettingsGroup.taiwan), (const Duration(hours: 6), 8, true, 60));
    expect(await read(c, RadarSettingsGroup.regional), (const Duration(hours: 4), 12, true, 60));
    expect(radarSettingsGroupOf(CwaDatasets.radarTaiwanDatasetId), RadarSettingsGroup.taiwan);
    for (final id in [CwaDatasets.radarShulinDatasetId, CwaDatasets.radarNantunDatasetId, CwaDatasets.radarLinyuanDatasetId]) {
      expect(radarSettingsGroupOf(id), RadarSettingsGroup.regional);
    }
  });

  test('a change stays in its group and survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = newContainer();
    await read(first, RadarSettingsGroup.taiwan);
    await first.read(radarWindowProvider(RadarSettingsGroup.taiwan).notifier).set(const Duration(hours: 12));
    await first.read(radarFramesPerSecondProvider(RadarSettingsGroup.taiwan).notifier).set(24);
    await first.read(radarRepeatProvider(RadarSettingsGroup.taiwan).notifier).set(false);
    await first.read(radarOpacityProvider(RadarSettingsGroup.taiwan).notifier).set(80);

    final second = newContainer();
    expect(await read(second, RadarSettingsGroup.taiwan), (const Duration(hours: 12), 24, false, 80));
    expect(await read(second, RadarSettingsGroup.regional), (const Duration(hours: 4), 12, true, 60));
  });

  test('a corrupt stored value is an error, and set() overwrites it', () async {
    const group = RadarSettingsGroup.regional;
    final cases = <(String, Object, Future<void> Function(ProviderContainer), Object)>[
      ('radar.regional.opacity', 55, (c) => c.read(radarOpacityProvider(group).notifier).set(30), radarOpacityProvider(group)),
      ('radar.regional.fps', 5, (c) => c.read(radarFramesPerSecondProvider(group).notifier).set(2), radarFramesPerSecondProvider(group)),
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
