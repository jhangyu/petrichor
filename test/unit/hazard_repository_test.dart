import 'dart:convert';
import 'dart:io';

import 'package:petrichor/core/api/api_key.dart';
import 'package:petrichor/core/api/dio_client.dart';
import 'package:petrichor/data/models/hazard_models.dart';
import 'package:petrichor/data/repositories/hazard_repository.dart';
import 'package:petrichor/core/api/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_cwa_adapter.dart';

String _fixture(String id) => File('test/fixtures/cwa/$id.json').readAsStringSync();

Map<String, dynamic> _fixtureJson(String id) => jsonDecode(_fixture(id)) as Map<String, dynamic>;

(int, String) _ok(Object body) => (200, body is String ? body : jsonEncode(body));

List<CountyWarning> _warningsOf(ActiveWarnings w, String county) =>
    w.counties.where((c) => c.county == county).firstOrNull?.warnings ?? const [];

final _fixedNow = DateTime.utc(2026, 11, 14, 12);

HazardRepository _repo(Map<String, (int, String)> routes, {DateTime Function()? clock}) {
  final adapter = FakeCwaAdapter()..routes.addAll(routes);
  return HazardRepository(adapter.dio(), clock: clock ?? () => _fixedNow);
}

DateTime _tw(String s) => DateTime.parse('$s+08:00');

/// 完整尺寸（441×561）的 1 小時預報 fixture：全部 -99，[cells] 指定的 index 設為指定值
String _fullGrid(Map<int, String> cells) {
  final root = _fixtureJson('F-B0046-001');
  final ps = root['cwaopendata']['dataset']['datasetInfo']['parameterSet'] as Map<String, dynamic>;
  final n = int.parse(ps['GridDimensionX'] as String) * int.parse(ps['GridDimensionY'] as String);
  root['cwaopendata']['dataset']['contents']['content'] = List.generate(n, (i) => cells[i] ?? '-9.900E+01').join(',');
  return jsonEncode(root);
}

