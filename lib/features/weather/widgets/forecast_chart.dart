import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/taiwan_time.dart';
import '../../../data/models/weather_models.dart';
import 'chart_paint.dart';
import 'home_logic.dart';
import 'weather_format.dart';

const forecastAxisWidth = 40.0;

/// Chart rows in the mockup's SVG coordinates (y), 16 px per hour (x).
class ForecastChartGeometry {
  ForecastChartGeometry(this.slots, this.now, this.availableWidth)
    : origin = slots.first.startTime.isBefore(now) ? slots.first.startTime : now,
      end = slots.last.startTime.add(forecastSlotLength) {
    final temps = [
      for (final s in slots) ...[s.temperature, s.apparentTemperature],
    ].whereType<double>();
    tempMin = temps.isEmpty ? 0 : temps.reduce((a, b) => a < b ? a : b);
    tempMax = temps.isEmpty ? 0 : temps.reduce((a, b) => a > b ? a : b);
    final hours = end.difference(origin).inMinutes / Duration.minutesPerHour;
    pxPerHour = ((availableWidth - _padStart - _padEnd) / hours).clamp(_minPxPerHour, _maxPxPerHour);
  }

  /// Width of the chart cell; the chart fills it up to [_maxPxPerHour] and scrolls below [_minPxPerHour].
  final double availableWidth;
  late final double pxPerHour;
  bool get scrolls => width - availableWidth > _fitTolerance;

  /// Bar width: two thirds of a 3-hour slot.
  double get popWidth => forecastSlotLength.inMinutes / Duration.minutesPerHour * pxPerHour * 2 / 3;

  final List<HourlyForecast> slots;
  final DateTime now;
  final DateTime origin;
  final DateTime end;

  /// Range of every temperature and 體感 value; only read when such a value exists.
  late final double tempMin;
  late final double tempMax;

  static const height = 340.0;
  static const _minPxPerHour = 16.0;
  static const _maxPxPerHour = 32.0;
  static const _fitTolerance = 0.5;
  static const _padStart = 32.0;
  static const _padEnd = 24.0;
  static const dayLabelY = 14.0;
  static const slotLabelY = 34.0;
  static const iconTop = 44.0;
  static const nowTop = 44.0;
  static const nowBottom = 276.0;
  static const dayLineTop = 4.0;
  static const dayLineBottom = 336.0;
  static const dayLabelInset = 8.0;
  static const todayLabelInset = 24.0;
  static const tempTop = 96.0;
  static const tempBottom = 160.0;
  static const tempLabelOffset = 18.0;
  static const tickAxisY = 182.0;
  static const tickLength = 4.0;
  static const tickLabelY = 198.0;
  static const apparentLabelY = 216.0;
  static const popTop = 236.0;
  static const popHeight = 40.0;
  static const popLabelY = 292.0;
  static const windDirY = 312.0;
  static const windSpeedY = 328.0;

  double x(DateTime t) => _padStart + t.difference(origin).inMinutes / Duration.minutesPerHour * pxPerHour;

  double slotCenter(HourlyForecast s) => x(s.startTime.add(forecastSlotLength ~/ 2));

  double get width => x(end) + _padEnd;

  double tempY(double t) {
    if (tempMax == tempMin) return (tempTop + tempBottom) / 2;
    return tempBottom - (t - tempMin) / (tempMax - tempMin) * (tempBottom - tempTop);
  }
}

/// Fixed row titles left of the scrolling chart (`.fc72__axis`).
class ForecastAxisPainter extends CustomPainter {
  const ForecastAxisPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final style = AppType.caption1.copyWith(color: AppPalette.fg3);
    for (final (label, y) in [
      ('時段', ForecastChartGeometry.slotLabelY),
      ('天氣', ForecastChartGeometry.iconTop + AppSize.icon24 / 2),
      ('溫度', (ForecastChartGeometry.tempTop + ForecastChartGeometry.tempBottom) / 2),
      ('體感', ForecastChartGeometry.apparentLabelY),
      ('降雨', ForecastChartGeometry.popTop + ForecastChartGeometry.popHeight / 2),
      ('風', (ForecastChartGeometry.windDirY + ForecastChartGeometry.windSpeedY) / 2),
    ]) {
      paintLabel(canvas, label, Offset(0, y), style, anchor: TextAnchor.start);
    }
  }

  @override
  bool shouldRepaint(ForecastAxisPainter old) => false;
}

