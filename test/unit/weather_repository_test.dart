import 'dart:io';

import 'package:cwb_flutter/data/models/weather_models.dart';
import 'package:cwb_flutter/core/location/location_service.dart';
import 'package:cwb_flutter/data/repositories/weather_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_cwa_adapter.dart';

LocationData _at(double lat, double lon, String city, String district) =>
    LocationData(latitude: lat, longitude: lon, city: city, district: district);

Map<String, dynamic> _station(Map<String, dynamic> json, String name) =>
    ((json['records'] as Map)['Station'] as List).cast<Map<String, dynamic>>().firstWhere((s) => s['StationName'] == name);

/// 取 1 週預報 臺北市 的 WeatherElement 內指定要素的第 [slot] 個時間槽的第一個 ElementValue
Map<String, dynamic> _weeklyValue(Map<String, dynamic> json, String element, int slot) {
  final location = (((json['records'] as Map)['Locations'] as List).first as Map)['Location'] as List;
  final elements = ((location.first as Map)['WeatherElement'] as List).cast<Map<String, dynamic>>();
  final time = (elements.firstWhere((e) => e['ElementName'] == element)['Time'] as List)[slot] as Map;
  return ((time['ElementValue'] as List).first as Map).cast<String, dynamic>();
}

void main() {
  late FakeCwaAdapter adapter;
  late WeatherRepository repo;

  setUp(() {
    adapter = FakeCwaAdapter();
    repo = WeatherRepository(adapter.dio());
  });

  group('getCurrentWeather (O-A0003-001)', () {
    test('picks the nearest station and parses its observation', () async {
      adapter.serveFixture('O-A0003-001');
      final r = await repo.getCurrentWeather(_at(25.17, 121.45, '新北市', '淡水區'));

      final w = r.data;
      expect(w.stationName, '淡水');
      expect(w.temperature, 21.4);
      expect(w.humidity, 95);
      expect(w.windSpeed, 0.3);
      expect(w.weather, '陰');
      expect((w.windDirection as WindFrom).degrees, 70);
      expect(w.dailyHigh, 25.5);
      expect(w.dailyLow, 21.1);
      expect(w.observedAt.toUtc(), DateTime.utc(2026, 11, 14, 12, 30));
      expect(w.distanceKm, lessThan(2));
    });

    test('wind direction: 0 is calm, 990 is variable, -99 is missing, out of range is a Failure', () async {
      Future<Result<CurrentWeather>> withWind(String raw) {
        adapter.serveFixture('O-A0003-001', (json) {
          (_station(json, '淡水')['WeatherElement'] as Map<String, dynamic>)['WindDirection'] = raw;
          return null;
        });
        return repo.getCurrentWeather(_at(25.17, 121.45, '新北市', '淡水區'));
      }

      expect((await withWind('0.0')).data.windDirection, isA<CalmWind>());
      expect((await withWind('990.0')).data.windDirection, isA<VariableWind>());
      expect((await withWind('-99')).data.windDirection, isNull);
      final bad = await withWind('500.0') as Failure;
      expect(bad.message, contains('500.0'));
      expect(bad.dataset, 'O-A0003-001');
    });

    test('skips stations without temperature and maps -99 to missing', () async {
      adapter.serveFixture('O-A0003-001', (json) {
        final tamsui = _station(json, '淡水')['WeatherElement'] as Map<String, dynamic>;
        tamsui['AirTemperature'] = '-99';
        final xinbei = _station(json, '新北')['WeatherElement'] as Map<String, dynamic>;
        xinbei['RelativeHumidity'] = '-99';
        xinbei['Weather'] = '-99';
        return null;
      });
      final r = await repo.getCurrentWeather(_at(25.17, 121.45, '新北市', '淡水區'));

      final w = r.data;
      expect(w.stationName, isNot('淡水'));
      expect(w.stationName, '新北');
      expect(w.temperature, 20.6);
      expect(w.humidity, isNull);
      expect(w.weather, isNull);
      expect(w.windSpeed, 1.0);
    });

    test('fails with dataset and location when every station lacks temperature', () async {
      adapter.serveFixture('O-A0003-001', (json) {
        for (final s in (json['records'] as Map)['Station'] as List) {
          ((s as Map)['WeatherElement'] as Map)['AirTemperature'] = '-99';
        }
        return null;
      });
      final r = await repo.getCurrentWeather(_at(25.17, 121.45, '新北市', '淡水區'));

      final f = r as Failure;
      expect(f.dataset, 'O-A0003-001');
      expect(f.location, '新北市淡水區');
    });

    test('HTTP 500 becomes a Failure carrying status, dataset and location', () async {
      adapter.serveStatus('O-A0003-001', 500);
      final r = await repo.getCurrentWeather(_at(25.17, 121.45, '新北市', '淡水區'));

      final f = r as Failure;
      expect(f.statusCode, 500);
      expect(f.dataset, 'O-A0003-001');
      expect(f.location, '新北市淡水區');
      expect(f.message, contains('O-A0003-001'));
    });
  });

  group('getHourlyForecast (3-day township dataset)', () {
    test('joins hourly and 3-hourly elements per 3-hour slot', () async {
      adapter.serveFixture('F-D0047-061');
      final r = await repo.getHourlyForecast('台北市', '中正區');

      expect(adapter.requests.single.path, endsWith('/F-D0047-061'));
      expect(adapter.requests.single.queryParameters['LocationName'], '中正區');
      final hours = r.data;
      expect(hours, hasLength(4));
      final first = hours.first;
      expect(first.startTime.toUtc(), DateTime.utc(2026, 11, 14, 10));
      expect(first.temperature, 24);
      expect(first.apparentTemperature, 27);
      expect(first.humidity, 96);
      expect(first.windSpeed, 2);
      expect(first.windDirection, '偏北風');
      expect(first.pop, 50);
      expect(first.weather, '短暫陣雨');
      expect(first.weatherCode, '08');
      expect(first.description, startsWith('短暫陣雨。降雨機率50%。'));
      expect(hours[1].temperature, 23);
      expect(hours[2].temperature, isNull, reason: 'fixture has no hourly temperature at 00:00');
      expect(hours[2].pop, 80);
      expect(hours[3].weatherCode, '04');
    });

    test('empty location list is a Failure naming dataset and location', () async {
      adapter.serveFixture('F-D0047-061', (json) {
        ((((json['records'] as Map)['Locations'] as List).first as Map))['Location'] = <Object?>[];
        return null;
      });
      final r = await repo.getHourlyForecast('臺北市', '中正區');

      final f = r as Failure;
      expect(f.dataset, 'F-D0047-061');
      expect(f.location, '臺北市中正區');
    });
  });

  group('getForecastIssueTime (file API head of the 3-day dataset)', () {
    test('reads DatasetInfo.IssueTime from the first bytes only', () async {
      adapter.routes['F-D0047-061'] = (206, File('test/fixtures/cwa/F-D0047-061-head.txt').readAsStringSync());
      final r = await repo.getForecastIssueTime('台北市');

      final request = adapter.requests.single;
      expect(request.path, '/fileapi/v1/opendataapi/F-D0047-061');
      expect(r.data, DateTime.parse('2026-11-14T17:00:00+08:00'));
    });

    test('a head without IssueTime is a Failure naming the dataset', () async {
      adapter.routes['F-D0047-061'] = (206, '{"cwaopendata": {"Sent": "2026-11-14T19:18:40+08:00"');
      final r = await repo.getForecastIssueTime('臺北市');

      final f = r as Failure;
      expect(f.dataset, 'F-D0047-061');
      expect(f.message, contains('IssueTime'));
    });
  });

  group('getWeeklyForecast (1-week township dataset)', () {
    test('computes real daily high and low over the Taiwan calendar day', () async {
      adapter.serveFixture('F-D0047-091', (json) {
        _weeklyValue(json, '最低溫度', 2)['MinTemperature'] = '19';
        return null;
      }, 'F-D0047-063');
      final r = await repo.getWeeklyForecast('臺北市', '臺北市');

      expect(adapter.requests.single.path, endsWith('/F-D0047-063'));
      final days = r.data;
      expect(days.map((d) => d.date), ['2026-11-14', '2026-11-15', '2026-11-16']);
      expect(days[0].maxTemperature, 24);
      expect(days[0].minTemperature, 21);
      // 11-15 spans slots 0,1,2 → max(24,24,22), min(21,21,19)
      expect(days[1].maxTemperature, 24);
      expect(days[1].minTemperature, 19);
      expect(days[1].maxApparentTemperature, 27);
      expect(days[1].minApparentTemperature, 22);
      // day fields come from the 06:00–18:00 slot
      expect(days[1].pop, 50);
      expect(days[1].humidity, 92);
      expect(days[1].windSpeed, 3);
      expect(days[1].weather, '陰短暫陣雨');
      expect(days[1].weatherCode, '11');
      expect(days[2].maxTemperature, 23);
      expect(days[2].minTemperature, 19);
      expect(days[2].pop, 30);
      expect(days[1].weekdayName, '週日');
    });

    test('-99 temperature is missing, never a fabricated number', () async {
      adapter.serveFixture('F-D0047-091', (json) {
        _weeklyValue(json, '最低溫度', 0)['MinTemperature'] = '-99';
        _weeklyValue(json, '最高溫度', 0)['MaxTemperature'] = '-99';
        return null;
      }, 'F-D0047-063');
      final r = await repo.getWeeklyForecast('臺北市', '臺北市');

      final today = r.data.first;
      expect(today.date, '2026-11-14');
      expect(today.minTemperature, isNull);
      expect(today.maxTemperature, isNull);
      expect(r.data[1].minTemperature, 21);
    });

    test('township absent from the response is a Failure listing what was returned', () async {
      adapter.serveFixture('F-D0047-091', null, 'F-D0047-063');
      final r = await repo.getWeeklyForecast('臺北市', '中正區');

      final f = r as Failure;
      expect(f.dataset, 'F-D0047-063');
      expect(f.message, contains('期望地點「中正區」'));
    });
  });

  group('getSunTimes (A-B0062-001)', () {
    // 2026-11-14 04:00Z = 臺灣 12:00
    final now = DateTime.utc(2026, 11, 14, 4);

    // 夾具只含 11-14、11-15（缺 11-13、11-16）：三日成功解析待真實金鑰重錄後補上
    test('queries yesterday through tomorrow with a 臺 county name', () async {
      adapter.serveFixture('A-B0062-001');
      await repo.getSunTimes('台北市', now);

      final q = adapter.requests.single.queryParameters;
      expect(q['CountyName'], '臺北市');
      expect(q['timeFrom'], '2026-11-13');
      expect(q['timeTo'], '2026-11-16');
    });

    test('uses the Taiwan calendar day of now (UTC evening is already tomorrow)', () async {
      adapter.serveFixture('A-B0062-001');
      await repo.getSunTimes('臺北市', DateTime.utc(2026, 11, 14, 17));

      final q = adapter.requests.single.queryParameters;
      expect(q['timeFrom'], '2026-11-14');
      expect(q['timeTo'], '2026-11-17');
    });

    test('missing day is a Failure naming dataset, county, the date and dates returned', () async {
      adapter.serveFixture('A-B0062-001');
      final r = await repo.getSunTimes('臺北市', now);

      final f = r as Failure;
      expect(f.dataset, 'A-B0062-001');
      expect(f.location, '臺北市');
      expect(f.message, contains('2026-11-13'));
      expect(f.message, contains('2026-11-14'));
    });

    test('unknown transit altitude format is a Failure, not a guess', () async {
      adapter.serveFixture('A-B0062-001', (json) {
        final loc = ((json['records'] as Map)['locations'] as Map)['location'] as List;
        (((loc.first as Map)['time'] as List).first as Map)['SunTransitAlt'] = '47E';
        return null;
      });
      final r = await repo.getSunTimes('臺北市', DateTime.utc(2026, 11, 15, 4));

      final f = r as Failure;
      expect(f.dataset, 'A-B0062-001');
      expect(f.message, contains('SunTransitAlt'));
    });
  });
}
