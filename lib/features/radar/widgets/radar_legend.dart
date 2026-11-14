import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/radar/radar_echo_stats.dart';

/// Intensity word under each 10 dBZ tick, lowest band first.
const _bandWords = ['微弱', '小雨', '中雨', '大雨', '豪雨', '強降雨', '冰雹'];

/// Colour names of the CWA scale ([AppPalette.dbzScale]) by hue family:
/// (highest dBZ of the family, name). 0–5 cyan, 6–14 blue, 15–25 green,
/// 26–29 yellow-green, 30–35 yellow, 36–44 orange (ffb800–ff1800),
/// 45–55 red (ff0000–960000), 56–59 magenta-red, 60–65 purple.
const _colourNames = [
  (5, '淺藍'),
  (14, '藍'),
  (25, '綠'),
  (29, '黃綠'),
  (35, '黃'),
  (44, '橙'),
  (55, '紅'),
  (59, '紫紅'),
  (65, '紫'),
];

int _clampDbz(int dbz) => dbz.clamp(0, AppPalette.dbzScale.length - 1);

/// CWA legend colour of [dbz].
Color radarDbzColour(int dbz) => AppPalette.dbzScale[_clampDbz(dbz)];

/// Name of the CWA legend colour of [dbz], as the hero says it (「最強約 45 dBZ（紅）」).
String radarDbzColourName(int dbz) => _colourNames.firstWhere((e) => _clampDbz(dbz) <= e.$1).$2;

/// `.legend`: 回波強度 dBZ bar with numbers; [showWords] adds the intensity
/// words under each number (full legend on the default frame). The bar draws
/// every CWA colour (1 dBZ each); ticks and words sit under their 10 dBZ band.
class RadarLegend extends StatelessWidget {
  const RadarLegend({super.key, required this.showWords});

  final bool showWords;

  @override
  Widget build(BuildContext context) {
    final caption = AppType.caption2.copyWith(color: AppPalette.fg3);
    final scale = AppPalette.dbzScale.length;
    final bands = [
      for (var b = 0; b < _bandWords.length; b++)
        (
          start: b * radarDbzBandWidth,
          width: (scale - b * radarDbzBandWidth).clamp(0, radarDbzBandWidth),
          word: _bandWords[b],
        ),
    ];
    Widget row(List<(int, Widget)> cells) =>
        Row(children: [for (final (flex, c) in cells) Expanded(flex: flex, child: c)]);
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
                children: [for (final color in AppPalette.dbzScale) Expanded(child: ColoredBox(color: color))],
              ),
            ),
          ),
          row([
            for (final b in bands)
              (
                b.width,
                Text(
                  b.width < radarDbzBandWidth ? '${b.start}+' : '${b.start}',
                  textAlign: TextAlign.center,
                  style: caption.copyWith(fontFeatures: AppType.tabular),
                ),
              ),
          ]),
          if (showWords)
            row([for (final b in bands) (b.width, Text(b.word, textAlign: TextAlign.center, style: caption))]),
        ],
      ),
    );
  }
}
