import '../../../data/models/hazard_models.dart';
import '../rainfall/rainfall_logic.dart' show rainLevelNames;

/// Rain-warning names, highest first: the level (1–4) is the first entry contained in the name.
/// CWA names no other warning by level, so every other warning has level null.
final _rainLevelsByName = [for (var level = rainLevelNames.length - 1; level >= 1; level--) (rainLevelNames[level], level)];

/// One warning (same kind, same validity) with every county it applies to.
class WarningGroup {
  final String phenomena;
  final String significance;
  final DateTime start;
  final DateTime end;
  final List<String> counties;

  /// Bulletin of the first county that has one; null when none matched.
  final WarningBulletin? bulletin;

  const WarningGroup({
    required this.phenomena,
    required this.significance,
    required this.start,
    required this.end,
    required this.counties,
    required this.bulletin,
  });

  /// Bulletin title (e.g. 「大雨特報」), else phenomena + significance. W-C0033-001 labels some
  /// 大雨 bulletins 「豪雨」, so the bulletin title is the more reliable name.
  String get name => bulletin?.title ?? '$phenomena$significance';

  /// Rain-warning level 1–4; null for any other warning.
  int? get level {
    for (final (rainName, level) in _rainLevelsByName) {
      if (name.contains(rainName)) return level;
    }
    return null;
  }

  /// Not yet in effect at [now].
  bool isUpcoming(DateTime now) => now.isBefore(start);
}

/// Merges per-county warnings into groups keyed by (phenomena, significance, start, end).
/// Sorted by level (highest first, non-rain last), then start time.
List<WarningGroup> groupWarnings(ActiveWarnings active) {
  final byKey = <(String, String, DateTime, DateTime), List<(String, CountyWarning)>>{};
  for (final c in active.counties) {
    for (final w in c.warnings) {
      byKey.putIfAbsent((w.phenomena, w.significance, w.start, w.end), () => []).add((c.county, w));
    }
  }
  final groups = [
    for (final MapEntry(key: (phenomena, significance, start, end), value: members) in byKey.entries)
      WarningGroup(
        phenomena: phenomena,
        significance: significance,
        start: start,
        end: end,
        counties: [for (final (county, _) in members) county],
        bulletin: members.map((m) => m.$2.bulletin).nonNulls.firstOrNull,
      ),
  ];
  groups.sort((a, b) {
    final byLevel = (b.level ?? 0).compareTo(a.level ?? 0);
    return byLevel != 0 ? byLevel : a.start.compareTo(b.start);
  });
  return groups;
}

/// Groups that apply to [county].
List<WarningGroup> groupsForCounty(List<WarningGroup> groups, String county) =>
    [for (final g in groups) if (g.counties.contains(county)) g];
