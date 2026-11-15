import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/api_key_notice.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/weather_models.dart';
import '../../../data/repositories/weather_repository.dart';
import 'chart_paint.dart';
import 'home_logic.dart';

/// Height of the sun card data block (arc + two time rows + now line + tomorrow line).
const _sunSkeletonHeight = 260.0;

/// `.sun`: today's sunrise / sunset (A-B0062-001), day length, 曙光／過中天／暮光
/// and tomorrow's times. [days] is `[今天, 明天]`.
class SunCard extends StatelessWidget {
  const SunCard({super.key, required this.days, required this.now, required this.onRetry});

  /// null = still loading.
  final Result<List<SunDay>>? days;
  final DateTime now;
  final VoidCallback onRetry;

  static const _title = '日出日落';

  /// Widest the sun arc grows; wider cards put the times beside it.
  static const _arcMaxWidth = 360.0;

  @override
  Widget build(BuildContext context) {
    return switch (days) {
      null => const AppCard.loading(title: _title, skeletonHeight: _sunSkeletonHeight),
      Failure(apiKeyIssue: final issue?) => ApiKeyNotice(issue: issue),
      Failure(:final message) => AppCard.error(title: '無法取得日出日落資料', message: message, onRetry: onRetry),
      Success(:final data) => _card(data.first, data.length > 1 ? data[1] : null),
    };
  }

