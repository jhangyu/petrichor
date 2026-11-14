import 'package:cwb_flutter/data/models/hazard_models.dart';
import 'package:cwb_flutter/features/hazard/warnings/warning_groups.dart';
import 'package:flutter_test/flutter_test.dart';

CountyWarning _w(String phenomena, DateTime start, {WarningBulletin? bulletin}) => CountyWarning(
      phenomena: phenomena,
      significance: '特報',
      start: start,
      end: start.add(const Duration(hours: 12)),
      bulletin: bulletin,
    );

WarningBulletin _bulletin(String title) => WarningBulletin(
      title: title,
      issueTime: DateTime.utc(2026, 11, 14),
      updatedAt: DateTime.utc(2026, 11, 14),
      start: DateTime.utc(2026, 11, 14),
      end: DateTime.utc(2026, 11, 15),
      description: '內文',
      affectedAreas: const [],
    );

void main() {
  final t0 = DateTime.utc(2026, 11, 14, 8);
  final t1 = DateTime.utc(2026, 11, 14, 10);

  test('merges counties sharing kind and validity, sorts by level then start', () {
    final groups = groupWarnings(ActiveWarnings(bulletins: const [], fetchedAt: DateTime.utc(2026, 11, 14), counties: [
      CountyWarnings(county: '宜蘭縣', warnings: [_w('豪雨', t1), _w('低溫', t0)]),
      CountyWarnings(county: '花蓮縣', warnings: [_w('豪雨', t1)]),
      CountyWarnings(county: '臺北市', warnings: [_w('大雨', t0)]),
    ]));
    expect([for (final g in groups) g.name], ['豪雨特報', '大雨特報', '低溫特報']);
    expect(groups.first.counties, ['宜蘭縣', '花蓮縣']);
    expect([for (final g in groups) g.level], [2, 1, null]);
    expect(countyCount(groups), 3);
    expect([for (final g in groupsForCounty(groups, '臺北市')) g.name], ['大雨特報']);
  });

  test('bulletin title wins over phenomena (-001 labels 大雨 as 豪雨)', () {
    final groups = groupWarnings(ActiveWarnings(bulletins: const [], fetchedAt: DateTime.utc(2026, 11, 14), counties: [
      CountyWarnings(county: '臺北市', warnings: [_w('豪雨', t0, bulletin: _bulletin('大雨特報'))]),
    ]));
    expect(groups.single.name, '大雨特報');
    expect(groups.single.level, 1);
  });

  test('higher rain levels do not match the shorter name', () {
    final groups = groupWarnings(ActiveWarnings(bulletins: const [], fetchedAt: DateTime.utc(2026, 11, 14), counties: [
      CountyWarnings(county: 'A', warnings: [_w('超大豪雨', t0)]),
      CountyWarnings(county: 'B', warnings: [_w('大豪雨', t0)]),
    ]));
    expect([for (final g in groups) g.level], [4, 3]);
    expect(groups.first.isUpcoming(t0.subtract(const Duration(minutes: 1))), isTrue);
    expect(groups.first.isUpcoming(t0), isFalse);
  });
}
