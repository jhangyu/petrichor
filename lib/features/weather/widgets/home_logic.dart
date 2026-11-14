import '../../../data/models/weather_models.dart';

/// CWA data and the mockup use Taiwan time (UTC+8, no DST).
const _taiwanUtcOffset = Duration(hours: 8);

/// Below this 降雨機率 the value is shown muted (`.day__rain--low`, `.fc-t--pop-low`).
const rainLowThresholdPercent = 30;

const _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

/// Taiwan wall-clock fields of [t], carried in a UTC DateTime.
DateTime taiwanWall(DateTime t) => t.toUtc().add(_taiwanUtcOffset);

/// Instant of a Taiwan wall-clock time carried in a UTC DateTime (inverse of [taiwanWall]).
DateTime fromTaiwanWall(DateTime wall) => wall.subtract(_taiwanUtcOffset);

/// CWA calendar date `2026-11-14` → its wall-clock midnight (UTC carrier).
DateTime taiwanDate(String date) => DateTime.parse('${date}T00:00:00Z');

String _two(int v) => v.toString().padLeft(2, '0');

/// `14:00`
String clockText(DateTime t) {
  final w = taiwanWall(t);
  return '${_two(w.hour)}:${_two(w.minute)}';
}

/// `11/14（六）` for a wall date (see [taiwanWall] / [taiwanDate]).
String monthDayWeekday(DateTime wall) => '${monthDay(wall)}（${_weekdayNames[wall.weekday - 1]}）';

/// `11/14` for a wall date.
String monthDay(DateTime wall) => '${wall.month}/${wall.day}';

/// `週六` for a wall date.
String weekdayName(DateTime wall) => '週${_weekdayNames[wall.weekday - 1]}';

/// Calendar days from [now]'s Taiwan date to [wall]'s date (0 = today).
int dayOffset(DateTime wall, DateTime now) {
  final today = taiwanWall(now);
  final a = DateTime.utc(wall.year, wall.month, wall.day);
  final b = DateTime.utc(today.year, today.month, today.day);
  return a.difference(b).inDays;
}

/// 今天／明天／後天, otherwise the weekday (`週二`).
String relativeDay(DateTime wall, DateTime now) => switch (dayOffset(wall, now)) {
  0 => '今天',
  1 => '明天',
  2 => '後天',
  _ => weekdayName(wall),
};

/// `10 小時 57 分`, or `7 分` under one hour.
String durationText(Duration d) {
  final minutes = d.inMinutes;
  final h = minutes ~/ Duration.minutesPerHour;
  final m = minutes % Duration.minutesPerHour;
  return h == 0 ? '$m 分' : '$h 小時 $m 分';
}

/// Rounded temperature `28°`, or 「—」 when the value is missing.
String tempText(double? t) => t == null ? '—' : '${t.round()}°';

/// `20%`, or 「—」 when missing.
String percentText(int? p) => p == null ? '—' : '$p%';

/// `3 m/s` / `3.2 m/s` (no trailing `.0`), or 「—」 when missing.
String speedText(double? v) {
  if (v == null) return '—';
  final text = v == v.roundToDouble() ? v.round().toString() : v.toString();
  return '$text m/s';
}

/// CWA 風向 `偏北風` / `東北風` → `偏北` / `東北` (chart label).
String windDirectionLabel(String? direction) {
  if (direction == null) return '—';
  return direction.endsWith('風') ? direction.substring(0, direction.length - 1) : direction;
}

// ---------------------------------------------------------------------------
// Weather phenomenon → icon bucket

enum WeatherGlyph { sun, partly, cloud, rain, thunder, fog, snow, unknown }

/// Buckets a CWA 天氣現象 text (forecast Wx or observation Weather) into an icon.
/// Precipitation wins over sky cover (「多雲短暫雨」 → rain).
WeatherGlyph weatherGlyph(String? text) {
  if (text == null) return WeatherGlyph.unknown;
  bool has(String s) => text.contains(s);
  if (has('雷')) return WeatherGlyph.thunder;
  if (has('雪')) return WeatherGlyph.snow;
  if (has('雨')) return WeatherGlyph.rain;
  if (has('霧') || has('霾') || has('靄')) return WeatherGlyph.fog;
  final cloudy = has('雲') || has('陰');
  if (has('晴')) return cloudy ? WeatherGlyph.partly : WeatherGlyph.sun;
  if (cloudy) return WeatherGlyph.cloud;
  return WeatherGlyph.unknown;
}

