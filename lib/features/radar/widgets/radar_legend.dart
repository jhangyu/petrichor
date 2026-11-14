import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/radar/radar_echo_stats.dart';

/// dBZ legend steps: colour (data-vis tokens), tick label, intensity word.
const _steps = [
  (AppPalette.dbz0, '0', '微弱'),
  (AppPalette.dbz10, '10', '小雨'),
  (AppPalette.dbz20, '20', '中雨'),
  (AppPalette.dbz30, '30', '大雨'),
  (AppPalette.dbz40, '40', '豪雨'),
  (AppPalette.dbz50, '50', '強降雨'),
  (AppPalette.dbz60, '60+', '冰雹'),
];

/// Colour name of each legend step, as the hero says it (「最強約 45 dBZ（橙）」).
const _colourNames = ['淺藍', '藍', '綠', '黃', '橙', '紅', '紫'];

int _stepOf(int dbz) => (dbz ~/ radarDbzBandWidth).clamp(0, _steps.length - 1);

/// Legend colour of the step containing [dbz].
Color radarDbzColour(int dbz) => _steps[_stepOf(dbz)].$1;

/// Legend colour name of the step containing [dbz].
String radarDbzColourName(int dbz) => _colourNames[_stepOf(dbz)];

/// `.legend`: 回波強度 dBZ bar with numbers; [showWords] adds the intensity
/// words under each number (full legend on the default frame).
class RadarLegend extends StatelessWidget {
  const RadarLegend({super.key, required this.showWords});

  final bool showWords;

  @override
  Widget build(BuildContext context) {
    final caption = AppType.caption2.copyWith(color: AppPalette.fg3);
    Widget row(List<Widget> cells) => Row(children: [for (final c in cells) Expanded(child: c)]);
    return Semantics(
      label: '雷達回波強度圖例',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s4,
        children: [
          if (showWords)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '回波強度',
                  style: AppType.caption1.copyWith(color: AppPalette.fg2, fontWeight: FontWeight.w600),
                ),
                Text('dBZ', style: caption),
              ],
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.circular),
            child: SizedBox(
              height: AppSize.legendBar,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final (color, _, _) in _steps) Expanded(child: ColoredBox(color: color))],
              ),
            ),
          ),
          row([
            for (final (_, tick, _) in _steps)
              Text(
                tick,
                textAlign: TextAlign.center,
                style: caption.copyWith(fontFeatures: AppType.tabular),
              ),
          ]),
          if (showWords)
            row([for (final (_, _, word) in _steps) Text(word, textAlign: TextAlign.center, style: caption)]),
        ],
      ),
    );
  }
}