  Widget _card(SunDay today, SunDay? tomorrow) {
    final todayWall = taiwanDate(today.date);
    final arc = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _arcMaxWidth),
        child: AspectRatio(
          aspectRatio: _SunArcPainter.viewWidth / _SunArcPainter.viewHeight,
          child: CustomPaint(
            painter: _SunArcPainter(day: today, now: now),
            child: Semantics(
              label:
                  '太陽位置：曙光 ${clockText(today.civilDawn)}、日出 ${clockText(today.sunrise)}、'
                  '過中天 ${clockText(today.transit)}（仰角 ${today.transitAltitudeDegrees}°）、'
                  '日落 ${clockText(today.sunset)}、暮光 ${clockText(today.civilDusk)}',
            ),
          ),
        ),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s12,
      children: [
        _row([
          ('日出', clockText(today.sunrise), _ValueSize.main),
          ('白晝長度', durationText(today.sunset.difference(today.sunrise)), _ValueSize.sub),
          ('日落', clockText(today.sunset), _ValueSize.main),
        ]),
        _row([
          ('曙光', clockText(today.civilDawn), _ValueSize.minor),
          ('過中天', clockText(today.transit), _ValueSize.minor),
          ('暮光', clockText(today.civilDusk), _ValueSize.minor),
        ]),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: AppSpace.s4,
          children: [
            const Icon(Icons.schedule, size: AppSize.icon16, color: AppPalette.brandFg),
            Flexible(
              child: Text(
                sunNowLine(today, tomorrow, now),
                style: AppType.body1.copyWith(color: AppPalette.fg1, fontFeatures: AppType.tabular),
              ),
            ),
          ],
        ),
        if (tomorrow != null) _tomorrow(tomorrow),
      ],
    );
    return AppCard(
      title: _title,
      meta: '${relativeDay(todayWall, now)} ${monthDayWeekday(todayWall)}',
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= AppLayout.cardWideWidth
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: AppSpace.s16,
                children: [
                  Expanded(child: arc),
                  Expanded(child: details),
                ],
              )
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: AppSpace.s12, children: [arc, details]),
      ),
    );
  }

  Widget _row(List<(String, String, _ValueSize)> cells) {
    return Row(
      children: [
        for (final (label, value, size) in cells)
          Expanded(
            child: Column(
              children: [
                Text(label, style: AppType.caption1.copyWith(color: AppPalette.fg3)),
                Text(
                  value,
                  maxLines: 1,
                  style: switch (size) {
                    _ValueSize.main => AppType.subtitle1.copyWith(color: AppPalette.fg1),
                    _ValueSize.sub => AppType.body1.copyWith(
                      color: AppPalette.fg2,
                      height: AppType.subtitle1.height! * AppType.subtitle1.fontSize! / AppType.body1.fontSize!,
                    ),
                    _ValueSize.minor => AppType.body1.copyWith(color: AppPalette.fg2),
                  }.copyWith(fontFeatures: AppType.tabular),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tomorrow(SunDay day) {
    final wall = taiwanDate(day.date);
    return Container(
      padding: const EdgeInsets.only(top: AppSpace.s12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppPalette.stroke3, width: AppStroke.thin),
        ),
      ),
      child: Text(
        '${relativeDay(wall, now)} ${monthDayWeekday(wall)}　日出 ${clockText(day.sunrise)} · 日落 ${clockText(day.sunset)}',
        style: AppType.caption1.copyWith(color: AppPalette.fg2, fontFeatures: AppType.tabular),
      ),
    );
  }
}

/// `.sun__value` sizes: main (subtitle1), `--sub` (body1 on the subtitle1 line), `--minor` (body1).
enum _ValueSize { main, sub, minor }

/// Half-ellipse sun path drawn in the mockup's 288×112 view box, scaled to the
/// card width. Points are placed by time: sunrise/sunset on the horizon, 曙光／暮光
/// below it, 過中天 and now on the arc.
class _SunArcPainter extends CustomPainter {
  _SunArcPainter({required this.day, required this.now});

  final SunDay day;
  final DateTime now;

  static const viewWidth = 288.0;
  static const viewHeight = 112.0;
  static const _cx = 144.0;
  static const _horizonY = 96.0;
  static const _rx = 96.0;
  static const _ry = 80.0;
  static const _horizonInset = 16.0;
  static const _arcLabelTop = 24.0;
  static const _dash = 4.0;
  static const _twilightDash = 2.0;
  static const _twilightGap = 3.0;
  static const _twilightAlpha = 0.4;
  static const _pointRadius = 3.0;
  static const _endRadius = 4.0;
  static const _nowRadius = 8.0;
  static const _pathStroke = 3.0;
  static const _twilightStroke = 2.0;
  static const _horizonStroke = 1.5;

  /// Share of daylight at [t] (0 = sunrise, 1 = sunset; negative before sunrise).
  double _fraction(DateTime t) => t.difference(day.sunrise).inSeconds / day.sunset.difference(day.sunrise).inSeconds;

  Offset _point(double fraction) {
    final angle = math.pi * (1 - fraction);
    return Offset(_cx + _rx * math.cos(angle), _horizonY - _ry * math.sin(angle));
  }

  Path _arc(double from, double to) {
    final rect = Rect.fromCenter(center: const Offset(_cx, _horizonY), width: _rx * 2, height: _ry * 2);
    final start = math.pi + from * math.pi;
    return Path()..addArc(rect, start, (to - from) * math.pi);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / viewWidth);
    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..color = c
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    Paint fill(Color c) => Paint()..color = c;

    canvas.drawLine(
      const Offset(_horizonInset, _horizonY),
      const Offset(viewWidth - _horizonInset, _horizonY),
      stroke(AppPalette.stroke2, _horizonStroke),
    );

    final pos = sunPosition(day, now);
    final f = pos.dayFraction;
    canvas.drawPath(dashedPath(_arc(f, 1), _dash, _dash), stroke(AppPalette.stroke1, AppStroke.thick));
    if (f > 0) canvas.drawPath(_arc(0, f), stroke(AppPalette.iconSun, _pathStroke));

    final twilight = stroke(AppPalette.iconSun.withValues(alpha: _twilightAlpha), _twilightStroke);
    final dawn = _fraction(day.civilDawn);
    final dusk = _fraction(day.civilDusk);
    canvas.drawPath(dashedPath(_arc(dawn, 0), _twilightDash, _twilightGap), twilight);
    canvas.drawPath(dashedPath(_arc(1, dusk), _twilightDash, _twilightGap), twilight);

    void ring(Offset c, double r, Color edge, double w) {
      canvas.drawCircle(c, r, fill(AppPalette.bg1));
      canvas.drawCircle(c, r, stroke(edge, w));
    }

    ring(_point(dawn), _pointRadius, AppPalette.fg4, _horizonStroke);
    ring(_point(dusk), _pointRadius, AppPalette.fg4, _horizonStroke);
    final transit = _point(_fraction(day.transit));
    ring(transit, _pointRadius, AppPalette.iconSun, AppStroke.thick);
    ring(_point(0), _endRadius, AppPalette.fg3, _horizonStroke);
    ring(_point(1), _endRadius, AppPalette.fg3, _horizonStroke);

    if (pos.phase == SunPhase.daytime) {
      final c = _point(f);
      canvas.drawCircle(c, _nowRadius, fill(AppPalette.iconSun));
      canvas.drawCircle(c, _nowRadius, stroke(AppPalette.bg1, _pathStroke));
    }

    final label = AppType.caption1.copyWith(color: AppPalette.fg2, fontFeatures: AppType.tabular);
    final lineHeight = AppType.caption1.fontSize! * AppType.caption1.height!;
    paintLabel(canvas, clockText(day.transit), Offset(transit.dx, _arcLabelTop + lineHeight / 2), label);
    paintLabel(canvas, '仰角 ${day.transitAltitudeDegrees}°', Offset(transit.dx, _arcLabelTop + lineHeight * 1.5), label);
  }

  @override
  bool shouldRepaint(_SunArcPainter old) => old.day != day || old.now != now;
}
