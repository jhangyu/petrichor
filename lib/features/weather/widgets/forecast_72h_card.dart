import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/weather_models.dart';
import '../../../data/repositories/weather_repository.dart';
import 'chart_paint.dart';
import 'home_logic.dart';
import 'weather_glyph_icon.dart';

/// Height of the 72-hour data block (summary + chart + legend).
const _forecastSkeletonHeight = 456.0;

/// `.fc72`: F-D0047-061 three-day township forecast as a summary row and a
/// horizontally scrolling chart (temperature line, 體感 dashed line, weather
/// icons, 3-hour 降雨機率 bars, wind), placed by time.
class Forecast72hCard extends StatelessWidget {
  const Forecast72hCard({super.key, required this.hourly, required this.now, required this.onRetry});

  /// null = still loading.
  final Result<List<HourlyForecast>>? hourly;
  final DateTime now;
  final VoidCallback onRetry;

  static const _title = '未來 72 小時預報';

  @override
  Widget build(BuildContext context) {
    return switch (hourly) {
      null => const AppCard.loading(title: _title, skeletonHeight: _forecastSkeletonHeight),
      Failure(:final message) => AppCard.error(title: '無法取得 72 小時預報', message: message, onRetry: onRetry),
      Success(:final data) when data.isEmpty => const AppCard.empty(title: '暫無 72 小時預報'),
      Success(:final data) => AppCard(
        title: _title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.s16,
          children: [_summary(forecastExtremes(data)), _chart(data), _legend()],
        ),
      ),
    };
  }

  String _when(HourlyForecast s) => '${relativeDay(taiwanWall(s.startTime), now)} ${clockText(s.startTime)}';

  Widget _summary(ForecastExtremes e) {
    final hot = e.hottest;
    final cold = e.coldest;
    final wet = e.wettest;
    return Row(
      spacing: AppSpace.s8,
      children: [
        _stat('最高溫', tempText(hot?.temperature), AppPalette.tempHot, hot == null ? '—' : _when(hot)),
        _stat('最低溫', tempText(cold?.temperature), AppPalette.tempCold, cold == null ? '—' : _when(cold)),
        _stat('降雨機率', percentText(wet?.pop), AppPalette.rainFg, wet == null ? '—' : _when(wet)),
      ],
    );
  }

  Widget _stat(String label, String value, Color color, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s8),
        decoration: BoxDecoration(
          color: AppPalette.bg2,
          border: Border.all(color: AppPalette.stroke3, width: AppStroke.thin),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 1, style: AppType.caption1.copyWith(color: AppPalette.fg3)),
            Text(
              value,
              style: AppType.subtitle1.copyWith(color: color, fontFeatures: AppType.tabular),
            ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.caption1.copyWith(color: AppPalette.fg2, fontFeatures: AppType.tabular),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chart(List<HourlyForecast> slots) {
    final geometry = _ChartGeometry(slots, now);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: _axisWidth,
          height: _ChartGeometry.height,
          child: CustomPaint(painter: _AxisPainter()),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Semantics(
                label: '未來 72 小時逐時溫度、體感溫度、降雨機率與風，可左右捲動',
                child: SizedBox(
                  width: geometry.width,
                  height: _ChartGeometry.height,
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _ChartPainter(geometry))),
                      for (final s in slots)
                        Positioned(
                          left: geometry.slotCenter(s) - AppSize.icon24 / 2,
                          top: _ChartGeometry.iconTop,
                          child: WeatherGlyphIcon(text: s.weather, size: AppSize.icon24),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legend() {
    final style = AppType.caption1.copyWith(color: AppPalette.fg3);
    Widget item(Widget key, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpace.s4,
      children: [
        key,
        Text(label, style: style),
      ],
    );
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: AppSpace.s16,
            runSpacing: AppSpace.s4,
            children: [
              item(
                Container(
                  width: AppSize.icon16,
                  height: AppStroke.thick,
                  decoration: BoxDecoration(
                    color: AppPalette.warningFg,
                    borderRadius: BorderRadius.circular(AppRadius.circular),
                  ),
                ),
                '溫度',
              ),
              item(
                const SizedBox(
                  width: AppSize.icon16,
                  height: AppStroke.thick,
                  child: CustomPaint(painter: _DashKeyPainter()),
                ),
                '體感',
              ),
              item(
                Container(
                  width: AppSize.dot,
                  height: AppSize.dot,
                  decoration: BoxDecoration(
                    color: AppPalette.rainBar,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                '3 小時降雨機率',
              ),
            ],
          ),
        ),
        Text('左右滑動看 72 小時', style: style),
      ],
    );
  }
}

