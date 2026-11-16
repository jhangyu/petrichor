import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/taiwan_time.dart';
import '../../../data/models/weather_models.dart';
import 'chart_paint.dart';
import 'sun_now.dart';
import 'weather_format.dart';
import 'weather_glyph_icon.dart';

/// Widest the sky arc grows (`.sky` max-width 360).
const skyMaxWidth = 360.0;

/// Temperature, weather text and 高/低 (`.sky__temp` content).
class TemperatureBlock extends StatelessWidget {
  const TemperatureBlock({super.key, required this.observation, this.crossAxisAlignment = CrossAxisAlignment.center});

  final CurrentWeather observation;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final c = observation;
    Widget hilo(String label, double? value, Color color) => Text(
      '$label ${tempText(value)}',
      style: AppType.caption1.copyWith(color: color, fontWeight: FontWeight.w600, fontFeatures: AppType.tabular),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          tempText(c.temperature),
          style: AppType.display.copyWith(color: AppPalette.fg1, fontFeatures: AppType.tabular),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: AppSpace.s8,
          children: [
            Text(c.weather ?? '—', style: AppType.body1.copyWith(color: AppPalette.fg2)),
            hilo('高', c.dailyHigh, AppPalette.tempHot),
            hilo('低', c.dailyLow, AppPalette.tempCold),
          ],
        ),
      ],
    );
  }
}

/// `.sky`: the sun arc (painted) with the glyph + 仰角 pill riding the sun
/// position and the temperature block centred in the dome.
class SkyArc extends StatelessWidget {
  const SkyArc({super.key, required this.observation, required this.sun});

  final CurrentWeather observation;
  final SunNow sun;

