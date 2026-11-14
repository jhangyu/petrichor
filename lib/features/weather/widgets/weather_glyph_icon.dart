import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import 'home_logic.dart';

/// Icon and tint for a [WeatherGlyph] (`.icon--sun/cloud/rain/thunder/fog`).
(IconData, Color) weatherGlyphStyle(WeatherGlyph glyph) => switch (glyph) {
  WeatherGlyph.sun => (Icons.wb_sunny_outlined, AppPalette.iconSun),
  WeatherGlyph.partly => (Icons.wb_cloudy_outlined, AppPalette.iconSun),
  WeatherGlyph.cloud => (Icons.cloud_outlined, AppPalette.iconCloud),
  WeatherGlyph.rain => (Icons.umbrella_outlined, AppPalette.iconRain),
  WeatherGlyph.thunder => (Icons.thunderstorm, AppPalette.iconThunder),
  WeatherGlyph.fog => (Icons.foggy, AppPalette.iconFog),
  WeatherGlyph.snow => (Icons.ac_unit, AppPalette.iconRain),
  WeatherGlyph.unknown => (Icons.help_outline, AppPalette.fg3),
};

/// Weather icon for a CWA 天氣現象 text; [text] is the semantics label.
class WeatherGlyphIcon extends StatelessWidget {
  const WeatherGlyphIcon({super.key, required this.text, required this.size});

  final String? text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = weatherGlyphStyle(weatherGlyph(text));
    return Icon(icon, size: size, color: color, semanticLabel: text);
  }
}
