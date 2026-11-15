import 'package:petrichor/features/weather/solar_elevation.dart';
import 'package:flutter_test/flutter_test.dart';

/// 臺北市 (Taipei City Hall area).
const _lat = 25.0375;
const _lon = 121.5637;

/// Taiwan wall time as an instant.
DateTime tw(int month, int day, int hour, int minute) => DateTime.utc(2026, month, day, hour - 8, minute);

double elevation(DateTime t) => solarElevationDegrees(latitude: _lat, longitude: _lon, instant: t);

void main() {
  // CWA A-B0062-001 臺北市 2026-11-14 (test/fixtures/cwa/A-B0062-001.json):
  // transit 11:38 at 47S, sunrise 06:10, sunset 17:07.
  test('matches the CWA noon altitude for Taipei', () {
    expect(elevation(tw(11, 14, 11, 38)), closeTo(47, 0.5));
  });

  test('is at the apparent horizon at the CWA sunrise and sunset minutes', () {
    expect(elevation(tw(11, 14, 6, 10)).abs(), lessThan(0.5));
    expect(elevation(tw(11, 14, 17, 7)).abs(), lessThan(0.5));
  });

  test('summer solstice noon matches 90 − |latitude − 23.44|', () {
    // Apparent noon in Taipei on 2026-06-21 ≈ 11:55 Taiwan time.
    expect(elevation(tw(6, 21, 11, 55)), closeTo(90 - (_lat - 23.44).abs(), 0.3));
  });
}
