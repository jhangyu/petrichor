import 'package:petrichor/core/constants/app_constants.dart';
import 'package:petrichor/data/models/place.dart';
import 'package:petrichor/core/api/result.dart';
import 'package:petrichor/data/repositories/weather_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_cwa_adapter.dart';

/// 測站清單用 O-A0001-001 樣本（臺北、三重〔新北市〕、澎湖、新興〔高雄市〕、臺中）；
/// 各縣市鄉鎮清單借臺北市 3 天預報樣本，只留一個鄉鎮並改縣市名、鄉鎮名與座標。
FakeCwaAdapter _serve(Map<String, (String, double, double)> townByCounty) {
  final adapter = FakeCwaAdapter()..serveFixture(AppConstants.countyLookupDataset);
  for (final MapEntry(key: county, value: (town, lat, lon)) in townByCounty.entries) {
    adapter.serveFixture('F-D0047-061', (json) {
      final group = ((json['records'] as Map)['Locations'] as List).first as Map;
      group['LocationsName'] = county;
      final loc = (group['Location'] as List).first as Map;
      loc['LocationName'] = town;
      loc['Latitude'] = '$lat';
      loc['Longitude'] = '$lon';
      return null;
    }, AppConstants.townshipForecastDatasets[county]!.threeDay);
  }
  return adapter;
}

List<String> _datasets(FakeCwaAdapter adapter) => [for (final r in adapter.requests) r.pathSegments.last];

void main() {
  test('county from the nearest station, then only that county list (far from any other county)', () async {
    final adapter = _serve({'澎湖縣': ('馬公市', 23.566, 119.566)});

    final r = await WeatherRepository(adapter.createDio()).nearestTown(23.57, 119.57);

    expect((r.data.county, r.data.town), ('澎湖縣', '馬公市'));
    expect(_datasets(adapter), ['O-A0001-001', 'F-D0047-045']);
    expect(adapter.requests.first.queryParameters['GeoInfo'], 'Coordinates,CountyName');
  });

  test('another county station farther than the nearest town plus slack is not fetched', () async {
    // 中正區 ≈ 0.9 km, 三重 station (新北市) ≈ 2.2 km > 0.9 + 1
    final adapter = _serve({'臺北市': ('中正區', 25.046058, 121.516565)});

    final r = await WeatherRepository(adapter.createDio()).nearestTown(25.04, 121.51);

    expect((r.data.county, r.data.town), ('臺北市', '中正區'));
    expect(_datasets(adapter), ['O-A0001-001', 'F-D0047-061']);
  });

  test('border: a nearer other-county station also fetches that county and picks the nearer town', () async {
    // 士林區 ≈ 5.6 km; 三重 station (新北市) ≈ 2.2 km ≤ 5.6 + 1 → 新北市 list, 板橋區 ≈ 1.5 km wins
    final adapter = _serve({
      '臺北市': ('士林區', 25.09, 121.52),
      '新北市': ('板橋區', 25.03, 121.50),
    });

    final r = await WeatherRepository(adapter.createDio()).nearestTown(25.04, 121.51);

    expect((r.data.county, r.data.town), ('新北市', '板橋區'));
    expect(_datasets(adapter), ['O-A0001-001', 'F-D0047-061', 'F-D0047-069']);
  });

  test('a county list failure names the county and dataset', () async {
    final adapter = _serve({})..serveStatus('F-D0047-061', 500);

    final failure = await WeatherRepository(adapter.createDio()).nearestTown(25.04, 121.51) as Failure<Place>;

    expect(failure.location, '臺北市');
    expect(failure.dataset, 'F-D0047-061');
    expect(failure.message, contains('伺服器回應錯誤：500'));
  });

  test('a station list failure names the station dataset and coordinates', () async {
    final adapter = FakeCwaAdapter()..serveStatus(AppConstants.countyLookupDataset, 500);

    final failure = await WeatherRepository(adapter.createDio()).nearestTown(25.04, 121.51) as Failure<Place>;

    expect(failure.dataset, 'O-A0001-001');
    expect(failure.location, '(25.04, 121.51)');
    expect(adapter.requests, hasLength(1));
  });
}
