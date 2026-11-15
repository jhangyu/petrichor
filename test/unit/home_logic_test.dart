import 'package:cwb_flutter/data/models/weather_models.dart';
import 'package:cwb_flutter/features/weather/widgets/home_logic.dart';
import 'package:flutter_test/flutter_test.dart';

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
  transitSide: TransitSide.south,
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
  test('sun line counts to sunset by day, to sunrise before dawn, to tomorrow after sunset', () {
    final today = sunDay(14);
    final tomorrow = sunDay(15);
    expect(sunNowLine(today, tomorrow, tw(14, 14)), '現在 14:00 · 距日落 3 小時 7 分');
    expect(sunNowLine(today, tomorrow, tw(14, 6, 3)), '現在 06:03 · 距日出 7 分');
    expect(sunNowLine(today, tomorrow, tw(14, 20)), '現在 20:00 · 已日落，距明天日出 10 小時 10 分');
    expect(sunNowLine(today, null, tw(14, 20)), '現在 20:00 · 已日落');

    final noon = sunPosition(today, tw(14, 11, 38));
    expect(noon.phase, SunPhase.daytime);
    expect(noon.dayFraction, closeTo(0.5, 0.01));
    expect(sunPosition(today, tw(14, 5)).dayFraction, 0);
    expect(sunPosition(today, tw(14, 18)).dayFraction, 1);
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
    expect((scale.min, scale.max), (20.0, 31.0));
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
