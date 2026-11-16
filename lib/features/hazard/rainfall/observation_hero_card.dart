import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/data_display.dart';
import '../../../data/models/hazard_models.dart';
import '../../../core/time/taiwan_time.dart';
import 'rain_level_badge.dart';
import 'rainfall_logic.dart';

String _millimetersWithUnitText(double? mm) => mm == null ? '—' : '${millimetersText(mm)} mm';

/// Hero: nearest station's accumulated rain, level badge, threshold bar.
class ObservationHeroCard extends StatelessWidget {
  const ObservationHeroCard({super.key, required this.rainfall});

  final CountyRainfall rainfall;

  @override
  Widget build(BuildContext context) {
    final station = rainfall.nearest;
    final mm = station.todayMm!; // CountyRainfall.nearest always has a value
    final next = nextWarning(mm);
    return AppCard(
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s16,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpace.s12,
            runSpacing: AppSpace.s12,
            children: [
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpace.s4,
                  children: [
                    Text('最近測站 · ${station.name}', style: AppType.caption1.copyWith(color: AppPalette.foreground3)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      spacing: AppSpace.s8,
                      children: [
                        Text(
                          millimetersText(mm),
                          style: AppType.display.copyWith(color: AppPalette.foreground1, fontFeatures: AppType.tabular),
                        ),
                        Text('mm', style: AppType.subtitle1.copyWith(color: AppPalette.foreground2, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Text(
                      '今日累積 · 觀測 ${clockText(station.obsTime)}',
                      style: AppType.caption1.copyWith(color: AppPalette.foreground3, fontFeatures: AppType.tabular),
                    ),
                  ],
                ),
              RainLevelBadge(level: rainLevel(mm)),
            ],
          ),
          ),
          _ThresholdBar(mm: mm),
          MetricGrid(children: [
            MetricTile(icon: Icons.schedule, label: '近 1 小時', value: _millimetersWithUnitText(station.past1hrMm), onHero: true),
            MetricTile(icon: Icons.schedule, label: '近 3 小時', value: _millimetersWithUnitText(station.past3hrMm), onHero: true),
            if (next != null)
              MetricTile(
                icon: Icons.warning_amber_outlined,
                label: '距${next.name}門檻',
                value: _millimetersWithUnitText(next.remainingMillimeters),
                onHero: true,
              ),
            MetricTile(
              icon: Icons.water_drop_outlined,
              label: '目前',
              value: currentRainText(station.past10MinMm),
              onHero: true,
            ),
          ]),
        ],
      ),
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
