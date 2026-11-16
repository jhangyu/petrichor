import 'package:petrichor/data/location/location_service.dart';
import 'package:petrichor/core/storage/stored_setting.dart';
import 'package:petrichor/data/models/place.dart';
import 'package:petrichor/data/repositories/weather_repository.dart';
import 'package:petrichor/features/place/place_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_cwa_adapter.dart';
import '../support/mock_location_service.dart';

const _banqiao = Place(county: '新北市', town: '板橋區', latitude: 25.01154, longitude: 121.450888);
const _magong = Place(county: '澎湖縣', town: '馬公市', latitude: 23.565, longitude: 119.586);

void main() {
  late MockLocationService location;

  ProviderContainer newContainer() {
    final container = ProviderContainer(overrides: [locationServiceProvider.overrideWithValue(location)]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    location = MockLocationService();
  });

  test('town list parses with county in 「臺」 and coordinates', () async {
    final adapter = FakeCwaAdapter()..serveFixture('F-D0047-061');

    final towns = (await WeatherRepository(adapter.createDio()).getTowns('台北市')).data;

    expect(adapter.requests.single.pathSegments.last, 'F-D0047-061');
    expect(towns, [const Place(county: '臺北市', town: '中正區', latitude: 25.046058, longitude: 121.516565)]);
  });

  test('saved places and the manual choice round-trip through persistence', () async {
    when(() => location.getCurrentLocation()).thenThrow(LocationException(LocationFailure.permissionDenied, 'denied'));
    final first = newContainer();
    final saved = first.read(savedPlacesProvider.notifier);
    await saved.save(_banqiao);
    await saved.save(_magong);
    await saved.save(_banqiao);
    await saved.remove(_magong);
    await saved.save(_magong);
    await first.read(currentPlaceProvider.notifier).select(_banqiao);

    clearInteractions(location);
    final second = newContainer();

    expect(await second.read(savedPlacesProvider.future), [_banqiao, _magong]);
    final current = await second.read(currentPlaceProvider.future) as PlaceSelected;
    expect((current.place, current.source), (_banqiao, PlaceSource.manual));
    verifyNever(() => location.getCurrentLocation());
  });

  test('first run without a stored choice: no place, no location request', () async {
    final current = await newContainer().read(currentPlaceProvider.future);

    expect(current, isA<NoPlace>().having((p) => p.kind, 'kind', NoPlaceKind.firstRun));
    verifyNever(() => location.getCurrentLocation());
  });

  test('choosing GPS is remembered: next launch locates without asking again for a choice', () async {
    when(() => location.getCurrentLocation()).thenAnswer(
      (_) async => LocationData(
        latitude: 23.565,
        longitude: 119.586,
        county: '澎湖縣',
        town: '馬公市',
        fixedAt: DateTime.utc(2026, 11, 14, 6, 10),
      ),
    );
    final first = newContainer();
    await first.read(currentPlaceProvider.future);
    await first.read(currentPlaceProvider.notifier).startAutoLocate();

    final current = await newContainer().read(currentPlaceProvider.future) as PlaceSelected;

    expect((current.place, current.source), (_magong, PlaceSource.gps));
    expect(current.fixedAt, DateTime.utc(2026, 11, 14, 6, 10));
    verify(() => location.getCurrentLocation()).called(2);
  });

  test('GPS denied after the user chose it is not a first run and keeps the underlying cause', () async {
    when(() => location.getCurrentLocation()).thenThrow(LocationException(LocationFailure.permissionDenied, 'denied'));
    final container = newContainer();
    await container.read(currentPlaceProvider.future);

    await container.read(currentPlaceProvider.notifier).startAutoLocate();

    expect(
      container.read(currentPlaceProvider).value,
      isA<NoPlace>()
          .having((p) => p.kind, 'kind', NoPlaceKind.locationFailed)
          .having((p) => p.reason, 'reason', LocationFailure.permissionDenied)
          .having((p) => p.cause, 'cause', 'denied'),
    );
  });

  test('corrupted stored places surface a typed error', () async {
    SharedPreferences.setMockInitialValues({PlaceStore.savedPlacesKey: '[{"county":"新北市"}]'});

    await expectLater(
      newContainer().read(savedPlacesProvider.future),
      throwsA(isA<StoredSettingException>().having((e) => e.key, 'key', PlaceStore.savedPlacesKey)),
    );
  });

  void answerFix() => when(() => location.getCurrentLocation()).thenAnswer(
        (_) async => LocationData(
          latitude: 23.565,
          longitude: 119.586,
          county: '澎湖縣',
          town: '馬公市',
          fixedAt: DateTime.utc(2026, 11, 14, 6, 10),
        ),
      );

  test('auto-locate off without a manual place: autoLocateOff, never locates, survives restart', () async {
    SharedPreferences.setMockInitialValues({PlaceStore.autoLocateKey: false});

    final first = await newContainer().read(currentPlaceProvider.future);
    final second = await newContainer().read(currentPlaceProvider.future);

    for (final c in [first, second]) {
      expect(c, isA<NoPlace>().having((p) => p.kind, 'kind', NoPlaceKind.autoLocateOff));
      expect(c.autoLocate, isFalse);
    }
    verifyNever(() => location.getCurrentLocation());
  });

  test('non-bool place.gps is a typed error and select() recovers', () async {
    SharedPreferences.setMockInitialValues({PlaceStore.autoLocateKey: 'yes'});
    final container = newContainer();

    await expectLater(
      container.read(currentPlaceProvider.future),
      throwsA(isA<StoredSettingException>().having((e) => e.key, 'key', 'place.gps')),
    );
    await container.read(currentPlaceProvider.notifier).select(_banqiao);

    final current = await newContainer().read(currentPlaceProvider.future) as PlaceSelected;
    expect((current.place, current.source), (_banqiao, PlaceSource.manual));
  });

  test('stopAutoLocate after a GPS fix keeps the same place as manual and stops locating', () async {
    answerFix();
    final container = newContainer();
    await container.read(currentPlaceProvider.future);
    await container.read(currentPlaceProvider.notifier).startAutoLocate();
    expect(container.read(currentPlaceProvider).value!.autoLocate, isTrue);

    await container.read(currentPlaceProvider.notifier).stopAutoLocate();

    final now = container.read(currentPlaceProvider).value as PlaceSelected;
    expect((now.place, now.source, now.autoLocate), (_magong, PlaceSource.manual, false));
    clearInteractions(location);
    final restarted = await newContainer().read(currentPlaceProvider.future) as PlaceSelected;
    expect((restarted.place, restarted.source), (_magong, PlaceSource.manual));
    verifyNever(() => location.getCurrentLocation());
  });

  test('select after startAutoLocate stores place.gps = false', () async {
    answerFix();
    final container = newContainer();
    await container.read(currentPlaceProvider.future);
    await container.read(currentPlaceProvider.notifier).startAutoLocate();

    await container.read(currentPlaceProvider.notifier).select(_banqiao);

    expect((await SharedPreferences.getInstance()).get(PlaceStore.autoLocateKey), false);
  });

  test('saving the same area with other coordinates keeps one entry', () async {
    final container = newContainer();
    final saved = container.read(savedPlacesProvider.notifier);
    await saved.save(_banqiao);
    await saved.save(const Place(county: '新北市', town: '板橋區', latitude: 25.0, longitude: 121.4));

    expect(await container.read(savedPlacesProvider.future), [_banqiao]);
  });

  test('clear() recovers a corrupt saved list to empty', () async {
    SharedPreferences.setMockInitialValues({PlaceStore.savedPlacesKey: '{'});
    final container = newContainer();
    await expectLater(
      container.read(savedPlacesProvider.future),
      throwsA(isA<StoredSettingException>().having((e) => e.key, 'key', 'place.saved')),
    );

    await container.read(savedPlacesProvider.notifier).clear();

    expect(container.read(savedPlacesProvider).value, isEmpty);
    expect(await newContainer().read(savedPlacesProvider.future), isEmpty);
  });
}
