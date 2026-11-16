import 'package:flutter/painting.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/models/weather_models.dart';
import '../../core/api/result.dart';
import '../../core/api/cwa_datasets.dart';
import 'weather_provider.dart';
import 'sun_now.dart';

/// Below this 降雨機率 the value is shown muted (`.day__rain--low`, `.fc-t--pop-low`).
const lowRainProbabilityThresholdPercent = 30;

/// Whether a 降雨機率 is shown muted; unknown (null) counts as low.
bool isLowRainProbability(int? pop) => pop == null || pop < lowRainProbabilityThresholdPercent;

/// [base] with the 降雨機率 emphasis: muted regular when [isLowRainProbability], rain-coloured semibold otherwise.
TextStyle rainProbabilityTextStyle(TextStyle base, int? pop) {
  final low = isLowRainProbability(pop);
  return base.copyWith(
    color: low ? AppPalette.foreground3 : AppPalette.rainForeground,
    fontWeight: low ? FontWeight.w400 : FontWeight.w600,
  );
}

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
  final datasets = CwaDatasets.townshipForecastDatasets[county];
  return [
    if (weather.current is Success) CwaDatasets.observationDatasetId,
    if (weather.weekly is Success && datasets != null) datasets.oneWeek,
    if (weather.hourly is Success && datasets != null) datasets.threeDay,
    if (weather.sun is Success) CwaDatasets.sunTimesDatasetId,
    if (warnings is Success) ...[CwaDatasets.warningsByCountyDatasetId, CwaDatasets.warningBulletinsDatasetId],
  ];
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
    Success() => const Failure('沒有地點，無法計算太陽仰角', dataset: CwaDatasets.sunTimesDatasetId),
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
class TemperatureScale {
  const TemperatureScale(this.lowest, this.highest);

  final double lowest;
  final double highest;

  /// Position of [t] on the axis, 0 (lowest) – 1 (highest).
  double fraction(double t) => highest == lowest ? 0.5 : ((t - lowest) / (highest - lowest)).clamp(0.0, 1.0);
}

/// Axis spanning every day's low/high and [current]; null when no value exists.
TemperatureScale? weeklyScale(List<DailyForecast> days, double? current) {
  final values = [
    for (final d in days) ...[d.minTemperature, d.maxTemperature],
    current,
  ].whereType<double>();
  if (values.isEmpty) return null;
  return TemperatureScale(
    values.reduce((a, b) => a < b ? a : b).floorToDouble(),
    values.reduce((a, b) => a > b ? a : b).ceilToDouble(),
  );
}
