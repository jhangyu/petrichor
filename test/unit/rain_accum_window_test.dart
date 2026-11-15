import 'package:cwb_flutter/core/storage/stored_setting.dart';
import 'package:cwb_flutter/features/hazard/rainfall/accum_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'rainfall.accumWindowHours';

ProviderContainer newContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('absent opens at 24 h, a valid stored window is read back', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await newContainer().read(rainAccumWindowProvider.future), 24);

    SharedPreferences.setMockInitialValues({_key: 168});
    expect(await newContainer().read(rainAccumWindowProvider.future), 168);
  });

  test('a corrupt stored window is an error, and set() overwrites it', () async {
    for (final corrupt in <Object>[3, '24']) {
      SharedPreferences.setMockInitialValues({_key: corrupt});
      final c = newContainer();
      await expectLater(c.read(rainAccumWindowProvider.future), throwsA(isA<StoredSettingException>()), reason: '$corrupt');

      await c.read(rainAccumWindowProvider.notifier).set(48);

      expect(c.read(rainAccumWindowProvider).value, 48);
      expect((await SharedPreferences.getInstance()).getInt(_key), 48);
    }
  });
}
