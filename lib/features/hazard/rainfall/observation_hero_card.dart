import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/data_display.dart' show MetricTone;
import '../../../data/models/hazard_models.dart';
import '../../../core/time/taiwan_time.dart';
import 'rain_level_badge.dart';
import 'rainfall_logic.dart';

String _millimetersWithUnitText(double? mm) => mm == null ? '—' : '${millimetersText(mm)} mm';

/// Hero strip: nearest station's accumulated rain, level badge, threshold bar and
/// the four secondary readings in three rows.
class ObservationHeroCard extends StatelessWidget {
  const ObservationHeroCard({super.key, required this.rainfall});

  final CountyRainfall rainfall;

  @override
  Widget build(BuildContext context) {
    final station = rainfall.nearest;
    final mm = station.todayMillimeters!; // CountyRainfall.nearest always has a value
    final next = nextWarning(mm);
    final raining = (station.past10MinutesMillimeters ?? 0) > rainingMinimumPast10MinutesMillimeters;
    final readings = [
      _Reading(label: '近 1 小時', value: _millimetersWithUnitText(station.past1HourMillimeters)),
      _Reading(label: '近 3 小時', value: _millimetersWithUnitText(station.past3HoursMillimeters)),
      if (next != null) _Reading(label: '距${next.name}門檻', value: _millimetersWithUnitText(next.remainingMillimeters), tone: MetricTone.next),
      _Reading(label: '目前', value: currentRainText(station.past10MinutesMillimeters), tone: raining ? MetricTone.rain : MetricTone.normal),
    ];
    return AppCard(
      hero: true,
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s8,
        children: [
          Row(
            spacing: AppSpace.s8,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '最近測站 · ${station.name}', style: AppType.body1Strong.copyWith(color: AppPalette.foreground1)),
                      TextSpan(
                        text: ' · 觀測 ${clockText(station.observedAt)}',
                        style: AppType.caption1.copyWith(color: AppPalette.foreground3, fontFeatures: AppType.tabular),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              RainLevelBadge(level: rainLevel(mm)),
            ],
          ),
          Row(
            spacing: AppSpace.s16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今日累積', style: AppType.caption1.copyWith(color: AppPalette.foreground3)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    spacing: AppSpace.s4,
                    children: [
                      Text(millimetersText(mm), style: AppType.title1.copyWith(color: AppPalette.foreground1, fontFeatures: AppType.tabular)),
                      Text('mm', style: AppType.body1Strong.copyWith(color: AppPalette.foreground2)),
                    ],
                  ),
                ],
              ),
              Expanded(child: _ThresholdBar(mm: mm)),
            ],
          ),
          const Divider(height: 1, thickness: AppStroke.thin, color: AppPalette.stroke3),
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (i, reading) in readings.indexed) ...[
                  if (i > 0) const VerticalDivider(width: AppSpace.s4, thickness: AppStroke.thin, color: AppPalette.stroke3),
                  // The 距…門檻 label varies in length: it alone yields space (ellipsis), values never shrink.
                  if (reading.tone == MetricTone.next) Flexible(child: reading) else reading,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One reading of the strip's third row: label over value.
class _Reading extends StatelessWidget {
  const _Reading({required this.label, required this.value, this.tone = MetricTone.normal});

  final String label;
  final String value;
  final MetricTone tone;

  @override
  Widget build(BuildContext context) {
    final next = tone == MetricTone.next;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: next
              ? AppType.caption1.copyWith(color: AppPalette.brandForegroundStrong, fontWeight: FontWeight.w600)
              : AppType.caption1.copyWith(color: AppPalette.foreground3),
        ),
        Text(
          value,
          softWrap: false,
          style: AppType.body1Strong.copyWith(
            color: tone == MetricTone.rain ? AppPalette.rainForeground : AppPalette.foreground1,
            fontFeatures: AppType.tabular,
          ),
        ),
      ],
    );
  }
}

/// `.thr`: segmented bar 0 / 80 / 200 / 350 (/ 500) with a marker at [mm].
class _ThresholdBar extends StatelessWidget {
  const _ThresholdBar({required this.mm});

  final double mm;

  static const _markerWidth = 3.0;
  static const _markerHeight = AppSpace.s16;

  @override
  Widget build(BuildContext context) {
    final flexes = [for (final p in thresholdSegmentPercents) p.round()];
    final labels = ['0', for (var i = 0; i < flexes.length - 1; i++) rainThresholdLabel(i)];
    final semantics = nextWarning(mm);
    return Semantics(
      label: semantics == null
          ? '已達超大豪雨門檻'
          : '警戒門檻：目前 ${millimetersText(mm)} 毫米，距${semantics.name} ${millimetersText(semantics.remainingMillimeters)} 毫米',
      child: ExcludeSemantics(
        child: Column(
          spacing: AppSpace.s4,
          children: [
            LayoutBuilder(
              builder: (context, box) => Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: SizedBox(
                      height: AppSize.legendBar,
                      child: Row(
                        children: [
                          for (var i = 0; i < flexes.length; i++)
                            Expanded(flex: flexes[i], child: ColoredBox(color: rainLevelColor(i))),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: box.maxWidth * thresholdMarkerFraction(mm) - _markerWidth / 2,
                    top: -AppSpace.s4,
                    child: Container(
                      width: _markerWidth,
                      height: _markerHeight,
                      decoration: BoxDecoration(
                        color: AppPalette.foreground1,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(color: AppPalette.background1, width: AppStroke.thin),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < flexes.length; i++)
                  Expanded(
                    flex: flexes[i],
                    child: Text(
                      labels[i],
                      style: AppType.caption2.copyWith(color: AppPalette.foreground3, fontFeatures: AppType.tabular),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
