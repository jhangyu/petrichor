import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/taiwan_time.dart';
import '../../../core/widgets/api_key_notice.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/weather_models.dart';
import '../../../core/api/result.dart';
import 'home_logic.dart';
import 'weather_glyph_icon.dart';

/// Height of the 7-day data block (7 rows of 56 + legend).
const _weeklySkeletonHeight = 424.0;

/// `.days`: F-D0047-063 7-day rows with a shared temperature axis; today's
/// row marks the observed temperature ([currentTemperature]).
class WeeklyCard extends StatelessWidget {
  const WeeklyCard({
    super.key,
    required this.weekly,
    required this.currentTemperature,
    required this.now,
    required this.onRetry,
  });

  /// null = still loading.
  final Result<List<DailyForecast>>? weekly;
  final double? currentTemperature;
  final DateTime now;
  final VoidCallback onRetry;

  static const _title = '7 日預報';
  static const _rowMinHeight = 56.0;
  static const _nameWidth = 64.0;
  static const _rainWidth = 36.0;
  static const _tempWidth = 28.0;

  @override
  Widget build(BuildContext context) {
    return switch (weekly) {
      null => const AppCard.loading(title: _title, skeletonHeight: _weeklySkeletonHeight),
      Failure(apiKeyIssue: final issue?) => ApiKeyNotice(issue: issue),
      Failure(:final message) => AppCard.error(title: '無法取得 7 日預報', message: message, onRetry: onRetry),
      Success(:final data) when data.isEmpty => const AppCard.empty(title: '暫無 7 日預報'),
      Success(:final data) => _card(data),
    };
  }

  Widget _card(List<DailyForecast> days) {
    final scale = weeklyScale(days, currentTemperature);
    final first = taiwanDate(days.first.date);
    final last = taiwanDate(days.last.date);
    return AppCard(
      title: _title,
      meta: '${monthDay(first)} – ${monthDay(last)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < days.length; i++) _row(days[i], scale, divider: i > 0),
          const SizedBox(height: AppSpace.s8),
          _legend(scale),
        ],
      ),
    );
  }

  Widget _row(DailyForecast d, TempScale? scale, {required bool divider}) {
    final wall = taiwanDate(d.date);
    final offset = dayOffset(wall, now);
    final label = offset <= 1 ? relativeDay(wall, now) : weekdayName(wall);
    final date = offset <= 1 ? '${weekdayName(wall)} ${monthDay(wall)}' : monthDay(wall);
    final low = isLowRain(d.pop);
    final num = AppType.body1.copyWith(fontFeatures: AppType.tabular);
    return Container(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      decoration: divider
          ? const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppPalette.stroke3, width: AppStroke.thin),
              ),
            )
          : null,
      child: Row(
        spacing: AppSpace.s8,
        children: [
          SizedBox(
            width: _nameWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.body1Strong.copyWith(color: AppPalette.fg1)),
                Text(
                  date,
                  style: AppType.caption1.copyWith(color: AppPalette.fg3, fontFeatures: AppType.tabular),
                ),
              ],
            ),
          ),
          WeatherGlyphIcon(text: d.weather, size: AppSize.icon24),
          SizedBox(
            width: _rainWidth,
            child: Text(
              percentText(d.pop),
              textAlign: TextAlign.right,
              style: AppType.caption1.copyWith(
                color: low ? AppPalette.fg3 : AppPalette.rainFg,
                fontWeight: low ? FontWeight.w400 : FontWeight.w600,
                fontFeatures: AppType.tabular,
              ),
            ),
          ),
          SizedBox(
            width: _tempWidth,
            child: Text(
              tempText(d.minTemperature),
              textAlign: TextAlign.right,
              style: num.copyWith(color: AppPalette.fg3),
            ),
          ),
          Expanded(
            child: _TempRange(
              scale: scale,
              low: d.minTemperature,
              high: d.maxTemperature,
              now: offset == 0 ? currentTemperature : null,
            ),
          ),
          SizedBox(
            width: _tempWidth,
            child: Text(
              tempText(d.maxTemperature),
              style: num.copyWith(color: AppPalette.fg1, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(TempScale? scale) {
    final style = AppType.caption1.copyWith(color: AppPalette.fg3, fontFeatures: AppType.tabular);
    final range = scale == null ? '' : '區間 ${tempText(scale.min)}–${tempText(scale.max)}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          spacing: AppSpace.s4,
          children: [
            const Icon(Icons.umbrella_outlined, size: AppSize.icon16, color: AppPalette.rainFg),
            Text('降雨機率', style: style),
          ],
        ),
        Row(
          spacing: AppSpace.s4,
          children: [
            if (currentTemperature != null) ...[
              const _NowDot(),
              Text('目前溫度　$range', style: style),
            ] else
              Text(range, style: style),
          ],
        ),
      ],
    );
  }
}

/// `.temp-range`: day low–high on the shared axis, with today's now marker.
class _TempRange extends StatelessWidget {
  const _TempRange({required this.scale, required this.low, required this.high, required this.now});

  final TempScale? scale;
  final double? low;
  final double? high;
  final double? now;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final lo = low;
    final hi = high;
    final mark = now;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return SizedBox(
          height: AppSize.dot,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: AppSize.sliderTrack,
                decoration: BoxDecoration(
                  color: AppPalette.bg4,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              if (s != null && lo != null && hi != null)
                Positioned(
                  left: s.fraction(lo) * w,
                  width: (s.fraction(hi) - s.fraction(lo)) * w,
                  child: Container(
                    height: AppSize.sliderTrack,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      gradient: const LinearGradient(
                        colors: [
                          AppPalette.tempBarCold,
                          AppPalette.tempBarMild,
                          AppPalette.tempBarWarm,
                          AppPalette.tempBarHot,
                        ],
                      ),
                    ),
                  ),
                ),
              if (s != null && mark != null)
                Positioned(
                  left: s.fraction(mark) * w - AppSize.dot / 2,
                  child: Semantics(label: '目前 ${tempText(mark)}', child: const _NowDot()),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// `.temp-range__now`: white dot with a dark ring.
class _NowDot extends StatelessWidget {
  const _NowDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSize.dot,
      height: AppSize.dot,
      decoration: BoxDecoration(
        color: AppPalette.bg1,
        shape: BoxShape.circle,
        border: Border.all(color: AppPalette.fg1, width: AppStroke.thick),
      ),
    );
  }
}
