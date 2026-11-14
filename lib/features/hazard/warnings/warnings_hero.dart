import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/data_display.dart';
import '../../radar/radar_playback.dart';
import 'warning_groups.dart';
import 'warning_style.dart';

/// `.hero` summary. With groups: count, per-name chips and [foot]. Without: the 「目前無警特報」 variant.
class WarningsHero extends StatelessWidget {
  const WarningsHero({super.key, required this.label, required this.groups, required this.foot, required this.emptyText});

  /// Top label, e.g. 「目前生效」 or 「臺北市目前生效」.
  final String label;
  final List<WarningGroup> groups;

  /// Foot line (icon + text); null hides it.
  final ({IconData icon, String text})? foot;

  /// Body text of the empty variant.
  final String emptyText;

  /// Foot line of a county view: effective period of [groups], e.g. 「11/14 18:00 起生效 · 至 11/15 06:00」.
  static String periodText(List<WarningGroup> groups) {
    final start = groups.map((g) => g.start).reduce((a, b) => a.isBefore(b) ? a : b);
    final end = groups.map((g) => g.end).reduce((a, b) => a.isAfter(b) ? a : b);
    return '${formatTaiwanMonthDayClock(start)} 起生效 · 至 ${formatTaiwanMonthDayClock(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final empty = groups.isEmpty;
    final style = empty ? WarningLevelStyle.ok : WarningLevelStyle.of(groups.first.level);
    final foot = this.foot;
    return Semantics(
      container: true,
      label: '警特報摘要',
      child: AppCard(
        hero: true,
        heroColor: style.bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.s16,
          children: [
            Row(
              spacing: AppSpace.s12,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpace.s4,
                    children: [
                      Text(label, style: AppType.body1Strong.copyWith(color: style.fg)),
                      if (empty)
                        Text(emptyText, style: AppType.body1.copyWith(color: AppPalette.fg2))
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          spacing: AppSpace.s8,
                          children: [
                            Text('${groups.length}',
                                style: AppType.display.copyWith(color: style.fg, fontFeatures: AppType.tabular)),
                            Text('項警特報', style: AppType.subtitle2.copyWith(color: AppPalette.fg1)),
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  width: AppSize.icon64,
                  height: AppSize.icon64,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppPalette.bg1, boxShadow: AppShadows.s4),
                  child: Icon(empty ? Icons.check_circle_outline : warningIcon(groups.first),
                      size: AppSize.icon32, color: style.solid),
                ),
              ],
            ),
            if (!empty) Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8, children: _chips()),
            if (foot != null)
              Row(
                spacing: AppSpace.s8,
                children: [
                  Icon(foot.icon, size: AppSize.icon16, color: AppPalette.fg2),
                  Expanded(
                    child: Text(foot.text,
                        style: AppType.caption1.copyWith(color: AppPalette.fg2, fontFeatures: AppType.tabular)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// One chip per warning name with the number of warnings, in the order of [groups] (highest level first).
  List<Widget> _chips() {
    final counts = <String, ({int level, int count})>{};
    for (final g in groups) {
      final prev = counts[g.name];
      counts[g.name] = (level: g.level ?? 0, count: (prev?.count ?? 0) + 1);
    }
    return [
      for (final MapEntry(:key, :value) in counts.entries)
        AppBadge(label: '$key ${value.count}', tone: WarningLevelStyle.of(value.level == 0 ? null : value.level).tone),
    ];
  }
}
