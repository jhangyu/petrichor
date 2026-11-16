import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/taiwan_time.dart';
import '../../../core/widgets/api_key_notice.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/weather_models.dart';
import '../../../core/api/result.dart';
import '../weather_logic.dart';
import '../../../core/format/weather_format.dart';
import '../../../core/widgets/weather_glyph_icon.dart';

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
  static const _temperatureWidth = 28.0;

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
      meta: '${monthDayText(first)} – ${monthDayText(last)}',
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

  Widget _row(DailyForecast d, TemperatureScale? scale, {required bool divider}) {
    final wall = taiwanDate(d.date);
    final offset = dayOffset(wall, now);
    final label = offset <= 1 ? relativeDay(wall, now) : weekdayName(wall);
    final date = offset <= 1 ? '${weekdayName(wall)} ${monthDayText(wall)}' : monthDayText(wall);
    final numberStyle = AppType.body1.copyWith(fontFeatures: AppType.tabular);
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
                Text(label, style: AppType.body1Strong.copyWith(color: AppPalette.foreground1)),
                Text(
                  date,
                  style: AppType.caption1.copyWith(color: AppPalette.foreground3, fontFeatures: AppType.tabular),
                ),
              ],
            ),
          ),
          WeatherGlyphIcon(text: d.weather, size: AppSize.icon24),
          SizedBox(
            width: _rainWidth,
            child: Text(
              percentText(d.rainProbabilityPercent),
              textAlign: TextAlign.right,
              style: rainProbabilityTextStyle(AppType.caption1.copyWith(fontFeatures: AppType.tabular), d.rainProbabilityPercent),
            ),
          ),
          SizedBox(
            width: _temperatureWidth,
            child: Text(
              temperatureText(d.minTemperature),
              textAlign: TextAlign.right,
              style: numberStyle.copyWith(color: AppPalette.foreground3),
            ),
          ),
          Expanded(
            child: _TemperatureRange(
              scale: scale,
              low: d.minTemperature,
              high: d.maxTemperature,
              currentTemperature: offset == 0 ? currentTemperature : null,
            ),
          ),
          SizedBox(
            width: _temperatureWidth,
            child: Text(
              temperatureText(d.maxTemperature),
              style: numberStyle.copyWith(color: AppPalette.foreground1, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(TemperatureScale? scale) {
    final style = AppType.caption1.copyWith(color: AppPalette.foreground3, fontFeatures: AppType.tabular);
    final range = scale == null ? '' : '區間 ${temperatureText(scale.lowest)}–${temperatureText(scale.highest)}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          spacing: AppSpace.s4,
          children: [
            const Icon(Icons.umbrella_outlined, size: AppSize.icon16, color: AppPalette.rainForeground),
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
class _TemperatureRange extends StatelessWidget {
  const _TemperatureRange({required this.scale, required this.low, required this.high, required this.currentTemperature});

  final TemperatureScale? scale;
  final double? low;
  final double? high;
  final double? currentTemperature;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final lowTemperature = low;
    final highTemperature = high;
    final mark = currentTemperature;
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
                  color: AppPalette.background4,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              if (s != null && lowTemperature != null && highTemperature != null)
                Positioned(
                  left: s.fraction(lowTemperature) * w,
                  width: (s.fraction(highTemperature) - s.fraction(lowTemperature)) * w,
                  child: Container(
                    height: AppSize.sliderTrack,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      gradient: const LinearGradient(
                        colors: [
                          AppPalette.temperatureBarCold,
                          AppPalette.temperatureBarMild,
                          AppPalette.temperatureBarWarm,
                          AppPalette.temperatureBarHot,
                        ],
                      ),
                    ),
                  ),
                ),
              if (s != null && mark != null)
                Positioned(
                  left: s.fraction(mark) * w - AppSize.dot / 2,
                  child: Semantics(label: '目前 ${temperatureText(mark)}', child: const _NowDot()),
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
        color: AppPalette.background1,
        shape: BoxShape.circle,
        border: Border.all(color: AppPalette.foreground1, width: AppStroke.thick),
      ),
    );
  }
}