const _axisWidth = 40.0;

/// Chart rows in the mockup's SVG coordinates (y), 16 px per hour (x).
class _ChartGeometry {
  _ChartGeometry(this.slots, this.now)
    : origin = slots.first.startTime.isBefore(now) ? slots.first.startTime : now,
      end = slots.last.startTime.add(forecastSlotLength) {
    final temps = [
      for (final s in slots) ...[s.temperature, s.apparentTemperature],
    ].whereType<double>();
    tempMin = temps.isEmpty ? 0 : temps.reduce((a, b) => a < b ? a : b);
    tempMax = temps.isEmpty ? 0 : temps.reduce((a, b) => a > b ? a : b);
  }

  final List<HourlyForecast> slots;
  final DateTime now;
  final DateTime origin;
  final DateTime end;

  /// Range of every temperature and 體感 value; only read when such a value exists.
  late final double tempMin;
  late final double tempMax;

  static const height = 340.0;
  static const _pxPerHour = 16.0;
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
  static const popWidth = 32.0;
  static const popLabelY = 292.0;
  static const windDirY = 312.0;
  static const windSpeedY = 328.0;

  double x(DateTime t) => _padStart + t.difference(origin).inMinutes / Duration.minutesPerHour * _pxPerHour;

  double slotCenter(HourlyForecast s) => x(s.startTime.add(forecastSlotLength ~/ 2));

  double get width => x(end) + _padEnd;

  double tempY(double t) {
    if (tempMax == tempMin) return (tempTop + tempBottom) / 2;
    return tempBottom - (t - tempMin) / (tempMax - tempMin) * (tempBottom - tempTop);
  }
}

