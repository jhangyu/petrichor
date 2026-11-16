import '../../../core/api/result.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/time/taiwan_time.dart';
import '../../../data/models/place.dart';
import '../../../data/models/weather_models.dart';
import '../solar_elevation.dart';
import 'weather_format.dart';

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
