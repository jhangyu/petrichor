import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/data_display.dart';
import '../../../data/models/hazard_models.dart';
import '../../radar/radar_playback.dart';
import '../../radar/widgets/radar_map_view.dart';
import 'level_style.dart';
import 'rainfall_logic.dart';

String _mmText(double? mm) => mm == null ? '—' : '${formatMm(mm)} mm';

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
                    Text(
                      '最近測站 · ${station.name}',
                      style: AppType.caption1.copyWith(color: AppPalette.fg3),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      spacing: AppSpace.s8,
                      children: [
                        Text(
                          formatMm(mm),
                          style: AppType.display.copyWith(
                            color: AppPalette.fg1,
                            fontFeatures: AppType.tabular,
                          ),
                        ),
                        Text(
                          'mm',
                          style: AppType.subtitle1.copyWith(
                            color: AppPalette.fg2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '今日累積 · 觀測 ${formatTaiwanClock(station.obsTime)}',
                      style: AppType.caption1.copyWith(
                        color: AppPalette.fg3,
                        fontFeatures: AppType.tabular,
                      ),
                    ),
                  ],
                ),
                RainLevelBadge(level: rainLevel(mm)),
              ],
            ),
          ),
          _ThresholdBar(mm: mm),
          MetricGrid(
            children: [
              MetricTile(
                icon: Icons.schedule,
                label: '近 1 小時',
                value: _mmText(station.past1hrMm),
                onHero: true,
              ),
              MetricTile(
                icon: Icons.schedule,
                label: '近 3 小時',
                value: _mmText(station.past3hrMm),
                onHero: true,
              ),
              if (next != null)
                MetricTile(
                  icon: Icons.warning_amber_outlined,
                  label: '距${next.name}門檻',
                  value: _mmText(next.remainingMm),
                  onHero: true,
                ),
              MetricTile(
                icon: Icons.water_drop_outlined,
                label: '目前',
                value: currentRainText(station.past10MinMm),
                onHero: true,
              ),
            ],
          ),
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
    final labels = ['0', '大雨 80', '豪雨 200', '大豪雨 350'];
    final semantics = nextWarning(mm);
    return Semantics(
      label: semantics == null
          ? '已達超大豪雨門檻'
          : '警戒門檻：目前 ${formatMm(mm)} 毫米，距${semantics.name} ${formatMm(semantics.remainingMm)} 毫米',
      child: ExcludeSemantics(
        child: Column(
          spacing: AppSpace.s4,
          children: [
            LayoutBuilder(
              builder: (context, box) => Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.circular),
                    child: SizedBox(
                      height: AppSize.legendBar,
                      child: Row(
                        children: [
                          for (var i = 0; i < flexes.length; i++)
                            Expanded(
                              flex: flexes[i],
                              child: ColoredBox(color: rainLevelColor(i)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left:
                        box.maxWidth * thresholdMarkerFraction(mm) -
                        _markerWidth / 2,
                    top: -AppSpace.s4,
                    child: Container(
                      width: _markerWidth,
                      height: _markerHeight,
                      decoration: BoxDecoration(
                        color: AppPalette.fg1,
                        borderRadius: BorderRadius.circular(AppRadius.circular),
                        border: Border.all(
                          color: AppPalette.bg1,
                          width: AppStroke.thin,
                        ),
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
                      style: AppType.caption2.copyWith(
                        color: AppPalette.fg3,
                        fontFeatures: AppType.tabular,
                      ),
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

/// `累積雨量圖`: CWA's O-A0040-002 image over the base map, with a legend of CWA's own
/// colour scale (`AppPalette.rainfallMapScale`, sampled from the image's legend bar).
class RainfallMapCard extends StatelessWidget {
  const RainfallMapCard({
    super.key,
    required this.map,
    required this.latitude,
    required this.longitude,
  });

  final RainfallMap map;
  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final clock = formatTaiwanClock(map.obsTime);
    return AppCard(
      title: '累積雨量圖',
      meta: '今日 · $clock',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s16,
        children: [
          RadarMapView(
            chipIcon: Icons.schedule,
            chipText: '今日累積 $clock',
            semanticsLabel: '今日累積雨量圖',
            overlayImages: [
              OverlayImage(
                bounds: LatLngBounds(
                  LatLng(map.minLatitude, map.minLongitude),
                  LatLng(map.maxLatitude, map.maxLongitude),
                ),
                imageProvider: NetworkImage(map.imageUrl),
              ),
            ],
            me: LatLng(latitude, longitude),
          ),
          const _MapLegend(),
        ],
      ),
    );
  }
}

/// CWA accumulated-rainfall colour scale; every swatch is labelled with its mm band.
class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '累積雨量圖例（毫米）',
      child: Wrap(
        spacing: AppSpace.s12,
        runSpacing: AppSpace.s8,
        children: [
          for (var i = 0; i < rainfallMapScaleLabels.length; i++)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpace.s4,
              children: [
                Container(
                  width: AppSize.icon16,
                  height: AppSize.icon16,
                  decoration: BoxDecoration(
                    color: AppPalette.rainfallMapScale[i],
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                Text(
                  rainfallMapScaleLabels[i],
                  style: AppType.caption1.copyWith(color: AppPalette.fg2),
                ),
              ],
            ),
          Text(
            '單位：毫米',
            style: AppType.caption1.copyWith(color: AppPalette.fg3),
          ),
        ],
      ),
    );
  }
}