/// Fixed row titles left of the scrolling chart (`.fc72__axis`).
class _AxisPainter extends CustomPainter {
  const _AxisPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final style = AppType.caption1.copyWith(color: AppPalette.fg3);
    for (final (label, y) in [
      ('時段', _ChartGeometry.slotLabelY),
      ('天氣', _ChartGeometry.iconTop + AppSize.icon24 / 2),
      ('溫度', (_ChartGeometry.tempTop + _ChartGeometry.tempBottom) / 2),
      ('體感', _ChartGeometry.apparentLabelY - 4),
      ('降雨', _ChartGeometry.popTop + _ChartGeometry.popHeight / 2),
      ('風', (_ChartGeometry.windDirY + _ChartGeometry.windSpeedY) / 2),
    ]) {
      paintLabel(canvas, label, Offset(0, y), style, anchor: TextAnchor.start);
    }
  }

  @override
  bool shouldRepaint(_AxisPainter old) => false;
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.g);

  final _ChartGeometry g;

  static const _tempStroke = 2.5;
  static const _apparentStroke = 1.5;
  static const _dotRadius = 3.0;
  static const _dash = 4.0;
  static const _apparentGap = 3.0;
  static const _popRadius = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..color = c
      ..strokeWidth = w
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

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
      Offset((showNow ? nowX : _ChartGeometry._padStart) + _ChartGeometry.todayLabelInset, _ChartGeometry.dayLabelY),
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
            ..moveTo(dx, _ChartGeometry.dayLineTop)
            ..lineTo(dx, _ChartGeometry.dayLineBottom),
          _dash,
          _dash,
        ),
        stroke(AppPalette.stroke1, AppStroke.thin),
      );
      paintLabel(
        canvas,
        _dayTitle(day, now),
        Offset(dx + _ChartGeometry.dayLabelInset, _ChartGeometry.dayLabelY),
        caption.copyWith(color: AppPalette.fg1, fontWeight: FontWeight.w600),
        anchor: TextAnchor.start,
      );
    }

    if (showNow) {
      canvas.drawLine(
        Offset(nowX, _ChartGeometry.nowTop),
        Offset(nowX, _ChartGeometry.nowBottom),
        stroke(AppPalette.brandFg, AppStroke.thick),
      );
      paintLabel(
        canvas,
        '現在',
        Offset(nowX, _ChartGeometry.dayLabelY),
        caption.copyWith(color: AppPalette.brandFg, fontWeight: FontWeight.w600),
      );
    }

    // Tick axis.
    canvas.drawLine(
      Offset(g.x(g.slots.first.startTime), _ChartGeometry.tickAxisY),
      Offset(g.x(g.slots.last.startTime), _ChartGeometry.tickAxisY),
      stroke(AppPalette.stroke1, AppStroke.thin),
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
      dashedPath(line((s) => s.apparentTemperature), _dash, _apparentGap),
      stroke(AppPalette.fg4, _apparentStroke),
    );
    canvas.drawPath(line((s) => s.temperature), stroke(AppPalette.warningFg, _tempStroke));

    final halo = AppPalette.bg1;
    for (final s in g.slots) {
      final x = g.x(s.startTime);
      final wall = taiwanWall(s.startTime);
      final endWall = taiwanWall(s.startTime.add(forecastSlotLength));
      final center = g.slotCenter(s);

      paintLabel(
        canvas,
        '${wall.hour.toString().padLeft(2, '0')}–${endWall.hour.toString().padLeft(2, '0')}',
        Offset(center, _ChartGeometry.slotLabelY),
        caption.copyWith(color: AppPalette.fg2),
      );

      final t = s.temperature;
      if (t != null) {
        final c = Offset(x, g.tempY(t));
        canvas.drawCircle(c, _dotRadius, Paint()..color = AppPalette.bg1);
        canvas.drawCircle(c, _dotRadius, stroke(AppPalette.warningFg, AppStroke.thick));
        paintLabel(
          canvas,
          tempText(t),
          c.translate(0, _ChartGeometry.tempLabelOffset),
          caption.copyWith(color: AppPalette.fg1, fontWeight: FontWeight.w600),
          halo: halo,
        );
      }

      canvas.drawLine(
        Offset(x, _ChartGeometry.tickAxisY),
        Offset(x, _ChartGeometry.tickAxisY + _ChartGeometry.tickLength),
        stroke(AppPalette.stroke1, AppStroke.thin),
      );
      paintLabel(
        canvas,
        '${wall.hour}時',
        Offset(x, _ChartGeometry.tickLabelY),
        small.copyWith(color: AppPalette.fg4),
        halo: halo,
      );
      paintLabel(
        canvas,
        tempText(s.apparentTemperature),
        Offset(x, _ChartGeometry.apparentLabelY),
        small.copyWith(color: AppPalette.fg3),
        halo: halo,
      );

      final track = Rect.fromLTWH(
        center - _ChartGeometry.popWidth / 2,
        _ChartGeometry.popTop,
        _ChartGeometry.popWidth,
        _ChartGeometry.popHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(track, const Radius.circular(_popRadius)),
        Paint()..color = AppPalette.rainBarTrack,
      );
      final pop = s.pop;
      if (pop != null && pop > 0) {
        final h = _ChartGeometry.popHeight * pop / 100;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(track.left, track.bottom - h, track.width, h),
            const Radius.circular(_popRadius),
          ),
          Paint()..color = AppPalette.rainBar,
        );
      }
      final low = pop == null || pop < rainLowThresholdPercent;
      paintLabel(
        canvas,
        percentText(pop),
        Offset(center, _ChartGeometry.popLabelY),
        small.copyWith(
          color: low ? AppPalette.fg3 : AppPalette.rainFg,
          fontWeight: low ? FontWeight.w400 : FontWeight.w600,
        ),
      );
      paintLabel(canvas, windDirectionLabel(s.windDirection), Offset(center, _ChartGeometry.windDirY), small);
      paintLabel(canvas, speedText(s.windSpeed), Offset(center, _ChartGeometry.windSpeedY), small);
    }
  }

  /// `今天 11/14（六）` for today…後天, `週二 11/17` beyond.
  String _dayTitle(DateTime wall, DateTime now) {
    final rel = relativeDay(wall, now);
    return dayOffset(wall, now) <= 2 ? '$rel ${monthDayWeekday(wall)}' : '$rel ${monthDay(wall)}';
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.g.slots != g.slots || old.g.now != g.now;
}

/// Dashed 體感 legend key (`.fc72__key--at`).
class _DashKeyPainter extends CustomPainter {
  const _DashKeyPainter();

  static const _dash = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawPath(
      dashedPath(
        Path()
          ..moveTo(0, y)
          ..lineTo(size.width, y),
        _dash,
        _dash,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.thick
        ..color = AppPalette.fg4,
    );
  }

  @override
  bool shouldRepaint(_DashKeyPainter old) => false;
}
