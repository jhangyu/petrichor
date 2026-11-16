import 'package:petrichor/data/models/place.dart';
import 'package:petrichor/data/models/weather_models.dart';
import 'package:petrichor/core/api/result.dart';
import 'package:petrichor/core/constants/app_constants.dart';
import 'package:petrichor/core/time/taiwan_time.dart';
import 'package:petrichor/features/weather/weather_provider.dart';
import 'package:petrichor/features/weather/weather_logic.dart';
import 'package:petrichor/features/weather/sun_now.dart';
import 'package:petrichor/features/weather/weather_format.dart';
import 'package:petrichor/features/weather/widgets/weather_glyph_icon.dart';
import 'package:flutter_test/flutter_test.dart';

const taipei = Place(county: '臺北市', town: '中正區', latitude: 25.0375, longitude: 121.5637);

/// Taiwan wall time 2026-11-14 hh:mm as an instant.
DateTime tw(int day, int hour, [int minute = 0]) => DateTime.utc(2026, 11, day, hour - 8, minute);

SunDay sunDay(int day) => SunDay(
  date: '2026-11-${day.toString().padLeft(2, '0')}',
  civilDawn: tw(day, 5, 46),
  sunrise: tw(day, 6, 10),
  sunset: tw(day, 17, 7),
  civilDusk: tw(day, 17, 31),
  transit: tw(day, 11, 38),
  transitAltitudeDegrees: 47,
);

HourlyForecast slot(DateTime start, {double? t, int? pop}) => HourlyForecast(
  startTime: start,
  temperature: t,
  apparentTemperature: null,
  humidity: null,
  windSpeed: null,
  windDirection: null,
  pop: pop,
  weather: null,
  weatherCode: null,
  description: null,
);

