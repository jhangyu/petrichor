import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/data_display.dart';
import '../../../core/time/taiwan_time.dart';
import 'warning_groups.dart';
import 'warning_style.dart';

const _upcomingLabel = '即將生效';
const _activeLabel = '生效中';

/// `.warn`: expandable warning card. Header = icon, name, status badge, counties and validity;
/// body = bulletin text, county badges and issue time (only what the bulletin provides).
class WarningCard extends StatefulWidget {
  const WarningCard({
    super.key,
    required this.group,
    required this.now,
    required this.onViewRainfall,
    this.initiallyOpen = false,
  });

  final WarningGroup group;
  final DateTime now;
  final bool initiallyOpen;

  /// Opens the 雨量 tab; the button is shown on rain warnings (level 1–4) only.
  final VoidCallback onViewRainfall;

  @override
  State<WarningCard> createState() => _WarningCardState();
}

class _WarningCardState extends State<WarningCard> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final style = WarningLevelStyle.of(group.level);
    final bulletin = group.bulletin;
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.background1,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: AppShadows.s4,
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: style.solid, width: AppStroke.thicker))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summary(group, style),
            if (_open)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.s16, AppSpace.s0, AppSpace.s16, AppSpace.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpace.s12,
                  children: [
                    if (bulletin != null) _description(bulletin.description),
                    _facts(group, style),
                    if (group.level != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: AppButton(
                          label: '查看雨量',
                          icon: Icons.chevron_right,
                          small: true,
                          onPressed: widget.onViewRainfall,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summary(WarningGroup group, WarningLevelStyle style) {
    return InkWell(
      onTap: () => setState(() => _open = !_open),
      hoverColor: AppPalette.backgroundHover,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.touch),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Row(
            spacing: AppSpace.s12,
            children: [
              Container(
                width: AppSize.touch,
                height: AppSize.touch,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: style.bg,
                  border: Border.all(color: style.stroke, width: AppStroke.thin),
                ),
                child: Icon(warningIcon(group), color: style.fg),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpace.s4,
                  children: [
                    Row(
                      spacing: AppSpace.s8,
                      children: [
                        Flexible(
                          child: Text(group.name, style: AppType.body2.copyWith(color: AppPalette.foreground1, fontWeight: FontWeight.w600)),
                        ),
                        AppBadge(label: group.isUpcoming(widget.now) ? _upcomingLabel : _activeLabel, tone: style.tone),
                      ],
                    ),
                    _meta(Icons.location_on_outlined, group.counties.join('、')),
                    _meta(Icons.schedule,
                        '${formatTaiwanMonthDayClock(group.start)} – ${formatTaiwanMonthDayClock(group.end)}',
                        tabular: true),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _open ? 0.25 : 0,
                duration: AppMotion.normal,
                curve: AppMotion.decelerateMiddle,
                child: const Icon(Icons.chevron_right, color: AppPalette.foreground3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text, {bool tabular = false}) {
    final base = AppType.caption1.copyWith(color: AppPalette.foreground2);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.s4,
      children: [
        Icon(icon, size: AppSize.icon16, color: AppPalette.foreground3),
        Expanded(child: Text(text, style: tabular ? base.copyWith(fontFeatures: AppType.tabular) : base)),
      ],
    );
  }

  Widget _description(String text) {
    return Container(
      padding: const EdgeInsets.only(top: AppSpace.s12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppPalette.stroke3, width: AppStroke.thin))),
      child: Text(text, style: AppType.body1.copyWith(color: AppPalette.foreground1)),
    );
  }

  Widget _facts(WarningGroup group, WarningLevelStyle style) {
    final bulletin = group.bulletin;
    final labelStyle = AppType.caption1.copyWith(color: AppPalette.foreground3);
    Widget row(String label, Widget value) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: AppSpace.s12,
          children: [
            Text(label, style: labelStyle),
            Expanded(child: Align(alignment: Alignment.centerLeft, child: value)),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s8,
      children: [
        row(
          '影響縣市',
          Wrap(
            spacing: AppSpace.s4,
            runSpacing: AppSpace.s4,
            children: [for (final c in group.counties) AppBadge(label: c, tone: style.tone)],
          ),
        ),
        if (bulletin != null)
          row(
            '發布時間',
            Text(formatTaiwanMonthDayClock(bulletin.issueTime),
                style: AppType.body1.copyWith(color: AppPalette.foreground1, fontFeatures: AppType.tabular)),
          ),
      ],
    );
  }
}
