import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/data_display.dart';
import '../warnings/warning_style.dart';
import 'rainfall_logic.dart';

/// Fill colour of a rain level (`.lv-0` … `.lv-4`).
Color rainLevelColor(int level) => switch (level) {
      0 => AppPalette.brand140,
      1 || 2 || 3 || 4 => WarningLevelStyle.of(level).solid,
      _ => throw RangeError.range(level, 0, 4, 'level'),
    };

/// Level badge: text always accompanies the colour.
class RainLevelBadge extends StatelessWidget {
  const RainLevelBadge({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final tone = switch (level) {
      1 || 2 || 3 || 4 => WarningLevelStyle.of(level).tone,
      _ => BadgeTone.neutral,
    };
    return AppBadge(label: rainLevelNames[level], tone: tone);
  }
}
