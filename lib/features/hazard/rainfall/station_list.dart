import 'package:flutter/material.dart';

import '../../../core/layout/adaptive.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choices.dart';
import '../../../data/models/hazard_models.dart';
import 'level_style.dart';
import 'rainfall_logic.dart';

/// Rows shown before 「顯示全部」.
const _collapsedRowCount = 6;

/// Bar full width = the top warning threshold.
final _barFullMm = rainWarningThresholds.last;

/// `測站今日累積雨量` flush card: sort button, county chips + station rows.
/// Starts on [county] (the current place's county; null without a place = all counties); the chips switch to any county or all.
class StationListCard extends StatefulWidget {
  const StationListCard({super.key, required this.county, required this.stations, required this.nearestId});

  final String? county;

  /// Every station of the dataset (all counties).
  final List<RainStation> stations;

  /// Nearest station to the current place; null without a place.
  final String? nearestId;

  @override
  State<StationListCard> createState() => _StationListCardState();
}

class _StationListCardState extends State<StationListCard> {
  StationSort _sort = StationSort.rainfall;
  bool _expanded = false;

  /// Selected county; null = 全部縣市.
  late String? _county = widget.county;

  @override
  void didUpdateWidget(StationListCard old) {
    super.didUpdateWidget(old);
    if (old.county != widget.county) {
      _county = widget.county;
      _expanded = false;
    }
  }

  void _toggleSort() => setState(() {
    _sort = _sort == StationSort.rainfall ? StationSort.name : StationSort.rainfall;
  });

  void _selectCounty(String? county) => setState(() {
    _county = county;
    _expanded = false;
  });

  @override
  Widget build(BuildContext context) {
    final counties = countyChipOrder(widget.stations, widget.county);
    final inScope = _county == null ? widget.stations : widget.stations.where((s) => s.county == _county).toList();
    final sorted = sortStations(inScope, _sort);
    final sortLabel = _sort == StationSort.rainfall ? '雨量高到低' : '站名';
    return AppCard(
      flush: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= AppLayout.cardWideWidth;
          final columns = AppGrid.columnsFor(
            box.maxWidth,
            spanUnits: sorted.length,
            minColumnWidth: AppLayout.paneMinWidth,
          );
          final chips = [
            AppChip(label: '全部縣市', selected: _county == null, onTap: () => _selectCounty(null)),
            for (final c in counties) AppChip(label: c, selected: _county == c, onTap: () => _selectCounty(c)),
          ];
          final collapsed = columns * _collapsedRowCount;
          final visible = _expanded ? sorted : sorted.take(collapsed).toList();
          final rows = [for (final s in visible) _StationRow(station: s, isNearest: s.id == widget.nearestId)];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(AppSpace.s16, AppSpace.s16, AppSpace.s16, AppSpace.s12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppPalette.stroke3, width: AppStroke.thin),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpace.s12,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: AppSpace.s4,
                            children: [
                              Text('測站今日累積雨量', style: AppType.subtitle1.copyWith(color: AppPalette.fg1)),
                              Text(
                                '${_county ?? '全部縣市'} · ${sorted.length} 站 · 依$sortLabel',
                                style: AppType.caption1.copyWith(color: AppPalette.fg3),
                              ),
                            ],
                          ),
                        ),
                        AppButton(
                          label: '排序',
                          icon: Icons.tune,
                          variant: AppButtonVariant.subtle,
                          small: true,
                          onPressed: _toggleSort,
                        ),
                      ],
                    ),
                    if (wide)
                      Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8, children: chips)
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(spacing: AppSpace.s8, children: chips),
                      ),
                  ],
                ),
              ),
              if (columns > 1)
                Padding(
                  padding: const EdgeInsets.all(AppSpace.s16),
                  child: AppGrid(minColumnWidth: AppLayout.paneMinWidth, children: rows),
                )
              else
                ...rows,
              if (sorted.length > collapsed)
                Container(
                  padding: const EdgeInsets.fromLTRB(AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s12),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppPalette.stroke3, width: AppStroke.thin),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: AppButton(
                    label: _expanded ? '收合' : '顯示全部 ${sorted.length} 站',
                    icon: _expanded ? Icons.expand_less : Icons.expand_more,
                    variant: AppButtonVariant.subtle,
                    small: true,
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StationRow extends StatelessWidget {
  const _StationRow({required this.station, required this.isNearest});

  final RainStation station;
  final bool isNearest;

  @override
  Widget build(BuildContext context) {
    final mm = station.todayMm;
    final level = mm == null ? null : rainLevel(mm);
    final place = '${station.county} ${station.town}${isNearest ? ' · 目前位置' : ''}';
    return Container(
      color: isNearest ? AppPalette.brandBgSubtle : AppPalette.bg1,
      constraints: const BoxConstraints(minHeight: AppSize.touch),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s12),
      child: Row(
        spacing: AppSpace.s12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpace.s4,
              children: [
                Text(
                  station.name,
                  style: AppType.body1Strong.copyWith(color: isNearest ? AppPalette.brandFgStrong : AppPalette.fg1),
                ),
                Text(place, style: AppType.caption1.copyWith(color: AppPalette.fg3)),
                if (mm != null && level != null) _LevelBar(fraction: (mm / _barFullMm).clamp(0, 1), level: level),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: AppSize.icon64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: AppSpace.s4,
              children: [
                Text.rich(
                  TextSpan(
                    text: '${formatMm(mm)} ',
                    style: AppType.body2.copyWith(
                      color: AppPalette.fg1,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppType.tabular,
                    ),
                    children: [
                      TextSpan(
                        text: 'mm',
                        style: AppType.caption1.copyWith(color: AppPalette.fg3, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                if (level == null) const _NoValueBadge() else RainLevelBadge(level: level),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoValueBadge extends StatelessWidget {
  const _NoValueBadge();

  @override
  Widget build(BuildContext context) => Text('無資料', style: AppType.caption1.copyWith(color: AppPalette.fg3));
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.fraction, required this.level});

  final double fraction;
  final int level;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        height: AppSize.sliderTrack,
        color: AppPalette.bg4,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction,
          child: ColoredBox(color: rainLevelColor(level)),
        ),
      ),
    );
  }
}