class ForecastChartPainter extends CustomPainter {
  ForecastChartPainter(this.g);

  final ForecastChartGeometry g;

  static const _tempStroke = 2.5;
  static const _apparentStroke = 1.5;
  static const _dotRadius = 3.0;
  static const _apparentGap = 3.0;
  static const _popRadius = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final small = AppType.caption2.copyWith(color: AppPalette.fg2, fontFeatures: AppType.tabular);
    final caption = AppType.caption1.copyWith(fontFeatures: AppType.tabular);
    final now = g.now;

    // Day boundaries (wall-clock midnights) and day labels.
    final firstWall = taiwanWall(g.origin);
    var day = DateTime.utc(firstWall.year, firstWall.month, firstWall.day);
    final nowX = g.x(now);
    final showNow = !now.isBefore(g.origin) && now.isBefore(g.end);
    paintLabel(
      canvas,
      _dayTitle(day, now),
      Offset(
        (showNow ? nowX : ForecastChartGeometry._padStart) + ForecastChartGeometry.todayLabelInset,
        ForecastChartGeometry.dayLabelY,
      ),
      caption.copyWith(color: AppPalette.fg1, fontWeight: FontWeight.w600),
      anchor: TextAnchor.start,
    );
    while (true) {
      day = day.add(const Duration(days: 1));
      final at = fromTaiwanWall(day);
      if (!at.isBefore(g.end)) break;
      final dx = g.x(at);
      canvas.drawPath(
        dashedPath(
          Path()
            ..moveTo(dx, ForecastChartGeometry.dayLineTop)
            ..lineTo(dx, ForecastChartGeometry.dayLineBottom),
          chartDash,
          chartDash,
        ),
        strokePaint(AppPalette.stroke1, AppStroke.thin),
      );
      paintLabel(
        canvas,
        _dayTitle(day, now),
        Offset(dx + ForecastChartGeometry.dayLabelInset, ForecastChartGeometry.dayLabelY),
        caption.copyWith(color: AppPalette.fg1, fontWeight: FontWeight.w600),
        anchor: TextAnchor.start,
      );
    }

    if (showNow) {
      canvas.drawLine(
        Offset(nowX, ForecastChartGeometry.nowTop),
        Offset(nowX, ForecastChartGeometry.nowBottom),
        strokePaint(AppPalette.brandFg, AppStroke.thick),
      );
      paintLabel(
        canvas,
        '現在',
        Offset(nowX, ForecastChartGeometry.dayLabelY),
        caption.copyWith(color: AppPalette.brandFg, fontWeight: FontWeight.w600),
      );
    }

    // Tick axis.
    canvas.drawLine(
      Offset(g.x(g.slots.first.startTime), ForecastChartGeometry.tickAxisY),
      Offset(g.x(g.slots.last.startTime), ForecastChartGeometry.tickAxisY),
      strokePaint(AppPalette.stroke1, AppStroke.thin),
    );

    // Lines: 體感 (dashed) under temperature.
    Path line(double? Function(HourlyForecast) value) {
      final path = Path();
      var started = false;
      for (final s in g.slots) {
        final v = value(s);
        if (v == null) {
          started = false;
          continue;
        }
        final p = Offset(g.x(s.startTime), g.tempY(v));
        started ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
        started = true;
      }
      return path;
    }

    canvas.drawPath(
      dashedPath(line((s) => s.apparentTemperature), chartDash, _apparentGap),
      strokePaint(AppPalette.fg4, _apparentStroke),
    );
    canvas.drawPath(line((s) => s.temperature), strokePaint(AppPalette.warningFg, _tempStroke));

