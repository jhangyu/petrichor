import 'package:petrichor/core/storage/stored_setting.dart';
import 'package:petrichor/features/hazard/rainfall/rain_accumulation_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/provider_container.dart';

const _key = 'rainfall.accumWindowHours';

void main() {
  test('absent opens at 24 h, a valid stored window is read back', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await newContainer().read(rainAccumulationWindowProvider.future), 24);

    SharedPreferences.setMockInitialValues({_key: 168});
    expect(await newContainer().read(rainAccumulationWindowProvider.future), 168);
  });

  test('a corrupt stored window is an error', () async {
    for (final corrupt in <Object>[3, '24']) {
      SharedPreferences.setMockInitialValues({_key: corrupt});
      final c = newContainer();
      await expectLater(c.read(rainAccumulationWindowProvider.future), throwsA(isA<StoredSettingException>()), reason: '$corrupt');
    }
  });
}
