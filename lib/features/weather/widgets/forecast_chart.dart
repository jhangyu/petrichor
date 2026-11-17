import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/taiwan_time.dart';
import '../../../data/models/weather_models.dart';
import 'chart_paint.dart';
import '../weather_logic.dart';
import '../../../core/format/weather_format.dart';

const forecastAxisWidth = 40.0;

/// Chart rows in the mockup's SVG coordinates (y), 16 px per hour (x).
class ForecastChartGeometry {
  ForecastChartGeometry(this.slots, this.now, this.availableWidth)
    : origin = slots.first.startTime.isBefore(now) ? slots.first.startTime : now,
      end = slots.last.startTime.add(forecastSlotLength) {
    final temps = [
      for (final s in slots) ...[s.temperature, s.apparentTemperature],
    ].whereType<double>();
    lowestTemperature = temps.isEmpty ? 0 : temps.reduce((a, b) => a < b ? a : b);
    highestTemperature = temps.isEmpty ? 0 : temps.reduce((a, b) => a > b ? a : b);
    final hours = end.difference(origin).inMinutes / Duration.minutesPerHour;
    pixelsPerHour = ((availableWidth - _padStart - _padEnd) / hours).clamp(_minPixelsPerHour, _maxPixelsPerHour);
  }

  /// Width of the chart cell; the chart fills it up to [_maxPixelsPerHour] and scrolls below [_minPixelsPerHour].
  final double availableWidth;
  late final double pixelsPerHour;
  bool get scrolls => width - availableWidth > _fitTolerance;

  /// Bar width: two thirds of a 3-hour slot.
  double get rainProbabilityWidth => forecastSlotLength.inMinutes / Duration.minutesPerHour * pixelsPerHour * 2 / 3;

  final List<HourlyForecast> slots;
  final DateTime now;
  final DateTime origin;
  final DateTime end;

  /// Range of every temperature and 體感 value; only read when such a value exists.
  late final double lowestTemperature;
  late final double highestTemperature;

  static const height = 340.0;
  static const _minPixelsPerHour = 16.0;
  static const _maxPixelsPerHour = 32.0;
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
  static const temperatureTop = 96.0;
  static const temperatureBottom = 160.0;
  static const temperatureLabelOffset = 18.0;
  static const tickAxisY = 182.0;
  static const tickLength = 4.0;
  static const tickLabelY = 198.0;
  static const apparentLabelY = 216.0;
  static const rainProbabilityTop = 236.0;
  static const rainProbabilityHeight = 40.0;
  static const rainProbabilityLabelY = 292.0;
  static const windDirectionY = 312.0;
  static const windSpeedY = 328.0;

  double x(DateTime t) => _padStart + t.difference(origin).inMinutes / Duration.minutesPerHour * pixelsPerHour;

  double slotCenter(HourlyForecast s) => x(s.startTime.add(forecastSlotLength ~/ 2));

  double get width => x(end) + _padEnd;

  double temperatureY(double t) {
    if (highestTemperature == lowestTemperature) return (temperatureTop + temperatureBottom) / 2;
    return temperatureBottom - (t - lowestTemperature) / (highestTemperature - lowestTemperature) * (temperatureBottom - temperatureTop);
  }
}

/// Fixed row titles left of the scrolling chart (`.fc72__axis`).
class ForecastAxisPainter extends CustomPainter {
  const ForecastAxisPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final style = AppType.caption1.copyWith(color: AppPalette.foreground3);
    for (final (label, y) in [
      ('時段', ForecastChartGeometry.slotLabelY),
      ('天氣', ForecastChartGeometry.iconTop + AppSize.icon24 / 2),
      ('溫度', (ForecastChartGeometry.temperatureTop + ForecastChartGeometry.temperatureBottom) / 2),
      ('體感', ForecastChartGeometry.apparentLabelY),
      ('降雨', ForecastChartGeometry.rainProbabilityTop + ForecastChartGeometry.rainProbabilityHeight / 2),
      ('風', (ForecastChartGeometry.windDirectionY + ForecastChartGeometry.windSpeedY) / 2),
    ]) {
      paintLabel(canvas, label, Offset(0, y), style, anchor: LabelAnchor.start);
    }
  }

  @override
  bool shouldRepaint(ForecastAxisPainter old) => false;
}

