import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

enum WeatherGlyph { sun, partly, cloud, rain, thunder, fog, snow, unknown }

/// Buckets a CWA 天氣現象 text (forecast Wx or observation Weather) into an icon.
/// Precipitation wins over sky cover (「多雲短暫雨」 → rain).
WeatherGlyph weatherGlyph(String? text) {
  if (text == null) return WeatherGlyph.unknown;
  bool has(String s) => text.contains(s);
  if (has('雷')) return WeatherGlyph.thunder;
  if (has('雪')) return WeatherGlyph.snow;
  if (has('雨')) return WeatherGlyph.rain;
  if (has('霧') || has('霾') || has('靄')) return WeatherGlyph.fog;
  final cloudy = has('雲') || has('陰');
  if (has('晴')) return cloudy ? WeatherGlyph.partly : WeatherGlyph.sun;
  if (cloudy) return WeatherGlyph.cloud;
  return WeatherGlyph.unknown;
}

/// Icon and tint for a [WeatherGlyph] (`.icon--sun/cloud/rain/thunder/fog`).
(IconData, Color) weatherGlyphStyle(WeatherGlyph glyph) => switch (glyph) {
  WeatherGlyph.sun => (Icons.wb_sunny_outlined, AppPalette.iconSun),
  WeatherGlyph.partly => (Icons.wb_cloudy_outlined, AppPalette.iconSun),
  WeatherGlyph.cloud => (Icons.cloud_outlined, AppPalette.iconCloud),
  WeatherGlyph.rain => (Icons.umbrella_outlined, AppPalette.iconRain),
  WeatherGlyph.thunder => (Icons.thunderstorm, AppPalette.iconThunder),
  WeatherGlyph.fog => (Icons.foggy, AppPalette.iconFog),
  WeatherGlyph.snow => (Icons.ac_unit, AppPalette.iconRain),
  WeatherGlyph.unknown => (Icons.help_outline, AppPalette.foreground3),
};

/// Weather icon for a CWA 天氣現象 text; [text] is the semantics label.
/// [night] swaps the sun glyphs for moon glyphs (sun → moon, partly → moon-partly).
class WeatherGlyphIcon extends StatelessWidget {
  const WeatherGlyphIcon({super.key, required this.text, required this.size, this.night = false});

  final String? text;
  final double size;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final glyph = weatherGlyph(text);
    final (icon, color) = switch (glyph) {
      WeatherGlyph.sun when night => (Icons.nightlight_outlined, AppPalette.brandForeground),
      WeatherGlyph.partly when night => (Icons.nights_stay_outlined, AppPalette.brandForeground),
      _ => weatherGlyphStyle(glyph),
    };
    return Icon(icon, size: size, color: color, semanticLabel: text);
  }
}
