import 'dart:math' as math;

const _degreesPerRadian = 180 / math.pi;
const _minutesPerDegreeOfHourAngle = 4;
const _hoursPerDay = 24;

/// Below this geometric elevation the Sæmundsson refraction formula diverges;
/// refraction is taken as 0 there.
const _refractionFloorDegrees = -1.0;

double _radians(double degrees) => degrees / _degreesPerRadian;

bool _isLeapYear(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

/// Apparent solar elevation in degrees at [instant] for the point
/// ([latitude], [longitude]) (north and east positive). NOAA general solar
/// position equations plus Sæmundsson refraction above −1°.
/// Negative below the horizon.
///
/// Source: NOAA GML "General Solar Position Calculations"
/// (https://gml.noaa.gov/grad/solcalc/solareqns.PDF), Fourier series after
/// Spencer (1971). Geometric error ≤ ~0.2°.
double solarElevationDegrees({required double latitude, required double longitude, required DateTime instant}) {
  final t = instant.toUtc();
  final daysInYear = _isLeapYear(t.year) ? 366 : 365;
  final dayOfYear = t.difference(DateTime.utc(t.year)).inDays + 1;
  final minutesOfDay = t.hour * 60 + t.minute + t.second / 60;
  final hour = minutesOfDay / 60;

  // Fractional year γ (rad).
  final dayAngle = 2 * math.pi / daysInYear * (dayOfYear - 1 + (hour - 12) / _hoursPerDay);

  final equationOfTimeMinutes = 229.18 *
      (0.000075 +
          0.001868 * math.cos(dayAngle) -
          0.032077 * math.sin(dayAngle) -
          0.014615 * math.cos(2 * dayAngle) -
          0.040849 * math.sin(2 * dayAngle));

  final declination = 0.006918 -
      0.399912 * math.cos(dayAngle) +
      0.070257 * math.sin(dayAngle) -
      0.006758 * math.cos(2 * dayAngle) +
      0.000907 * math.sin(2 * dayAngle) -
      0.002697 * math.cos(3 * dayAngle) +
      0.00148 * math.sin(3 * dayAngle);

  final trueSolarMinutes = minutesOfDay + equationOfTimeMinutes + _minutesPerDegreeOfHourAngle * longitude;
  final hourAngle = _radians(trueSolarMinutes / _minutesPerDegreeOfHourAngle - 180);

  final phi = _radians(latitude);
  // Clamp: float rounding can push the value just past ±1; mathematically it is in range.
  final cosZenith = (math.sin(phi) * math.sin(declination) + math.cos(phi) * math.cos(declination) * math.cos(hourAngle))
      .clamp(-1.0, 1.0);
  final geometric = 90 - math.acos(cosZenith) * _degreesPerRadian;

  if (geometric <= _refractionFloorDegrees) return geometric;
  final refractionArcMinutes = 1.02 / math.tan(_radians(geometric + 10.3 / (geometric + 5.11)));
  return geometric + refractionArcMinutes / 60;
}
