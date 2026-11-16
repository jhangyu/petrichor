import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/status.dart';
import '../radar_provider.dart'
    show radarOpacityDefaultPercent, radarOpacityMaxPercent, radarOpacityMinPercent, radarOpacityStepPercent;

/// Slider look shared by the playback timeline and the opacity slider.
const radarSliderTheme = SliderThemeData(
  trackHeight: AppSize.sliderTrack,
  activeTrackColor: AppPalette.brandBg,
  inactiveTrackColor: AppPalette.strokeAccessible,
  thumbColor: AppPalette.brandBg,
  overlayColor: AppPalette.brandBgSubtle,
  thumbShape: RoundSliderThumbShape(enabledThumbRadius: AppSize.sliderThumb / 2),
);

/// `.slider`: 疊圖透明度 10–100 % (the [PlaybackCard.opacity] content).
class RadarOpacitySlider extends StatelessWidget {
  const RadarOpacitySlider({super.key, required this.percent, required this.onChanged});

  final int percent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s4,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('疊圖透明度', style: AppType.body1.copyWith(color: AppPalette.fg1)),
            Text(
              '$percent%',
              style: AppType.body1.copyWith(
                color: AppPalette.fg1,
                fontWeight: FontWeight.w600,
                fontFeatures: AppType.tabular,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: radarSliderTheme,
          child: Slider(
            min: radarOpacityMinPercent.toDouble(),
            max: radarOpacityMaxPercent.toDouble(),
            divisions: (radarOpacityMaxPercent - radarOpacityMinPercent) ~/ radarOpacityStepPercent,
            value: percent.toDouble(),
            semanticFormatterCallback: (_) => '疊圖透明度',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final v in const [radarOpacityMinPercent, radarOpacityMaxPercent])
              Text('$v%', style: AppType.caption1.copyWith(color: AppPalette.fg3)),
          ],
        ),
      ],
    );
  }
}

/// Shown above the map when the opacity setting failed: unreadable saved value
/// ([overlayHidden]: the overlay is hidden until reset) or a failed save (the
/// overlay stays drawn with the value chosen this session).
class RadarOpacityErrorBanner extends StatelessWidget {
  const RadarOpacityErrorBanner({super.key, required this.error, required this.overlayHidden, required this.onReset});

  final Object error;
  final bool overlayHidden;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return StatusBanner(
      tone: StatusTone.error,
      title: overlayHidden ? '雷達疊圖已隱藏：儲存的透明度設定無法讀取' : '透明度設定無法儲存：本次使用中的值仍有效，重新啟動後會恢復',
      text: overlayHidden ? '$error。重設後即可再顯示雷達疊圖。' : '$error。重設會再試一次儲存。',
      actions: [AppButton(label: '重設為 $radarOpacityDefaultPercent%', small: true, onPressed: onReset)],
    );
  }
}
