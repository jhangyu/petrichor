import 'package:cwb_flutter/core/constants/app_constants.dart';
import 'package:cwb_flutter/data/models/place.dart';
import 'package:cwb_flutter/data/repositories/weather_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_cwa_adapter.dart';

/// 22 縣市各借用臺北市樣本（單一鄉鎮），只改縣市名與座標；座標 [coords] 以縣市名索引。
FakeCwaAdapter _serveAllCounties(Map<String, (String, double, double)> townByCounty) {
  final adapter = FakeCwaAdapter();
  for (final entry in AppConstants.townshipForecastDatasets.entries) {
    final (town, lat, lon) = townByCounty[entry.key] ?? ('某區', 0.0, 0.0);
    adapter.serveFixture('F-D0047-061', (json) {
      final group = ((json['records'] as Map)['Locations'] as List).first as Map;
      group['LocationsName'] = entry.key;
      final loc = (group['Location'] as List).first as Map;
      loc['LocationName'] = town;
      loc['Latitude'] = '$lat';
      loc['Longitude'] = '$lon';
      return null;
    }, entry.value.threeDay);
  }
  return adapter;
}

void main() {
  const towns = {
    '臺北市': ('中正區', 25.046, 121.516),
    '澎湖縣': ('馬公市', 23.566, 119.566),
    '花蓮縣': ('花蓮市', 23.977, 121.604),
  };

  test('nearestTown returns the county and town closest to the coordinates, fetching the list once', () async {
    final adapter = _serveAllCounties(towns);
    final repo = WeatherRepository(adapter.dio());

    final taipei = (await repo.nearestTown(25.04, 121.52)).data;
    final penghu = (await repo.nearestTown(23.57, 119.57)).data;

    expect((taipei.county, taipei.town), ('臺北市', '中正區'));
    expect((penghu.county, penghu.town), ('澎湖縣', '馬公市'));
    expect(adapter.requests.length, AppConstants.townshipForecastDatasets.length);
  });

  test('nearestTown fails naming the county when any county list cannot be fetched', () async {
    final adapter = _serveAllCounties(towns);
    adapter.serveStatus('F-D0047-041', 500);
    final repo = WeatherRepository(adapter.dio());

    final r = await repo.nearestTown(25.04, 121.52);

    final failure = r as Failure<Place>;
    expect(failure.location, '花蓮縣');
    expect(failure.message, contains('花蓮縣'));
  });
}
