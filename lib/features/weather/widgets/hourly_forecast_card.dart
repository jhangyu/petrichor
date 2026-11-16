import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/taiwan_time.dart';
import '../../../core/widgets/api_key_notice.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/weather_models.dart';
import '../../../core/api/result.dart';
import 'forecast_chart.dart';
import '../weather_logic.dart';
import '../../../core/format/weather_format.dart';
import '../../../core/widgets/weather_glyph_icon.dart';

/// Height of the 72-hour data block (summary + chart + legend).
const _forecastSkeletonHeight = 456.0;

/// `.fc72`: F-D0047-061 three-day township forecast as a summary row and a
/// horizontally scrolling chart (temperature line, 體感 dashed line, weather
/// icons, 3-hour 降雨機率 bars, wind), placed by time.
class HourlyForecastCard extends StatelessWidget {
  const HourlyForecastCard({
    super.key,
    required this.hourly,
    required this.issuedAt,
    required this.now,
    required this.onRetry,
  });

  /// null = still loading.
  final Result<List<HourlyForecast>>? hourly;

  /// 發布時間 (card meta); null = still loading.
  final Result<DateTime>? issuedAt;
  final DateTime now;
  final VoidCallback onRetry;

  static const _title = '未來 72 小時預報';

  @override
  Widget build(BuildContext context) {
    return switch (hourly) {
      null => const AppCard.loading(title: _title, skeletonHeight: _forecastSkeletonHeight),
      Failure(apiKeyIssue: final issue?) => ApiKeyNotice(issue: issue),
      Failure(:final message) => AppCard.error(title: '無法取得 72 小時預報', message: message, onRetry: onRetry),
      Success(:final data) when data.isEmpty => const AppCard.empty(title: '暫無 72 小時預報'),
      Success(:final data) => AppCard(
        title: _title,
        meta: switch (issuedAt) {
          Success(:final data) => issuedText(data),
          Failure() => '無法取得發布時間',
          null => null,
        },
        child: LayoutBuilder(
          builder: (context, box) {
            final geometry = ForecastChartGeometry(data, now, box.maxWidth - forecastAxisWidth);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpace.s16,
              children: [
                _summary(forecastExtremes(data)),
                _chart(data, geometry),
                _legend(scrolls: geometry.scrolls),
              ],
            );
          },
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
        _stat('最高溫', temperatureText(hot?.temperature), AppPalette.temperatureHot, hot == null ? '—' : _when(hot)),
        _stat('最低溫', temperatureText(cold?.temperature), AppPalette.temperatureCold, cold == null ? '—' : _when(cold)),
        _stat('降雨機率', percentText(wet?.rainProbabilityPercent), AppPalette.rainForeground, wet == null ? '—' : _when(wet)),
      ],
    );
  }

  Widget _stat(String label, String value, Color color, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s8),
        decoration: BoxDecoration(
          color: AppPalette.background2,
          border: Border.all(color: AppPalette.stroke3, width: AppStroke.thin),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 1, style: AppType.caption1.copyWith(color: AppPalette.foreground3)),
            Text(
              value,
              style: AppType.subtitle1.copyWith(color: color, fontFeatures: AppType.tabular),
            ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.caption1.copyWith(color: AppPalette.foreground2, fontFeatures: AppType.tabular),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chart(List<HourlyForecast> slots, ForecastChartGeometry geometry) {
    final scrolls = geometry.scrolls;
    Widget plot = Semantics(
      label: _chartLabel(slots, scrolls),
      child: SizedBox(
        width: geometry.width,
        height: ForecastChartGeometry.height,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: ForecastChartPainter(geometry))),
            for (final s in slots)
              Positioned(
                left: geometry.slotCenter(s) - AppSize.icon24 / 2,
                top: ForecastChartGeometry.iconTop,
                child: WeatherGlyphIcon(text: s.weather, size: AppSize.icon24),
              ),
          ],
        ),
      ),
    );
    plot = scrolls ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: plot) : Center(child: plot);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: forecastAxisWidth,
          height: ForecastChartGeometry.height,
          child: CustomPaint(painter: ForecastAxisPainter()),
        ),
        Expanded(
          child: ClipRRect(borderRadius: BorderRadius.circular(AppRadius.extraSmall), child: plot),
        ),
      ],
    );
  }

  String _chartLabel(List<HourlyForecast> slots, bool scrolls) {
    final e = forecastExtremes(slots);
    final summary =
        '最高溫 ${temperatureText(e.hottest?.temperature)}、最低溫 ${temperatureText(e.coldest?.temperature)}、降雨機率最高 ${percentText(e.wettest?.rainProbabilityPercent)}';
    return '未來 72 小時逐時溫度、體感溫度、降雨機率與風${scrolls ? '，可左右捲動' : ''}。$summary';
  }

  Widget _legend({required bool scrolls}) {
    final style = AppType.caption1.copyWith(color: AppPalette.foreground3);
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
                    color: AppPalette.warningForeground,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                '溫度',
              ),
              item(
                const SizedBox(
                  width: AppSize.icon16,
                  height: AppStroke.thick,
                  child: CustomPaint(painter: ForecastDashKeyPainter()),
                ),
                '體感',
              ),
              item(
                Container(
                  width: AppSize.dot,
                  height: AppSize.dot,
                  decoration: BoxDecoration(
                    color: AppPalette.rainBar,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                '3 小時降雨機率',
              ),
            ],
          ),
        ),
        if (scrolls) Text('左右滑動看 72 小時', style: style),
      ],
    );
  }
}