class ForecastChartPainter extends CustomPainter {
  ForecastChartPainter(this.geometry);

  final ForecastChartGeometry geometry;

  static const _temperatureStroke = 2.5;
  static const _apparentStroke = 1.5;
  static const _dotRadius = 3.0;
  static const _apparentGap = 3.0;
  static const _rainProbabilityRadius = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final small = AppType.caption2.copyWith(color: AppPalette.foreground2, fontFeatures: AppType.tabular);
    final caption = AppType.caption1.copyWith(fontFeatures: AppType.tabular);
    final now = geometry.now;

    // Day boundaries (wall-clock midnights) and day labels.
    final firstWall = taiwanWall(geometry.origin);
    var day = DateTime.utc(firstWall.year, firstWall.month, firstWall.day);
    final nowX = geometry.x(now);
    final showNow = !now.isBefore(geometry.origin) && now.isBefore(geometry.end);
    // Late in the day the first label would run into the next day's label:
    // dropped then (the 現在 marker still shows where today is).
    final dayStyle = caption.copyWith(color: AppPalette.foreground1, fontWeight: FontWeight.w600);
    final firstTitle = _dayTitle(day, now);
    final firstX = (showNow ? nowX : ForecastChartGeometry._padStart) + ForecastChartGeometry.todayLabelInset;
    final firstWidth = (TextPainter(text: TextSpan(text: firstTitle, style: dayStyle), textDirection: TextDirection.ltr)..layout()).width;
    final nextDayX = geometry.x(fromTaiwanWall(day.add(const Duration(days: 1))));
    if (firstX + firstWidth + ForecastChartGeometry.dayLabelInset <= nextDayX) {
      paintLabel(canvas, firstTitle, Offset(firstX, ForecastChartGeometry.dayLabelY), dayStyle, anchor: LabelAnchor.start);
    }
    while (true) {
      day = day.add(const Duration(days: 1));
      final at = fromTaiwanWall(day);
      if (!at.isBefore(geometry.end)) break;
      final dx = geometry.x(at);
      canvas.drawPath(
        dashedPath(
          Path()
            ..moveTo(dx, ForecastChartGeometry.dayLineTop)
            ..lineTo(dx, ForecastChartGeometry.dayLineBottom),
          chartDashLength,
          chartDashLength,
        ),
        strokePaint(AppPalette.stroke1, AppStroke.thin),
      );
      paintLabel(
        canvas,
        _dayTitle(day, now),
        Offset(dx + ForecastChartGeometry.dayLabelInset, ForecastChartGeometry.dayLabelY),
        caption.copyWith(color: AppPalette.foreground1, fontWeight: FontWeight.w600),
        anchor: LabelAnchor.start,
      );
    }

    if (showNow) {
      canvas.drawLine(
        Offset(nowX, ForecastChartGeometry.nowTop),
        Offset(nowX, ForecastChartGeometry.nowBottom),
        strokePaint(AppPalette.brandForeground, AppStroke.thick),
      );
      paintLabel(
        canvas,
        '現在',
        Offset(nowX, ForecastChartGeometry.dayLabelY),
        caption.copyWith(color: AppPalette.brandForeground, fontWeight: FontWeight.w600),
      );
    }

    // Tick axis.
    canvas.drawLine(
      Offset(geometry.x(geometry.slots.first.startTime), ForecastChartGeometry.tickAxisY),
      Offset(geometry.x(geometry.slots.last.startTime), ForecastChartGeometry.tickAxisY),
      strokePaint(AppPalette.stroke1, AppStroke.thin),
    );

    // Lines: 體感 (dashed) under temperature.
    Path line(double? Function(HourlyForecast) value) {
      final path = Path();
      var started = false;
      for (final s in geometry.slots) {
        final v = value(s);
        if (v == null) {
          started = false;
          continue;
        }
        final p = Offset(geometry.x(s.startTime), geometry.temperatureY(v));
        started ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
        started = true;
      }
      return path;
    }