    final halo = AppPalette.bg1;
    for (final s in g.slots) {
      final x = g.x(s.startTime);
      final wall = taiwanWall(s.startTime);
      final endWall = taiwanWall(s.startTime.add(forecastSlotLength));
      final center = g.slotCenter(s);

      paintLabel(
        canvas,
        '${twoDigits(wall.hour)}–${twoDigits(endWall.hour)}',
        Offset(center, ForecastChartGeometry.slotLabelY),
        caption.copyWith(color: AppPalette.fg2),
      );

      final t = s.temperature;
      if (t != null) {
        final c = Offset(x, g.tempY(t));
        canvas.drawCircle(c, _dotRadius, Paint()..color = AppPalette.bg1);
        canvas.drawCircle(c, _dotRadius, strokePaint(AppPalette.warningFg, AppStroke.thick));
        paintLabel(
          canvas,
          tempText(t),
          c.translate(0, ForecastChartGeometry.tempLabelOffset),
          caption.copyWith(color: AppPalette.fg1, fontWeight: FontWeight.w600),
          halo: halo,
        );
      }

      canvas.drawLine(
        Offset(x, ForecastChartGeometry.tickAxisY),
        Offset(x, ForecastChartGeometry.tickAxisY + ForecastChartGeometry.tickLength),
        strokePaint(AppPalette.stroke1, AppStroke.thin),
      );
      paintLabel(
        canvas,
        '${wall.hour}時',
        Offset(x, ForecastChartGeometry.tickLabelY),
        small.copyWith(color: AppPalette.fg4),
        halo: halo,
      );
      paintLabel(
        canvas,
        tempText(s.apparentTemperature),
        Offset(x, ForecastChartGeometry.apparentLabelY),
        small.copyWith(color: AppPalette.fg3),
        halo: halo,
      );

      final track = Rect.fromLTWH(
        center - g.popWidth / 2,
        ForecastChartGeometry.popTop,
        g.popWidth,
        ForecastChartGeometry.popHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(track, const Radius.circular(_popRadius)),
        Paint()..color = AppPalette.rainBarTrack,
      );
      final pop = s.pop;
      if (pop != null && pop > 0) {
        final h = ForecastChartGeometry.popHeight * pop / 100;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(track.left, track.bottom - h, track.width, h),
            const Radius.circular(_popRadius),
          ),
          Paint()..color = AppPalette.rainBar,
        );
      }
      paintLabel(
        canvas,
        percentText(pop),
        Offset(center, ForecastChartGeometry.popLabelY),
        popTextStyle(small, pop),
      );
      paintLabel(canvas, windDirectionLabel(s.windDirection), Offset(center, ForecastChartGeometry.windDirY), small);
      paintLabel(canvas, speedText(s.windSpeed), Offset(center, ForecastChartGeometry.windSpeedY), small);
    }
  }

  /// `今天 11/14（六）` for today…後天, `週二 11/17` beyond.
  String _dayTitle(DateTime wall, DateTime now) {
    final rel = relativeDay(wall, now);
    return dayOffset(wall, now) <= 2 ? '$rel ${monthDayWeekday(wall)}' : '$rel ${monthDay(wall)}';
  }

  @override
  bool shouldRepaint(ForecastChartPainter old) =>
      old.g.slots != g.slots || old.g.now != g.now || old.g.pxPerHour != g.pxPerHour;
}

/// Dashed 體感 legend key (`.fc72__key--at`).
class ForecastDashKeyPainter extends CustomPainter {
  const ForecastDashKeyPainter();


  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawPath(
      dashedPath(
        Path()
          ..moveTo(0, y)
          ..lineTo(size.width, y),
        chartDash,
        chartDash,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.thick
        ..color = AppPalette.fg4,
    );
  }

  @override
  bool shouldRepaint(ForecastDashKeyPainter old) => false;
}
