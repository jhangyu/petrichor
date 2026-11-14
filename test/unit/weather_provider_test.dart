import 'dart:async';

import 'package:cwb_flutter/core/location/location_service.dart';
import 'package:cwb_flutter/data/models/weather_models.dart';
import 'package:cwb_flutter/data/repositories/weather_repository.dart';
import 'package:cwb_flutter/features/weather/weather_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_cwa_adapter.dart';

class MockLocationService extends Mock implements LocationService {}

final _taipei = LocationData(latitude: 25.046, longitude: 121.5166, city: '臺北市', district: '中正區');

/// 縣市級樣本（臺北市）借作鄉鎮資料集：改名成查詢的鄉鎮
Object? _renameToZhongzheng(Map<String, dynamic> json) {
  final locations = ((json['records'] as Map)['Locations'] as List).first as Map;
  ((locations['Location'] as List).first as Map)['LocationName'] = '中正區';
  return null;
}

Future<WeatherState> _settled(ProviderContainer container) {
  final completer = Completer<WeatherState>();
  late ProviderSubscription<WeatherState> sub;
  sub = container.listen<WeatherState>(weatherNotifierProvider, (_, next) {
    if (!next.isLoading && !completer.isCompleted) {
      sub.close();
      completer.complete(next);
    }
  }, fireImmediately: true);
  return completer.future;
}

void main() {
  late MockLocationService location;
  late FakeCwaAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    location = MockLocationService();
    adapter = FakeCwaAdapter();
    container = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(location),
      weatherRepositoryProvider.overrideWithValue(WeatherRepository(adapter.dio())),
      weatherClockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 14, 4)),
    ]);
    addTearDown(container.dispose);
  });

  test('loads real observation, 3-hourly and weekly data', () async {
    when(() => location.getCurrentLocation()).thenAnswer((_) async => _taipei);
    adapter.serveFixture('O-A0003-001');
    adapter.serveFixture('F-D0047-061');
    adapter.serveFixture('A-B0062-001');
    adapter.serveFixture('F-D0047-091', _renameToZhongzheng, 'F-D0047-063');

    final s = await _settled(container);

    expect(s.error, isNull);
    expect(s.location, _taipei);
    expect(s.current!.data.temperature, isNotNull);
    expect(s.hourly!.data, hasLength(4));
    expect(s.weekly!.data.first.minTemperature, 21);
    expect(s.sun!.data, hasLength(2));
  });

  test('location failure maps to a Chinese message and never calls the API', () async {
    when(() => location.getCurrentLocation()).thenThrow(
      LocationException(LocationFailure.permissionDeniedForever, 'denied'),
    );

    final s = await _settled(container);

    expect(s.error, '定位權限已被永久拒絕，請到系統設定開啟');
    expect(s.current, isNull);
    expect(adapter.requests, isEmpty);
  });

  test('failing sun times keep observation and both forecasts', () async {
    when(() => location.getCurrentLocation()).thenAnswer((_) async => _taipei);
    adapter.serveFixture('O-A0003-001');
    adapter.serveFixture('F-D0047-061');
    adapter.serveFixture('F-D0047-091', _renameToZhongzheng, 'F-D0047-063');
    adapter.serveStatus('A-B0062-001', 500);

    final s = await _settled(container);

    expect((s.sun as Failure).message, contains('A-B0062-001'));
    expect(s.current!.isSuccess, isTrue);
    expect(s.hourly!.data, hasLength(4));
    expect(s.weekly!.isSuccess, isTrue);
  });

  test('one failing dataset keeps the other three and exposes its own message', () async {
    when(() => location.getCurrentLocation()).thenAnswer((_) async => _taipei);
    adapter.serveFixture('O-A0003-001');
    adapter.serveStatus('F-D0047-061', 500);
    adapter.serveFixture('F-D0047-091', _renameToZhongzheng, 'F-D0047-063');
    adapter.serveFixture('A-B0062-001');

    final s = await _settled(container);

    expect(s.error, isNull);
    expect(s.hourly, isA<Failure<List<HourlyForecast>>>());
    expect((s.hourly as Failure).message, contains('F-D0047-061'));
    expect(s.current!.isSuccess, isTrue);
    expect(s.weekly!.data.first.minTemperature, 21);
    expect(s.sun!.data, hasLength(2));
  });
}