  @override
  Widget build(BuildContext context) {
    final night = sun.isNight;
    final day = sun.day;
    final weather = observation.weather;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: skyMaxWidth),
        child: AspectRatio(
          aspectRatio: _SkyGeometry.viewWidth / _SkyGeometry.viewHeight,
          child: LayoutBuilder(
            builder: (context, box) {
              final geometry = _SkyGeometry(box.maxWidth / _SkyGeometry.viewWidth);
              final at = geometry.sun(sun);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Semantics(
                      label:
                          '太陽位置：現在仰角 ${sun.elevationDegrees} 度，${night ? '夜間' : '白天'}；'
                          '過中天 ${clockText(day.transit)}，最高仰角 ${day.transitAltitudeDegrees} 度；'
                          '目前天氣${weather ?? '不明'}',
                      child: CustomPaint(painter: _SkyPainter(geometry: geometry, sun: sun)),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: box.maxHeight * _SkyGeometry.temperatureBottomShare,
                    child: Center(child: TemperatureBlock(observation: observation)),
                  ),
                  Positioned(
                    left: at.dx,
                    top: at.dy,
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, -0.5),
                      child: _Pill(weather: weather, elevation: sun.elevationDegrees, night: night),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// `.sky__pill`: weather glyph (moon at night) + current 仰角.
class _Pill extends StatelessWidget {
  const _Pill({required this.weather, required this.elevation, required this.night});

  final String? weather;
  final int elevation;
  final bool night;

  static const _height = 30.0;

  @override
  Widget build(BuildContext context) {
    // U+2212 minus sign, as in the mockup (「−61°」).
    final degrees = elevation < 0 ? '−${-elevation}°' : '$elevation°';
    return Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
      decoration: BoxDecoration(
        color: AppPalette.bg1,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: night ? AppPalette.stroke1 : AppPalette.iconSun, width: AppStroke.thin),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpace.s4,
        children: [
          WeatherGlyphIcon(text: weather, size: AppSize.icon20, night: night),
          Text(
            degrees,
            style: AppType.body1Strong.copyWith(
              color: night ? AppPalette.fg2 : AppPalette.fg1,
              fontFeatures: AppType.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mockup view box 320 × 200 scaled by [scale]: day dome east (left) → west
/// (right) above the horizon, shallow night arc west → east below it.
class _SkyGeometry {
  _SkyGeometry(this.scale);

  final double scale;

  static const viewWidth = 320.0;
  static const viewHeight = 200.0;
  static const _cx = 160.0;
  static const horizonY = 156.0;
  static const _rx = 136.0;
  static const _dayRy = 120.0;
  static const _nightRy = 24.0;
  static const horizonInset = 4.0;
  static const labelY = 13.0;

  /// `.sky__temp` bottom: 26 % of the arc height.
  static const temperatureBottomShare = 0.26;

  Offset view(double x, double y) => Offset(x * scale, y * scale);

  /// Point on the day dome at [f] (0 = sunrise, east; 1 = sunset, west).
  Offset day(double f) {
    final a = math.pi * f;
    return view(_cx - _rx * math.cos(a), horizonY - _dayRy * math.sin(a));
  }

  /// Point on the night arc at [f] (0 = sunset, west; 1 = sunrise, east).
  Offset night(double f) {
    final a = math.pi * f;
    return view(_cx + _rx * math.cos(a), horizonY + _nightRy * math.sin(a));
  }

  Offset sun(SunNow s) => s.isNight ? night(s.arcFraction) : day(s.arcFraction);

  /// Day dome between fractions [from] and [to].
  Path dayArc(double from, double to) {
    final rect = Rect.fromCenter(center: view(_cx, horizonY), width: 2 * _rx * scale, height: 2 * _dayRy * scale);
    return Path()..addArc(rect, math.pi + from * math.pi, (to - from) * math.pi);
  }

  /// Night arc between fractions [from] and [to] (clockwise from the west end).
  Path nightArc(double from, double to) {
    final rect = Rect.fromCenter(center: view(_cx, horizonY), width: 2 * _rx * scale, height: 2 * _nightRy * scale);
    return Path()..addArc(rect, from * math.pi, (to - from) * math.pi);
  }
}

/// Horizon, compass, day dome, night arc, 過中天 mark and the sun dot.
/// Strokes and labels keep their size; only positions scale with the card.
class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.geometry, required this.sun});

  final _SkyGeometry geometry;
  final SunNow sun;

  static const _nightDash = 2.0;
  static const _transitTick = 4.0;
  static const _transitRadius = 3.0;
  static const _endRadius = 4.0;
  static const _sunRadius = 5.0;
  static const _compassInset = 11.0;
  static const _compassY = 150.0;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    Paint fill(Color c) => Paint()..color = c;
    void ring(Offset c, double r, Color edge, double w) {
      canvas.drawCircle(c, r, fill(AppPalette.bg1));
      canvas.drawCircle(c, r, strokePaint(edge, w));
    }

    canvas.drawLine(
      g.view(_SkyGeometry.horizonInset, _SkyGeometry.horizonY),
      g.view(_SkyGeometry.viewWidth - _SkyGeometry.horizonInset, _SkyGeometry.horizonY),
      strokePaint(AppPalette.stroke1, AppStroke.thin),
    );

    final night = sun.isNight;
    final f = sun.arcFraction;
    final dayTodo = strokePaint(AppPalette.stroke1, AppStroke.thick);
    final nightTodo = strokePaint(AppPalette.stroke2, AppStroke.thin);
    if (night) {
      canvas.drawPath(dashedPath(g.dayArc(0, 1), chartDash, chartDash), dayTodo);
      canvas.drawPath(dashedPath(g.nightArc(f, 1), _nightDash, chartDash), nightTodo);
      if (f > 0) canvas.drawPath(g.nightArc(0, f), strokePaint(AppPalette.brand120, AppStroke.thick));
    } else {
      canvas.drawPath(dashedPath(g.nightArc(0, 1), _nightDash, chartDash), nightTodo);
      canvas.drawPath(dashedPath(g.dayArc(f, 1), chartDash, chartDash), dayTodo);
      if (f > 0) canvas.drawPath(g.dayArc(0, f), strokePaint(AppPalette.iconSun, AppStroke.thicker));
    }

    final compass = AppType.caption2.copyWith(color: AppPalette.fg3);
    final compassY = _compassY * g.scale;
    paintLabel(canvas, '東', Offset(_compassInset * g.scale, compassY), compass);
    paintLabel(canvas, '西', Offset((_SkyGeometry.viewWidth - _compassInset) * g.scale, compassY), compass);

    final day = sun.day;
    final transit = g.day(
      day.transit.difference(day.sunrise).inSeconds / day.sunset.difference(day.sunrise).inSeconds,
    );
    final markColor = night ? AppPalette.fg4 : AppPalette.iconSun;
    canvas.drawLine(
      transit - const Offset(0, _transitTick),
      transit + const Offset(0, _transitTick),
      strokePaint(markColor, AppStroke.thin),
    );
    ring(transit, _transitRadius, markColor, AppStroke.thick);
    paintLabel(
      canvas,
      '過中天 ${clockText(day.transit)} · 最高 ${day.transitAltitudeDegrees}°',
      Offset(transit.dx, _SkyGeometry.labelY * g.scale),
      AppType.caption1.copyWith(color: AppPalette.fg2, fontFeatures: AppType.tabular),
    );

    ring(g.day(0), _endRadius, AppPalette.fg3, AppStroke.thin);
    ring(g.day(1), _endRadius, AppPalette.fg3, AppStroke.thin);
    canvas.drawCircle(g.sun(sun), _sunRadius, fill(night ? AppPalette.brand120 : AppPalette.iconSun));
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.geometry.scale != geometry.scale || old.sun != sun;
}
