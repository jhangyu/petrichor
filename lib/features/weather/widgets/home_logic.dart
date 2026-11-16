import '../../../data/models/place.dart';
import '../../../data/models/weather_models.dart';
import '../../../core/api/result.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/time/taiwan_time.dart';
import '../solar_elevation.dart';
import '../weather_provider.dart';

/// Below this 降雨機率 the value is shown muted (`.day__rain--low`, `.fc-t--pop-low`).
const rainLowThresholdPercent = 30;

/// Whether a 降雨機率 is shown muted; unknown (null) counts as low.
bool isLowRain(int? pop) => pop == null || pop < rainLowThresholdPercent;

/// The first API-key failure among the page's datasets (they share one CWA token).
ApiKeyIssue? firstApiKeyIssue(List<Result<Object?>?> results) {
  for (final result in results) {
    if (result case Failure(apiKeyIssue: final issue?)) return issue;
  }
  return null;
}

/// Dataset ids credited under the home page: only datasets whose data is on screen; none while loading.
List<String> creditedDatasets(WeatherState weather, String county, Result<Object?>? warnings) {
  if (weather.isLoading) return const <String>[];
  final datasets = AppConstants.townshipForecastDatasets[county];
  return [
    if (weather.current is Success) AppConstants.observationDataset,
    if (weather.weekly is Success && datasets != null) datasets.oneWeek,
    if (weather.hourly is Success && datasets != null) datasets.threeDay,
    if (weather.sun is Success) AppConstants.sunTimesDataset,
    if (warnings is Success) ...[AppConstants.warningsByCountyDataset, AppConstants.warningBulletinsDataset],
  ];
}

const _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

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

const _compass8 = ['北', '東北', '東', '東南', '南', '西南', '西', '西北'];
const _compassSectorDegrees = 360 / 8;

/// Observed wind → `東北` (8-point, from-direction) / `靜風` / `風向不定`.
String observedWindLabel(ObservedWind wind) => switch (wind) {
  CalmWind() => '靜風',
  VariableWind() => '風向不定',
  WindFrom(:final degrees) => _compass8[(degrees / _compassSectorDegrees).round() % _compass8.length],
};

/// `發布 11/14 17:00` (Taiwan time).
String issuedText(DateTime t) => '發布 ${monthDay(taiwanWall(t))} ${clockText(t)}';

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
// Now card: sun state and view model

enum SunPhase { beforeSunrise, daytime, afterSunset }

/// The four sun tiles, in time order.
enum SunEvent {
  civilDawn('曙光'),
  sunrise('日出'),
  sunset('日落'),
  civilDusk('暮光');

  const SunEvent(this.label);
  final String label;

  DateTime timeOf(SunDay d) => switch (this) {
    civilDawn => d.civilDawn,
    sunrise => d.sunrise,
    sunset => d.sunset,
    civilDusk => d.civilDusk,
  };
}

/// next = the upcoming sun event (brand-subtle tile); past = already happened (muted value).
enum SunTileTone { normal, next, past }

class SunTile {
  const SunTile({required this.event, required this.time, required this.tone});

  final SunEvent event;
  final DateTime time;
  final SunTileTone tone;
}

/// Sun state at one instant, derived from consecutive SunDays.
class SunNow {
  const SunNow({
    required this.day,
    required this.phase,
    required this.arcFraction,
    required this.nextEvent,
    required this.elevationDegrees,
    required this.note,
    required this.tilesDay,
    required this.tilesAreTomorrow,
    required this.tiles,
    required this.tilesMeta,
  });

  /// The SunDay of now's Taiwan calendar date: source of the 過中天 mark and the day dome.
  final SunDay day;
  final SunPhase phase;

  /// Position on the current half of the arc, 0–1.
  /// daytime: sunrise → sunset of [day] (east → west);
  /// night: previous sunset → next sunrise (the painter runs it right → left under the horizon).
  final double arcFraction;

  /// The sunrise or sunset the note counts to.
  final DateTime nextEvent;

  /// Rounded apparent elevation (negative at night), from solarElevationDegrees.
  final int elevationDegrees;

  /// Sun-status note: 「現在 14:00，距日落 3 小時 7 分」 / 「現在 05:40，日出前，距日出 30 分」 /
  /// 「現在 21:40，已日落，距明天日出 8 小時 12 分」.
  final String note;

  /// The SunDay shown in the 太陽 tile row: today, or tomorrow once today's 暮光 has ended.
  final SunDay tilesDay;
  final bool tilesAreTomorrow;

  /// 曙光 / 日出 / 日落 / 暮光 of [tilesDay], in that order, with next/past tone.
  final List<SunTile> tiles;

  /// 太陽 group meta: 「今天 · 白晝 10 小時 57 分」 / 「明天 11/16 · 白晝 10 小時 56 分」.
  final String tilesMeta;

  bool get isNight => phase != SunPhase.daytime;
}

