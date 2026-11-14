import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cwb_flutter/core/location/location_service.dart';
import 'package:cwb_flutter/data/models/place.dart';
import 'package:cwb_flutter/data/models/weather_models.dart';
import 'package:cwb_flutter/data/repositories/weather_repository.dart';
import 'package:cwb_flutter/features/location/place_provider.dart';
import 'package:cwb_flutter/features/weather/weather_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_cwa_adapter.dart';

class MockLocationService extends Mock implements LocationService {}

/// file API 請求（72 小時預報發布時間）一律回臺北市 3 天預報的開頭樣本；其餘照 [FakeCwaAdapter] 路由。
class _FileApiAdapter extends FakeCwaAdapter {
  final List<Uri> fileRequests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    if (!options.uri.path.startsWith('/fileapi/')) return super.fetch(options, requestStream, cancelFuture);
    fileRequests.add(options.uri);
    return Future.value(ResponseBody.fromString(File('test/fixtures/cwa/F-D0047-061-head.txt').readAsStringSync(), 206));
  }
}

final _taipei = LocationData(
  latitude: 25.046,
  longitude: 121.5166,
  city: '臺北市',
  district: '中正區',
  fixedAt: DateTime.utc(2026, 11, 14, 4),
);
const _banqiao = Place(county: '新北市', town: '板橋區', latitude: 25.01154, longitude: 121.450888);

/// 臺北市樣本借作其他鄉鎮資料集：改名成查詢的鄉鎮
Object? Function(Map<String, dynamic>) _renameTo(String town) => (json) {
      final locations = ((json['records'] as Map)['Locations'] as List).first as Map;
      ((locations['Location'] as List).first as Map)['LocationName'] = town;
      return null;
    };

Future<WeatherState> _settled(ProviderContainer container) {
  final completer = Completer<WeatherState>();
  final sub = container.listen<WeatherState>(weatherNotifierProvider, (_, next) {
    if (!next.isLoading && !completer.isCompleted) completer.complete(next);
  }, fireImmediately: true);
  return completer.future.whenComplete(sub.close);
}

void main() {
  late MockLocationService location;
  late _FileApiAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({PlaceStore.gpsKey: true});
    location = MockLocationService();
    adapter = _FileApiAdapter();
    container = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(location),
      weatherRepositoryProvider.overrideWithValue(WeatherRepository(adapter.dio())),
      weatherClockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 14, 4)),
    ]);
    addTearDown(container.dispose);
  });

  void serveTaipei() {
    adapter.serveFixture('O-A0003-001');
    adapter.serveFixture('F-D0047-061');
    adapter.serveFixture('A-B0062-001');
    adapter.serveFixture('F-D0047-091', _renameTo('中正區'), 'F-D0047-063');
  }

  test('loads real observation, 3-hourly and weekly data for the GPS place', () async {
    when(() => location.getCurrentLocation()).thenAnswer((_) async => _taipei);
    serveTaipei();

    final s = await _settled(container);

    expect(s.error, isNull);
    expect(s.location, Place.fromLocation(_taipei));
    expect(s.current!.data.temperature, isNotNull);
    expect(s.hourly!.data, hasLength(4));
    expect(s.weekly!.data.first.minTemperature, 21);
    expect(s.sun!.data, hasLength(2));
    expect(s.hourlyIssuedAt!.data, DateTime.parse('2026-11-14T17:00:00+08:00'));
    expect(adapter.fileRequests.single.pathSegments.last, 'F-D0047-061');
  });

  test('permission denied with no saved choice: no place, denial reason, API never called', () async {
    when(() => location.getCurrentLocation()).thenThrow(
      LocationException(LocationFailure.permissionDenied, 'denied'),
    );

    final s = await _settled(container);
    final place = await container.read(currentPlaceProvider.future);

    expect(place, isA<NoPlace>().having((p) => p.reason, 'reason', LocationFailure.permissionDenied));
    expect(s.error, locationFailureMessage(LocationFailure.permissionDenied));
    expect(s.location, isNull);
    expect(s.current, isNull);
    expect(adapter.requests, isEmpty);
  });

  test('after selecting a manual town the home provider queries that town', () async {
    when(() => location.getCurrentLocation()).thenThrow(
      LocationException(LocationFailure.permissionDenied, 'denied'),
    );
    adapter.serveFixture('O-A0003-001');
    adapter.serveFixture('F-D0047-061', _renameTo('板橋區'), 'F-D0047-069');
    adapter.serveFixture('F-D0047-091', _renameTo('板橋區'), 'F-D0047-071');
    adapter.serveFixture('A-B0062-001');
    await _settled(container);

    await container.read(currentPlaceProvider.notifier).select(_banqiao);
    final s = await _settled(container);

    expect(s.location, _banqiao);
    expect(s.hourly!.data, hasLength(4));
    final byDataset = {for (final r in adapter.requests) r.pathSegments.last: r.queryParameters};
    expect(byDataset['F-D0047-069']!['LocationName'], '板橋區');
    expect(byDataset['F-D0047-071']!['LocationName'], '板橋區');
    expect(byDataset['A-B0062-001']!['CountyName'], '新北市');
    expect(adapter.fileRequests.last.pathSegments.last, 'F-D0047-069');
  });

  test('failing sun times keep observation and both forecasts', () async {
    when(() => location.getCurrentLocation()).thenAnswer((_) async => _taipei);
    adapter.serveFixture('O-A0003-001');
    adapter.serveFixture('F-D0047-061');
    adapter.serveFixture('F-D0047-091', _renameTo('中正區'), 'F-D0047-063');
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
    adapter.serveFixture('F-D0047-091', _renameTo('中正區'), 'F-D0047-063');
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
