import '../../../data/models/hazard_models.dart';

/// CWA rain-warning thresholds (mm of accumulated rain): 大雨, 豪雨, 大豪雨, 超大豪雨.
const rainWarningThresholds = [80.0, 200.0, 350.0, 500.0];

/// Level names indexed by [rainLevel]; 0 = below every threshold.
const rainLevelNames = ['未達警戒', '大雨', '豪雨', '大豪雨', '超大豪雨'];

/// Label of warning level [i] + 1 with its threshold, e.g. `大雨 80`.
String rainThresholdLabel(int i) => '${rainLevelNames[i + 1]} ${rainWarningThresholds[i].toInt()}';

/// Widths (percent of the bar) of the 0–80, 80–200, 200–350, 350–500 segments
/// in the threshold bar (mockup `.thr__bar`).
const thresholdSegmentPercents = [16.0, 24.0, 30.0, 30.0];

/// Forecast cells below this are blank on the map (mockup hint).
const forecastVisibleMinimumMillimeters = 1.0;

/// Upper bounds of forecast buckets 1–3; bucket 4 is everything above.
const forecastBucketUpperMillimeters = [5.0, 10.0, 20.0];

/// 0 = below 大雨 … 4 = 超大豪雨.
int rainLevel(double mm) => rainWarningThresholds.where((t) => mm >= t).length;

/// Marker position on the threshold bar, 0–1 (piecewise linear per segment, clamped).
double thresholdMarkerFraction(double mm) {
  var done = 0.0;
  var lower = 0.0;
  for (var i = 0; i < rainWarningThresholds.length; i++) {
    final upper = rainWarningThresholds[i];
    final segment = thresholdSegmentPercents[i] / 100;
    if (mm < upper) return done + (mm - lower) / (upper - lower) * segment;
    done += segment;
    lower = upper;
  }
  return done;
}

/// Remaining mm to the next warning level and its name; null at the top level.
({String name, double remainingMillimeters})? nextWarning(double mm) {
  final level = rainLevel(mm);
  if (level >= rainWarningThresholds.length) return null;
  return (name: rainLevelNames[level + 1], remainingMillimeters: rainWarningThresholds[level] - mm);
}

/// 1 decimal, e.g. `86.5`; null (station reported no value) → `—`.
String millimetersText(double? mm) => mm == null ? '—' : mm.toStringAsFixed(1);

/// County chip order: [current] first (none without a place), then the other counties of [stations] by first appearance.
List<String> countyChipOrder(List<RainStation> stations, String? current) {
  final others = {for (final s in stations) s.county}..remove(current);
  return [?current, ...others];
}

/// Past-10-minute rain above this counts as currently raining.
const rainingMinimumPast10MinutesMillimeters = 0.0;

/// Hero 「目前」 tile text; null (no value) → `—`.
String currentRainText(double? past10MinMm) {
  if (past10MinMm == null) return '—';
  return past10MinMm > rainingMinimumPast10MinutesMillimeters ? '持續降雨' : '無降雨';
}

/// Stations sorted high → low (missing values last) or by name.
enum StationSort { rainfall, name }

List<RainStation> sortStations(List<RainStation> stations, StationSort sort) {
  final sorted = [...stations];
  switch (sort) {
    case StationSort.rainfall:
      sorted.sort((a, b) {
        final x = a.todayMm;
        final y = b.todayMm;
        if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
        return y.compareTo(x);
      });
    case StationSort.name:
      sorted.sort((a, b) => a.name.compareTo(b.name));
  }
  return sorted;
}

/// Stations of [county]; null = every station.
List<RainStation> stationsInScope(List<RainStation> stations, String? county) =>
    county == null ? stations : stations.where((s) => s.county == county).toList();

/// Bucket per grid cell, same order as [RainForecastGrid.values]:
/// 0 = blank (missing or < 1 mm), 1 = 1–5, 2 = 5–10, 3 = 10–20, 4 = ≥ 20 mm.
List<int> forecastBuckets(RainForecastGrid grid) {
  return [
    for (final mm in grid.values)
      if (mm == null || mm < forecastVisibleMinimumMillimeters)
        0
      else
        1 + forecastBucketUpperMillimeters.where((upper) => mm >= upper).length,
  ];
}
