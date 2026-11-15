import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/radar/radar_echo_stats.dart';

int _clampDbz(int dbz) => dbz.clamp(0, AppPalette.dbzScale.length - 1);

/// CWA legend colour of [dbz].
Color radarDbzColour(int dbz) => AppPalette.dbzScale[_clampDbz(dbz)];

/// `.legend` (compact): dBZ bar with numbers. The bar draws every CWA colour
/// (1 dBZ each); each number sits under its 10 dBZ band.
class RadarLegend extends StatelessWidget {
  const RadarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final caption = AppType.caption2.copyWith(color: AppPalette.fg3);
    final scale = AppPalette.dbzScale.length;
    return Semantics(
      label: '雷達回波強度圖例',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s4,
        children: [
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
          Row(
            children: [
              for (var start = 0; start < scale; start += radarDbzBandWidth)
                Expanded(
                  // The top band is narrower (60–65): its number reads 「60+」.
                  flex: min(radarDbzBandWidth, scale - start),
                  child: Text(
                    scale - start < radarDbzBandWidth ? '$start+' : '$start',
                    textAlign: TextAlign.center,
                    style: caption.copyWith(fontFeatures: AppType.tabular),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