// ---------------------------------------------------------------------------
// Sunrise / sunset

enum SunPhase { beforeSunrise, daytime, afterSunset }

/// Where [now] sits in [day]: phase, share of daylight elapsed (0–1) and
/// the time to the next sunrise/sunset event of that day.
class SunPosition {
  const SunPosition({required this.phase, required this.dayFraction, required this.untilEvent});

  final SunPhase phase;
  final double dayFraction;

  /// Before sunrise: to sunrise; daytime: to sunset; after sunset: zero.
  final Duration untilEvent;
}

SunPosition sunPosition(SunDay day, DateTime now) {
  if (now.isBefore(day.sunrise)) {
    return SunPosition(phase: SunPhase.beforeSunrise, dayFraction: 0, untilEvent: day.sunrise.difference(now));
  }
  if (!now.isBefore(day.sunset)) {
    return const SunPosition(phase: SunPhase.afterSunset, dayFraction: 1, untilEvent: Duration.zero);
  }
  final daylight = day.sunset.difference(day.sunrise).inSeconds;
  return SunPosition(
    phase: SunPhase.daytime,
    dayFraction: now.difference(day.sunrise).inSeconds / daylight,
    untilEvent: day.sunset.difference(now),
  );
}

/// `現在 14:00 · 距日落 3 小時 7 分`; after sunset counts to [tomorrow]'s sunrise.
String sunNowLine(SunDay today, SunDay? tomorrow, DateTime now) {
  final head = '現在 ${clockText(now)}';
  final pos = sunPosition(today, now);
  return switch (pos.phase) {
    SunPhase.beforeSunrise => '$head · 距日出 ${durationText(pos.untilEvent)}',
    SunPhase.daytime => '$head · 距日落 ${durationText(pos.untilEvent)}',
    SunPhase.afterSunset when tomorrow != null => '$head · 已日落，距明天日出 ${durationText(tomorrow.sunrise.difference(now))}',
    SunPhase.afterSunset => '$head · 已日落',
  };
}

// ---------------------------------------------------------------------------
// 72-hour summary

/// Length of one F-D0047-061 天氣現象／降雨機率 slot.
const forecastSlotLength = Duration(hours: 3);

/// The forecast slot covering [now], or null when none does.
HourlyForecast? currentSlot(List<HourlyForecast> slots, DateTime now) {
  for (final s in slots) {
    if (!now.isBefore(s.startTime) && now.isBefore(s.startTime.add(forecastSlotLength))) return s;
  }
  return null;
}

/// 72 小時 extremes; each is null when no slot has that value.
class ForecastExtremes {
  const ForecastExtremes({required this.hottest, required this.coldest, required this.wettest});

  final HourlyForecast? hottest;
  final HourlyForecast? coldest;
  final HourlyForecast? wettest;
}

/// Highest / lowest temperature and highest 降雨機率 slot (earliest on ties).
ForecastExtremes forecastExtremes(List<HourlyForecast> slots) {
  HourlyForecast? hottest, coldest, wettest;
  for (final s in slots) {
    final t = s.temperature;
    if (t != null) {
      if (hottest == null || t > hottest.temperature!) hottest = s;
      if (coldest == null || t < coldest.temperature!) coldest = s;
    }
    final p = s.pop;
    if (p != null && (wettest == null || p > wettest.pop!)) wettest = s;
  }
  return ForecastExtremes(hottest: hottest, coldest: coldest, wettest: wettest);
}

// ---------------------------------------------------------------------------
// 7-day temperature axis

/// Shared temperature axis for the 7-day range bars (`.temp-range`).
class TempScale {
  const TempScale(this.min, this.max);

  final double min;
  final double max;

  /// Position of [t] on the axis, 0 (min) – 1 (max).
  double fraction(double t) => max == min ? 0.5 : ((t - min) / (max - min)).clamp(0.0, 1.0);
}

/// Axis spanning every day's low/high and [current]; null when no value exists.
TempScale? weeklyScale(List<DailyForecast> days, double? current) {
  final values = [
    for (final d in days) ...[d.minTemperature, d.maxTemperature],
    current,
  ].whereType<double>();
  if (values.isEmpty) return null;
  return TempScale(
    values.reduce((a, b) => a < b ? a : b).floorToDouble(),
    values.reduce((a, b) => a > b ? a : b).ceilToDouble(),
  );
}
