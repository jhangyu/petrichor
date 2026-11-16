import 'package:petrichor/core/geography/earth.dart';
import 'package:petrichor/data/radar/radar_bounds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('station bounds are site ± 150 km', () {
    final shulin = radarStations.firstWhere((s) => s.code == 'RCSL'); // 樹林 121.40E 25.00N
    final b = stationRadarBounds(shulin.site, radiusKm: radarStationRangeKm);
    const dLat = 150 / earthRadiusKilometers * 57.29577951308232;
    expect(b.south, closeTo(25.0 - dLat, 1e-9));
    expect(b.north, closeTo(25.0 + dLat, 1e-9));
    expect(b.east - b.west, closeTo(2 * dLat / 0.9063077870366499, 1e-9)); // cos 25°
    expect((b.east + b.west) / 2, closeTo(121.40, 1e-9));
  });
}
