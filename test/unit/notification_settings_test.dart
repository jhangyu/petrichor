import 'dart:convert';

import 'package:petrichor/core/storage/stored_setting.dart';
import 'package:petrichor/data/models/place.dart';
import 'package:petrichor/features/place/place_provider.dart';
import 'package:petrichor/features/settings/notification_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/provider_container.dart';

const taipei = Place(county: '臺北市', town: '中正區', latitude: 25.03, longitude: 121.52);
const banqiao = Place(county: '新北市', town: '板橋區', latitude: 25.01, longitude: 121.46);

Future<Object?> readOutcome(Future<Object?> Function() read) async {
  try {
    return await read();
  } catch (e) {
    return e;
  }
}

void expectCorrupt(Object? outcome, String key) {
  expect(outcome, isA<StoredSettingException>().having((e) => e.storageKey, 'key', key));
}

void main() {
  test('fresh install: everything off, quiet hours 22:00-07:00, no warning areas', () async {
    SharedPreferences.setMockInitialValues({});
    final c = newContainer();
    for (final t in NotificationToggle.values) {
      expect(await c.read(notificationToggleProvider(t).future), false, reason: t.name);
    }
    expect(await c.read(quietMinuteProvider(QuietEdge.start).future), 1320);
    expect(await c.read(quietMinuteProvider(QuietEdge.end).future), 420);
    expect(await c.read(warningAreasProvider.future), isEmpty);
  });

  test('each setting survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = newContainer();
    await first.read(savedPlacesProvider.notifier).save(taipei);
    for (final t in NotificationToggle.values) {
      await first.read(notificationToggleProvider(t).notifier).set(true);
    }
    await first.read(quietMinuteProvider(QuietEdge.start).notifier).set(60);
    await first.read(quietMinuteProvider(QuietEdge.end).notifier).set(1439);
    await first.read(warningAreasProvider.notifier).setWarningsEnabled(taipei, true);

    final second = newContainer();
    for (final t in NotificationToggle.values) {
      expect(await second.read(notificationToggleProvider(t).future), true, reason: t.name);
    }
    expect(await second.read(quietMinuteProvider(QuietEdge.start).future), 60);
    expect(await second.read(quietMinuteProvider(QuietEdge.end).future), 1439);
    expect(await second.read(warningAreasProvider.future), {taipei.areaKey});
  });

  group('corrupt value is an error and set recovers', () {
    test('notify.master=2', () async {
      SharedPreferences.setMockInitialValues({'notify.master': 2});
      final c = newContainer();
      expectCorrupt(await readOutcome(() => c.read(notificationToggleProvider(NotificationToggle.master).future)), 'notify.master');
    });

    test('notify.quietStart=1440', () async {
      SharedPreferences.setMockInitialValues({'notify.quietStart': 1440});
      final c = newContainer();
      expectCorrupt(
          await readOutcome(() => c.read(quietMinuteProvider(QuietEdge.start).future)), 'notify.quietStart');
    });

    test("notify.quietEnd='x'", () async {
      SharedPreferences.setMockInitialValues({'notify.quietEnd': 'x'});
      final c = newContainer();
      expectCorrupt(await readOutcome(() => c.read(quietMinuteProvider(QuietEdge.end).future)), 'notify.quietEnd');
    });

    for (final bad in ['{', '["a","a"]', '[""]']) {
      test('notify.warningAreas=$bad', () async {
        SharedPreferences.setMockInitialValues({
          'notify.warningAreas': bad,
          'place.saved': jsonEncode([
            {'county': '臺北市', 'town': '中正區', 'latitude': 25.03, 'longitude': 121.52},
          ]),
        });
        final c = newContainer();
        expectCorrupt(await readOutcome(() => c.read(warningAreasProvider.future)), 'notify.warningAreas');
        await c.read(warningAreasProvider.notifier).setWarningsEnabled(taipei, true);
        expect(c.read(warningAreasProvider).value, {taipei.areaKey});
        expect(await newContainer().read(warningAreasProvider.future), {taipei.areaKey});
      });
    }
  });

  test('corrupt warning areas with no saved places: reset recovers', () async {
    SharedPreferences.setMockInitialValues({'notify.warningAreas': '{'});
    final c = newContainer();
    expectCorrupt(await readOutcome(() => c.read(warningAreasProvider.future)), 'notify.warningAreas');
    await c.read(warningAreasProvider.notifier).reset();
    expect(c.read(warningAreasProvider).value, isEmpty);
    expect(await newContainer().read(warningAreasProvider.future), isEmpty);
  });

  test('warning areas: on for a saved place, pruned on remove, off after re-add, unsaved rejected', () async {
    SharedPreferences.setMockInitialValues({});
    final c = newContainer();
    await c.read(savedPlacesProvider.notifier).save(taipei);
    await c.read(savedPlacesProvider.notifier).save(banqiao);
    expect(await c.read(warningAreasProvider.future), isEmpty);

    await c.read(warningAreasProvider.notifier).setWarningsEnabled(taipei, true);
    expect(c.read(warningAreasProvider).value, {taipei.areaKey});

    await c.read(savedPlacesProvider.notifier).remove(taipei);
    expect(await c.read(warningAreasProvider.future), isEmpty);
    expect((await SharedPreferences.getInstance()).getString('notify.warningAreas'), '[]');

    await c.read(savedPlacesProvider.notifier).save(taipei);
    expect(await c.read(warningAreasProvider.future), isEmpty);

    const unsaved = Place(county: '高雄市', town: '前金區', latitude: 22.63, longitude: 120.29);
    await expectLater(c.read(warningAreasProvider.notifier).setWarningsEnabled(unsaved, true), throwsArgumentError);
  });
}