    canvas.drawPath(
      dashedPath(line((s) => s.apparentTemperature), chartDashLength, _apparentGap),
      strokePaint(AppPalette.foreground4, _apparentStroke),
    );
    canvas.drawPath(line((s) => s.temperature), strokePaint(AppPalette.warningForeground, _temperatureStroke));

    final halo = AppPalette.background1;
    for (final s in geometry.slots) {
      final x = geometry.x(s.startTime);
      final wall = taiwanWall(s.startTime);
      final endWall = taiwanWall(s.startTime.add(forecastSlotLength));
      final center = geometry.slotCenter(s);

      paintLabel(
        canvas,
        '${twoDigits(wall.hour)}–${twoDigits(endWall.hour)}',
        Offset(center, ForecastChartGeometry.slotLabelY),
        caption.copyWith(color: AppPalette.foreground2),
      );

      final t = s.temperature;
      if (t != null) {
        final c = Offset(x, geometry.temperatureY(t));
        canvas.drawCircle(c, _dotRadius, Paint()..color = AppPalette.background1);
        canvas.drawCircle(c, _dotRadius, strokePaint(AppPalette.warningForeground, AppStroke.thick));
        paintLabel(
          canvas,
          temperatureText(t),
          c.translate(0, ForecastChartGeometry.temperatureLabelOffset),
          caption.copyWith(color: AppPalette.foreground1, fontWeight: FontWeight.w600),
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
        small.copyWith(color: AppPalette.foreground4),
        halo: halo,
      );
      paintLabel(
        canvas,
        temperatureText(s.apparentTemperature),
        Offset(x, ForecastChartGeometry.apparentLabelY),
        small.copyWith(color: AppPalette.foreground3),
        halo: halo,
      );

      final track = Rect.fromLTWH(
        center - geometry.rainProbabilityWidth / 2,
        ForecastChartGeometry.rainProbabilityTop,
        geometry.rainProbabilityWidth,
        ForecastChartGeometry.rainProbabilityHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(track, const Radius.circular(_rainProbabilityRadius)),
        Paint()..color = AppPalette.rainBarTrack,
      );
      final rainProbabilityPercent = s.rainProbabilityPercent;
      if (rainProbabilityPercent != null && rainProbabilityPercent > 0) {
        final h = ForecastChartGeometry.rainProbabilityHeight * rainProbabilityPercent / 100;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(track.left, track.bottom - h, track.width, h),
            const Radius.circular(_rainProbabilityRadius),
          ),
          Paint()..color = AppPalette.rainBar,
        );
      }
      paintLabel(
        canvas,
        percentText(rainProbabilityPercent),
        Offset(center, ForecastChartGeometry.rainProbabilityLabelY),
        rainProbabilityTextStyle(small, rainProbabilityPercent),
      );
      paintLabel(canvas, windDirectionLabel(s.windDirection), Offset(center, ForecastChartGeometry.windDirectionY), small);
      paintLabel(canvas, speedText(s.windSpeed), Offset(center, ForecastChartGeometry.windSpeedY), small);
    }
  }

  /// `今天 11/14（六）` for today…後天, `週二 11/17` beyond.
  String _dayTitle(DateTime wall, DateTime now) {
    final rel = relativeDay(wall, now);
    return dayOffset(wall, now) <= 2 ? '$rel ${monthDayWeekday(wall)}' : '$rel ${monthDayText(wall)}';
  }

  @override
  bool shouldRepaint(ForecastChartPainter old) =>
      old.geometry.slots != geometry.slots || old.geometry.now != geometry.now || old.geometry.pixelsPerHour != geometry.pixelsPerHour;
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
        chartDashLength,
        chartDashLength,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.thick
        ..color = AppPalette.foreground4,
    );
  }

  @override
  bool shouldRepaint(ForecastDashKeyPainter old) => false;
}
