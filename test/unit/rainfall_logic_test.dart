import 'package:cwb_flutter/core/theme/app_tokens.dart';
import 'package:cwb_flutter/data/models/hazard_models.dart';
import 'package:cwb_flutter/features/hazard/rainfall/rainfall_logic.dart';
import 'package:flutter_test/flutter_test.dart';

RainStation _station(String name, double? mm) => RainStation(
      id: name,
      name: name,
      county: '臺北市',
      town: '信義區',
      latitude: 25,
      longitude: 121.5,
      todayMm: mm,
      obsTime: DateTime.utc(2026, 11, 14, 6),
    );

void main() {
  test('levels switch exactly at the thresholds', () {
    expect([79.9, 80.0, 200.0, 350.0, 500.0].map(rainLevel), [0, 1, 2, 3, 4]);
  });

  test('marker follows the mockup (86.5 mm → 17.3 %) and clamps at the ends', () {
    expect(thresholdMarkerFraction(86.5), closeTo(0.173, 1e-9));
    expect(thresholdMarkerFraction(0), 0);
    expect(thresholdMarkerFraction(900), closeTo(1, 1e-9));
  });

  test('next warning is the next level up, none at the top', () {
    final next = nextWarning(86.5)!;
    expect(next.name, '豪雨');
    expect(next.remainingMm, closeTo(113.5, 1e-9));
    expect(nextWarning(500), isNull);
  });

  test('station sort: rainfall high to low with missing last, or by name', () {
    final list = [_station('b', 10), _station('a', null), _station('c', 50)];
    expect(sortStations(list, StationSort.rainfall).map((s) => s.name), ['c', 'b', 'a']);
    expect(sortStations(list, StationSort.name).map((s) => s.name), ['a', 'b', 'c']);
  });

  test('map legend has one label per colour', () {
    expect(rainfallMapScaleLabels.length, AppPalette.rainfallMapScale.length);
  });

  test('county chips start with the current county, then the others once', () {
    RainStation inCounty(String county) => RainStation(
          id: county,
          name: county,
          county: county,
          town: 't',
          latitude: 25,
          longitude: 121.5,
          todayMm: 1,
          obsTime: DateTime.utc(2026, 11, 14),
        );
    final stations = [inCounty('基隆市'), inCounty('臺北市'), inCounty('基隆市'), inCounty('宜蘭縣')];
    expect(countyChipOrder(stations, '臺北市'), ['臺北市', '基隆市', '宜蘭縣']);
  });

  test('forecast buckets blank out missing and under 1 mm', () {
    final grid = RainForecastGrid(
      baseTime: DateTime.utc(2026, 11, 14, 6),
      issuedAt: DateTime.utc(2026, 11, 14, 6, 15),
      startLongitude: 120,
      startLatitude: 22,
      resolution: 0.0125,
      columns: 4,
      rows: 2,
      values: [null, 0.9, 1.0, 5.0, 9.9, 10.0, 20.0, 80.0],
    );
    expect(forecastBuckets(grid), [0, 0, 1, 2, 2, 3, 4, 4]);
  });
}