void main() {
  final days = [sunDay(13), sunDay(14), sunDay(15)];
  SunNow sunAt(DateTime now) => sunNow(days, taipei, now).data;
  List<SunTileTone> tones(SunNow s) => [for (final t in s.tiles) t.tone];
  const n = SunTileTone.normal, next = SunTileTone.next, past = SunTileTone.past;

  test('daytime: arc from sunrise to sunset, counts to sunset, sunset tile next', () {
    final s = sunAt(tw(14, 14));
    expect(s.phase, SunPhase.daytime);
    expect(s.arcFraction, closeTo(470 / 657, 1e-9));
    expect(s.nextEvent, tw(14, 17, 7));
    expect(s.note, '現在 14:00，距日落 3 小時 7 分');
    expect(s.elevationDegrees, greaterThan(0));
    expect(s.tilesAreTomorrow, isFalse);
    expect(tones(s), [past, past, next, n]);
    expect(s.tilesMeta, '今天 · 白晝 10 小時 57 分');
  });

  test('before sunrise: night arc starts at yesterday sunset, today row with sunrise next', () {
    final s = sunAt(tw(14, 5, 40));
    expect(s.phase, SunPhase.beforeSunrise);
    expect(s.arcFraction, closeTo(753 / 783, 1e-9));
    expect(s.nextEvent, tw(14, 6, 10));
    expect(s.note, '現在 05:40，日出前，距日出 30 分');
    expect(s.elevationDegrees, lessThan(0));
    expect(s.day.date, '2026-11-14');
    expect(tones(s), [n, next, n, n]);
  });

  test('after sunset: counts to tomorrow sunrise, tiles switch to tomorrow only after 暮光', () {
    final dusk = sunAt(tw(14, 17, 20));
    expect(dusk.phase, SunPhase.afterSunset);
    expect(dusk.tilesAreTomorrow, isFalse);
    expect(tones(dusk), [past, past, past, next]);

    final s = sunAt(tw(14, 21, 40));
    expect(s.arcFraction, closeTo(273 / 783, 1e-9));
    expect(s.nextEvent, tw(15, 6, 10));
    expect(s.note, '現在 21:40，已日落，距明天日出 8 小時 30 分');
    expect(s.day.date, '2026-11-14');
    expect(s.tilesAreTomorrow, isTrue);
    expect(s.tilesDay.date, '2026-11-15');
    expect(tones(s), [n, next, n, n]);
    expect(s.tilesMeta, '明天 11/15 · 白晝 10 小時 57 分');
  });

  test('sun data not covering now fails naming the expected and actual dates', () {
    String message(DateTime now) => (sunNow(days, taipei, now) as Failure<SunNow>).message;
    expect(message(tw(16, 12)), contains('期望 2026-11-16，實際 2026-11-13–2026-11-15'));
    expect(message(tw(13, 5)), contains('期望 2026-11-12'));
    expect(message(tw(15, 20)), contains('期望 2026-11-16'));
  });

  test('now card keeps the observation when sun data fails', () {
    final obs = CurrentWeather(
      stationName: '臺北',
      observedAt: tw(14, 14),
      temperature: 22,
      humidity: null,
      windSpeed: null,
      windDirection: null,
      weather: null,
      dailyHigh: null,
      dailyLow: null,
    );
    NowCardReady card(Result<List<SunDay>> sun) => nowCard(
      WeatherState(location: taipei, current: Success(obs), sun: sun, isLoading: false),
      tw(14, 14),
    ) as NowCardReady;

    final failed = card(const Failure('逾時', dataset: AppConstants.sunTimesDatasetId));
    expect(failed.observation, same(obs));
    expect((failed.sun as Failure).message, '逾時');
    expect(failed.slot, isNull);

    final stale = card(Success([sunDay(12)]));
    expect((stale.sun as Failure).message, contains('期望 2026-11-14'));
    expect(card(Success(days)).sun, isA<Success<SunNow>>());
  });

  test('now card keeps the sun failure location when re-wrapping it', () {
    final obs = CurrentWeather(
      stationName: '臺北',
      observedAt: tw(14, 14),
      temperature: 22,
      humidity: null,
      windSpeed: null,
      windDirection: null,
      weather: null,
      dailyHigh: null,
      dailyLow: null,
    );
    final state = WeatherState(
      location: taipei,
      current: Success(obs),
      sun: const Failure('逾時', dataset: AppConstants.sunTimesDatasetId, location: '臺北市中正區'),
      isLoading: false,
    );
    final sun = (nowCard(state, tw(14, 14)) as NowCardReady).sun as Failure;
    expect(sun.location, '臺北市中正區');
    expect(sun.dataset, AppConstants.sunTimesDatasetId);
  });

  test('day labels use the Taiwan calendar date, not UTC', () {
    // 2026-11-14 00:30 Taiwan is still 11-13 in UTC.
    final now = tw(14, 0, 30);
    expect(relativeDay(taiwanWall(tw(14, 23)), now), '今天');
    expect(relativeDay(taiwanDate('2026-11-15'), now), '明天');
    expect(relativeDay(taiwanDate('2026-11-16'), now), '後天');
    expect(relativeDay(taiwanDate('2026-11-17'), now), '週二');
    expect(monthDayWeekday(taiwanDate('2026-11-14')), '11/14（六）');
    expect(fromTaiwanWall(taiwanWall(now)), now);
  });

  test('72-hour extremes skip missing values and keep the earliest slot on ties', () {
    final slots = [
      slot(tw(14, 15), t: 28, pop: 20),
      slot(tw(14, 18), t: null, pop: 70),
      slot(tw(14, 21), t: 20, pop: 70),
      slot(tw(15, 0), t: 28, pop: null),
    ];
    final e = forecastExtremes(slots);
    expect(e.hottest, same(slots[0]));
    expect(e.coldest, same(slots[2]));
    expect(e.wettest, same(slots[1]));

    final empty = forecastExtremes([slot(tw(14, 15))]);
    expect([empty.hottest, empty.coldest, empty.wettest], everyElement(isNull));

    expect(currentSlot(slots, tw(14, 17, 59)), same(slots[0]));
    expect(currentSlot(slots, tw(14, 14, 59)), isNull);
  });

  test('weekly scale spans all lows/highs and the current temperature', () {
    DailyForecast day(double? lo, double? hi) => DailyForecast(
      date: '2026-11-14',
      maxTemperature: hi,
      minTemperature: lo,
      maxApparentTemperature: null,
      minApparentTemperature: null,
      humidity: null,
      windSpeed: null,
      pop: null,
      weather: null,
      weatherCode: null,
    );
    final scale = weeklyScale([day(20.4, 26), day(null, 29.5)], 31)!;
    expect((scale.lowest, scale.highest), (20.0, 31.0));
    expect(scale.fraction(25.5), closeTo(0.5, 1e-9));
    expect(scale.fraction(40), 1.0);
    expect(weeklyScale([day(null, null)], null), isNull);
  });

  test('weather text maps to icon buckets with precipitation first', () {
    expect(weatherGlyph('晴'), WeatherGlyph.sun);
    expect(weatherGlyph('多雲時晴'), WeatherGlyph.partly);
    expect(weatherGlyph('陰'), WeatherGlyph.cloud);
    expect(weatherGlyph('多雲短暫陣雨'), WeatherGlyph.rain);
    expect(weatherGlyph('多雲午後短暫雷陣雨'), WeatherGlyph.thunder);
    expect(weatherGlyph('有霾'), WeatherGlyph.fog);
    expect(weatherGlyph(null), WeatherGlyph.unknown);
  });

  test('observed wind maps degrees to the nearest of 8 points, plus calm and variable', () {
    expect(observedWindLabel(const WindFrom(360)), '北');
    expect(observedWindLabel(const WindFrom(22)), '北');
    expect(observedWindLabel(const WindFrom(23)), '東北');
    expect(observedWindLabel(const WindFrom(260)), '西');
    expect(observedWindLabel(const WindFrom(338)), '北');
    expect(observedWindLabel(const CalmWind()), '靜風');
    expect(observedWindLabel(const VariableWind()), '風向不定');
  });

  test('issue time is shown in Taiwan time', () {
    expect(issuedText(DateTime.utc(2026, 11, 14, 9)), '發布 11/14 17:00');
    expect(issuedText(DateTime.utc(2026, 11, 14, 17)), '發布 11/15 01:00');
  });
}
