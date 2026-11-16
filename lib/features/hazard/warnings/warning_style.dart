import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/data_display.dart';
import 'warning_groups.dart';

/// Colours of one warning level (`.warn--N`); level null = informational (`.warn--info`).
class WarningLevelStyle {
  final Color bg;
  final Color fg;
  final Color stroke;
  final Color solid;
  final BadgeTone tone;

  const WarningLevelStyle._(this.bg, this.fg, this.stroke, this.solid, this.tone);

  static const _info = WarningLevelStyle._(
      AppPalette.infoBackground, AppPalette.infoForeground, AppPalette.infoStroke, AppPalette.infoSolid, BadgeTone.rain);

  factory WarningLevelStyle.of(int? level) => switch (level) {
        1 => const WarningLevelStyle._(
            AppPalette.alert1Background, AppPalette.alert1Foreground, AppPalette.alert1Stroke, AppPalette.alert1Solid, BadgeTone.alert1),
        2 => const WarningLevelStyle._(
            AppPalette.alert2Background, AppPalette.alert2Foreground, AppPalette.alert2Stroke, AppPalette.alert2Solid, BadgeTone.alert2),
        3 => const WarningLevelStyle._(
            AppPalette.alert3Background, AppPalette.alert3Foreground, AppPalette.alert3Stroke, AppPalette.alert3Solid, BadgeTone.alert3),
        4 => const WarningLevelStyle._(
            AppPalette.alert4Background, AppPalette.alert4Foreground, AppPalette.alert4Stroke, AppPalette.alert4Solid, BadgeTone.alert4),
        _ => _info,
      };
}

/// Icon by warning name (`i-thunder`, `i-rain`, `i-thermo`, else the generic warning glyph).
IconData warningIcon(WarningGroup group) {
  final name = group.name;
  if (name.contains('豪雨')) return Icons.thunderstorm_outlined;
  if (name.contains('大雨')) return Icons.grain;
  if (name.contains('低溫')) return Icons.thermostat;
  if (name.contains('風')) return Icons.air;
  if (name.contains('霧')) return Icons.foggy;
  return Icons.warning_amber_outlined;
}