/// Builds [SunNow] from [days] (expected: yesterday, today, tomorrow); Failure when
/// they cannot cover [now] (stale data). Never substitutes default times.
Result<SunNow> sunNow(List<SunDay> days, Place place, DateTime now) {
  final wall = taiwanWall(now);
  final todayWall = DateTime.utc(wall.year, wall.month, wall.day);
  final byDate = {for (final d in days) d.date: d};

  Result<SunDay> lookup(DateTime dateWall) {
    final key = isoDate(dateWall);
    final d = byDate[key];
    if (d != null) return Success(d);
    final actual = days.isEmpty ? '無資料' : '${days.first.date}–${days.last.date}';
    return Failure('日出日落資料不含所需日期：期望 $key，實際 $actual，請重新整理', dataset: AppConstants.sunTimesDataset);
  }

  final Result<SunDay> todayResult = lookup(todayWall);
  final SunDay today;
  switch (todayResult) {
    case Failure():
      return todayResult.retype<SunNow>();
    case Success(:final data):
      today = data;
  }

  // Neighbour needed: before sunrise → yesterday (arc start), after sunset → tomorrow (arc end, countdown).
  final SunPhase phase;
  final Result<SunDay>? neighbour;
  if (now.isBefore(today.sunrise)) {
    phase = SunPhase.beforeSunrise;
    neighbour = lookup(todayWall.subtract(const Duration(days: 1)));
  } else if (now.isBefore(today.sunset)) {
    phase = SunPhase.daytime;
    neighbour = null;
  } else {
    phase = SunPhase.afterSunset;
    neighbour = lookup(todayWall.add(const Duration(days: 1)));
  }
  if (neighbour case final Failure<SunDay> failure) return failure.retype<SunNow>();
  final other = (neighbour as Success<SunDay>?)?.data;

  double fraction(DateTime from, DateTime to) => now.difference(from).inSeconds / to.difference(from).inSeconds;

  final head = '現在 ${clockText(now)}';
  final (double arcFraction, DateTime nextEvent, String note) = switch (phase) {
    SunPhase.beforeSunrise => (
      fraction(other!.sunset, today.sunrise),
      today.sunrise,
      '$head，日出前，距日出 ${durationText(today.sunrise.difference(now))}',
    ),
    SunPhase.daytime => (
      fraction(today.sunrise, today.sunset),
      today.sunset,
      '$head，距日落 ${durationText(today.sunset.difference(now))}',
    ),
    SunPhase.afterSunset => (
      fraction(today.sunset, other!.sunrise),
      other.sunrise,
      '$head，已日落，距明天日出 ${durationText(other.sunrise.difference(now))}',
    ),
  };

  // Tiles: today until today's 暮光 ends, then tomorrow (the row never mixes two dates).
  final tilesAreTomorrow = !now.isBefore(today.civilDusk);
  final tilesDay = tilesAreTomorrow ? other! : today;
  final shown = [for (final e in SunEvent.values) (e, e.timeOf(tilesDay))];
  // The next marker sits on the tile of [nextEvent]; between sunset and 暮光 that sunrise is
  // not in today's row, so the earliest upcoming tile (暮光) takes it.
  final nextTile = shown.where((s) => s.$2 == nextEvent).firstOrNull ?? shown.where((s) => s.$2.isAfter(now)).firstOrNull;
  final tiles = [
    for (final s in shown)
      SunTile(
        event: s.$1,
        time: s.$2,
        tone: s == nextTile
            ? SunTileTone.next
            : (s.$2.isAfter(now) ? SunTileTone.normal : SunTileTone.past),
      ),
  ];
  final dayLabel = tilesAreTomorrow ? '明天 ${monthDay(taiwanDate(tilesDay.date))}' : '今天';
  final tilesMeta = '$dayLabel · 白晝 ${durationText(tilesDay.sunset.difference(tilesDay.sunrise))}';

  return Success(
    SunNow(
      day: today,
      phase: phase,
      arcFraction: arcFraction,
      nextEvent: nextEvent,
      elevationDegrees: solarElevationDegrees(latitude: place.latitude, longitude: place.longitude, instant: now).round(),
      note: note,
      tilesDay: tilesDay,
      tilesAreTomorrow: tilesAreTomorrow,
      tiles: tiles,
      tilesMeta: tilesMeta,
    ),
  );
}

/// What the now card shows (`arch-solar.md` §5, precedence top to bottom).
sealed class NowCardState {
  const NowCardState();
}

/// current or sun not loaded yet.
final class NowCardLoading extends NowCardState {
  const NowCardLoading();
}

/// current or sun failed because of the API key.
final class NowCardApiKey extends NowCardState {
  const NowCardApiKey(this.issue);
  final ApiKeyIssue issue;
}

/// The observation failed.
final class NowCardFailed extends NowCardState {
  const NowCardFailed(this.message);
  final String message;
}

final class NowCardReady extends NowCardState {
  const NowCardReady({required this.observation, required this.slot, required this.sun});

  final CurrentWeather observation;

  /// Forecast slot covering now; null: 體感/降雨機率 show 「—」 and the 天氣建議 note is absent.
  final HourlyForecast? slot;

  /// Failure: the card replaces arc, sun tiles and sun note with one inline error block.
  final Result<SunNow> sun;
}

NowCardState nowCard(WeatherState state, DateTime now) {
  final current = state.current;
  final sun = state.sun;
  if (current == null || sun == null) return const NowCardLoading();
  if (current case Failure(apiKeyIssue: final issue?)) return NowCardApiKey(issue);
  if (sun case Failure(apiKeyIssue: final issue?)) return NowCardApiKey(issue);
  final CurrentWeather observation;
  switch (current) {
    case Failure(:final message):
      return NowCardFailed(message);
    case Success(:final data):
      observation = data;
  }
  final place = state.location;
  final Result<SunNow> sunState = switch (sun) {
    final Failure<List<SunDay>> failure => failure.retype<SunNow>(),
    Success(:final data) when place != null => sunNow(data, place, now),
    // Invariant: WeatherState carries data only for a loaded place; surface the break instead of hiding the arc.
    Success() => const Failure('沒有地點，無法計算太陽仰角', dataset: AppConstants.sunTimesDataset),
  };
  final slot = switch (state.hourly) {
    Success(:final data) => currentSlot(data, now),
    _ => null,
  };
  return NowCardReady(observation: observation, slot: slot, sun: sunState);
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
