import 'dart:async';

import 'package:petrichor/core/location/location_service.dart';
import 'package:petrichor/data/models/place.dart';
import 'package:petrichor/features/location/place_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/mock_location_service.dart';

/// 權限已允許，但 getCurrentPosition 永不完成（macOS 上定位服務不回應的情況）。
class _HangingPositionPlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) => Completer<Position>().future;
}

const _banqiao = Place(county: '新北市', town: '板橋區', latitude: 25.01154, longitude: 121.450888);

void main() {
  test('no position within the limit fails as positionUnavailable naming the step and the limit', () async {
    GeolocatorPlatform.instance = _HangingPositionPlatform();
    final service = LocationService(
      (latitude, longitude) async => throw StateError('unreachable: no position'),
      positionTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      service.getCurrentLocation(),
      throwsA(
        isA<LocationException>()
            .having((e) => e.failure, 'failure', LocationFailure.positionUnavailable)
            .having((e) => e.message, 'message', contains('getCurrentPosition'))
            .having((e) => e.cause, 'cause', isA<TimeoutException>()),
      ),
    );
  });

  test('a late GPS result after a manual selection does not override it', () async {
    SharedPreferences.setMockInitialValues({PlaceStore.gpsKey: true});
    final late = Completer<LocationData>();
    final location = MockLocationService();
    when(() => location.getCurrentLocation()).thenAnswer((_) => late.future);
    final container = ProviderContainer(overrides: [locationServiceProvider.overrideWithValue(location)]);
    addTearDown(container.dispose);
    final firstLoad = container.read(currentPlaceProvider.future);
    await container.read(placeStoreProvider.future);
    await pumpEventQueue();

    await container.read(currentPlaceProvider.notifier).select(_banqiao);
    late.complete(LocationData(
      latitude: 23.565,
      longitude: 119.586,
      county: '澎湖縣',
      town: '馬公市',
      fixedAt: DateTime.utc(2026, 11, 14, 6, 10),
    ));
    await firstLoad;
    await pumpEventQueue();

    final current = container.read(currentPlaceProvider).value as PlaceSelected;
    expect((current.place, current.source), (_banqiao, PlaceSource.manual));
  });

  test('a late GPS failure after a manual selection does not turn into NoPlace', () async {
    SharedPreferences.setMockInitialValues({PlaceStore.gpsKey: true});
    final late = Completer<LocationData>();
    final location = MockLocationService();
    when(() => location.getCurrentLocation()).thenAnswer((_) => late.future);
    final container = ProviderContainer(overrides: [locationServiceProvider.overrideWithValue(location)]);
    addTearDown(container.dispose);
    final firstLoad = container.read(currentPlaceProvider.future);
    await container.read(placeStoreProvider.future);
    await pumpEventQueue();

    await container.read(currentPlaceProvider.notifier).select(_banqiao);
    late.completeError(LocationException(LocationFailure.positionUnavailable, '10 秒內未取得位置'));
    await firstLoad;
    await pumpEventQueue();

    expect(container.read(currentPlaceProvider).value, isA<PlaceSelected>());
  });
}