void main() {
  group('getActiveWarnings', () {
    test('joins county warnings with bulletins by county and valid period', () async {
      final repo = _repo({
        'W-C0033-001': _ok(_fixture('W-C0033-001')),
        'W-C0033-002': _ok(_fixture('W-C0033-002')),
      });
      final w = (await repo.getActiveWarnings()).data;

      expect(w.counties.length, 11);
      expect(w.bulletins.length, 2);

      final pingtung = _warningsOf(w, '屏東縣');
      expect(pingtung.map((e) => e.phenomena), ['豪雨', '陸上強風']);
      final heavyRain = pingtung.first;
      expect(heavyRain.start, _tw('2026-11-14T18:57:00'));
      expect(heavyRain.end, _tw('2026-11-15T01:00:00'));
      // -001 標「豪雨」、-002 對屏東標「大雨」：靠縣市＋有效期間配對
      expect(heavyRain.bulletin!.title, '豪雨特報');
      expect(heavyRain.bulletin!.issueTime, _tw('2026-11-14T18:55:00'));
      expect(heavyRain.bulletin!.description.startsWith('鋒面通過'), isTrue);
      expect(heavyRain.bulletin!.description, equals(heavyRain.bulletin!.description.trim()));
      expect(heavyRain.bulletin!.affectedAreas, containsAll(['高雄市', '屏東縣']));

      expect(_warningsOf(w, '澎湖縣').single.bulletin!.title, '陸上強風特報');
      expect(_warningsOf(w, '臺北市'), isEmpty);
    });

    test('updatedAt is the newest bulletin update, fetchedAt comes from the injected clock', () async {
      final fetched = _tw('2026-11-14T22:50:00');
      final repo = _repo({
        'W-C0033-001': _ok(_fixture('W-C0033-001')),
        'W-C0033-002': _ok(_fixture('W-C0033-002')),
      }, clock: () => fetched);
      final w = (await repo.getActiveWarnings()).data;
      expect(w.fetchedAt, fetched);
      expect(w.updatedAt, _tw('2026-11-14T18:59:50'));
    });

    test('no active warnings is Success with empty counties', () async {
      final w1 = _fixtureJson('W-C0033-001');
      for (final loc in (w1['records']['location'] as List)) {
        loc['hazardConditions']['hazards'] = [];
      }
      final repo = _repo({
        'W-C0033-001': _ok(w1),
        'W-C0033-002': _ok({'success': 'true', 'records': <String, dynamic>{}}),
      });
      final r = await repo.getActiveWarnings();
      expect(r, isA<Success<ActiveWarnings>>());
      expect(r.data.counties, isEmpty);
      expect(r.data.bulletins, isEmpty);
      expect(r.data.updatedAt, isNull);
    });

    test('active warnings without any bulletin is Failure naming -002', () async {
      final repo = _repo({
        'W-C0033-001': _ok(_fixture('W-C0033-001')),
        'W-C0033-002': _ok({'success': 'true', 'records': <String, dynamic>{}}),
      });
      final r = await repo.getActiveWarnings();
      expect(r, isA<Failure<ActiveWarnings>>());
      expect((r as Failure).message, contains('W-C0033-002'));
    });

    test('lifted bulletin without hazardConditions is skipped, active ones still join', () async {
      final w2 = _fixtureJson('W-C0033-002');
      final lifted = jsonDecode(_fixture('W-C0033-002-lifted-record'));
      (w2['records']['record'] as List).insert(0, lifted);
      final repo = _repo({
        'W-C0033-001': _ok(_fixture('W-C0033-001')),
        'W-C0033-002': _ok(w2),
      });
      final r = await repo.getActiveWarnings();
      expect(r, isA<Success<ActiveWarnings>>());
      expect(r.data.bulletins.length, 2);
      expect(r.data.bulletins.any((b) => b.description.contains('解除')), isFalse);
      expect(_warningsOf(r.data, '澎湖縣').single.bulletin!.title, '陸上強風特報');
    });

    test('-001 without records.location is Failure, not empty', () async {
      final repo = _repo({
        'W-C0033-001': _ok({'success': 'true', 'records': <String, dynamic>{}}),
        'W-C0033-002': _ok(_fixture('W-C0033-002')),
      });
      final r = await repo.getActiveWarnings();
      expect(r, isA<Failure<ActiveWarnings>>());
      expect((r as Failure).message, allOf(contains('W-C0033-001'), contains('records.location')));
    });
  });

  group('getRainfall', () {
    final routes = {'O-A0002-001': _ok(_fixture('O-A0002-001'))};

    test('returns county stations and nearest station today accumulated', () async {
      final r = (await _repo(routes).getRainfall(county: '基隆市', latitude: 25.13, longitude: 121.74)).data;
      expect(r.nearest.name, '基隆');
      expect(r.nearest.todayMm, 3.0);
      expect(r.stations.length, 1);

      final nantou = (await _repo(routes).getRainfall(county: '南投縣', latitude: 23.9, longitude: 120.9)).data;
      expect(nantou.nearest.name, '九份二山');
      expect(nantou.nearest.todayMm, 27.5);
    });

    test('unknown county (e.g. 台 instead of 臺) is Failure with context', () async {
      final r = await _repo(routes).getRainfall(county: '台北市', latitude: 25.0, longitude: 121.5);
      expect(r, isA<Failure<CountyRainfall>>());
      expect((r as Failure).message, allOf(contains('O-A0002-001'), contains('台北市')));
    });

    test('-99 station value is null and skipped for nearest', () async {
      final body = _fixtureJson('O-A0002-001');
      final stations = body['records']['Station'] as List;
      // 讓「基隆」缺值，同縣市加一個有值測站
      final extra = jsonDecode(jsonEncode(stations[1])) as Map<String, dynamic>;
      extra['StationName'] = '遠站';
      extra['GeoInfo']['Coordinates'][1]['StationLatitude'] = '25.5';
      extra['RainfallElement']['Now']['Precipitation'] = '8.0';
      stations[1]['RainfallElement']['Now']['Precipitation'] = '-99';
      stations.add(extra);
      final repo = _repo({'O-A0002-001': _ok(body)});
      final r = (await repo.getRainfall(county: '基隆市', latitude: 25.13, longitude: 121.74)).data;
      expect(r.stations.firstWhere((s) => s.name == '基隆').todayMm, isNull);
      expect(r.nearest.name, '遠站');
    });

    test('non-numeric station value (e.g. T) becomes null without failing the dataset', () async {
      final body = _fixtureJson('O-A0002-001');
      final element = body['records']['Station'][0]['RainfallElement'] as Map<String, dynamic>;
      element['Past1hr']['Precipitation'] = 'T';
      element['Past3hr']['Precipitation'] = 'abc';
      final r = (await _repo({'O-A0002-001': _ok(body)}).getRainfall(county: '南投縣', latitude: 23.9, longitude: 120.9)).data;
      final station = r.stations.single;
      expect(station.todayMm, 27.5);
      expect(station.past1hrMm, isNull);
      expect(station.past3hrMm, isNull);
      expect(r.allStations.length, 3);
    });

    test('wrong structure (Precipitation not a string) is still Failure', () async {
      final body = _fixtureJson('O-A0002-001');
      body['records']['Station'][0]['RainfallElement']['Past1hr']['Precipitation'] = 1.5;
      final r = await _repo({'O-A0002-001': _ok(body)}).getRainfall(county: '南投縣', latitude: 23.9, longitude: 120.9);
      expect((r as Failure).message, allOf(contains('O-A0002-001'), contains('Past1hr')));
    });
  });

  group('getRainForecast', () {
    // 25.0375N,121.5E → y=(25.0375-20)/0.0125=403, x=(121.5-118)/0.0125=280（手算）
    const cell = 403 * 441 + 280;

    test('value at coordinate comes from hand-computed grid index', () async {
      final repo = _repo({'F-B0046-001': _ok(_fullGrid({cell: '1.250E+01'}))});
      final f = (await repo.getRainForecast(latitude: 25.0375, longitude: 121.5)).data;
      expect(f.mmAtLocation, 12.5);
      expect(f.grid.baseTime, _tw('2026-11-14T20:30:00'));
      expect(f.grid.issuedAt, _tw('2026-11-14T20:45:09'));
      expect(f.grid.columns, 441);
      expect(f.grid.rows, 561);
      expect(f.grid.resolution, 0.0125);
      expect([f.grid.startLongitude, f.grid.startLatitude], [118.0, 20.0]);
      // 相鄰格不受影響
      final neighbour = (await repo.getRainForecast(latitude: 25.0375, longitude: 121.5125)).data;
      expect(neighbour.mmAtLocation, isNull);
    });

    test('-99 cell is null, not zero', () async {
      final repo = _repo({'F-B0046-001': _ok(_fullGrid({}))});
      expect((await repo.getRainForecast(latitude: 25.0, longitude: 121.5)).data.mmAtLocation, isNull);
    });

    test('coordinate outside grid is Failure', () async {
      final repo = _repo({'F-B0046-001': _ok(_fullGrid({}))});
      final r = await repo.getRainForecast(latitude: 30.0, longitude: 121.5);
      expect((r as Failure).message, allOf(contains('F-B0046-001'), contains('30.0')));
    });

    test('truncated fixture (200 of 247401 values) is Failure', () async {
      final r = await _repo({'F-B0046-001': _ok(_fixture('F-B0046-001'))}).getRainForecast(latitude: 25.0, longitude: 121.5);
      expect((r as Failure).message, allOf(contains('F-B0046-001'), contains('247401')));
    });
  });

  group('fileapi key', () {
    test('url carries no key and the interceptor adds it as a query parameter', () async {
      const dummyKey = 'CWA-00000000-0000-0000-0000-000000000000';
      SharedPreferences.setMockInitialValues({CwaApiKeyNotifier.storageKey: dummyKey});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = FakeCwaAdapter()..routes['F-B0046-001'] = _ok(_fullGrid({}));
      container.read(dioProvider).httpClientAdapter = adapter;

      final r = await container.read(hazardRepositoryProvider).getRainForecast(latitude: 25.0, longitude: 121.5);

      expect(r, isA<Success<RainForecast>>());
      final uri = adapter.requests.single;
      expect(uri.path, endsWith('/fileapi/v1/opendataapi/F-B0046-001'));
      expect(uri.queryParameters['Authorization'], dummyKey);
      expect(uri.queryParameters['downloadType'], 'WEB');
      // CWA answers 404 when a query parameter appears twice
      for (final name in ['format', 'downloadType', 'Authorization']) {
        expect(RegExp('(^|&)$name=').allMatches(uri.query), hasLength(1), reason: uri.query.replaceAll(dummyKey, '<key>'));
      }
    });
  });
}
