import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/data_display.dart';
import '../../../data/models/weather_models.dart';
import '../../../data/repositories/weather_repository.dart';
import 'home_logic.dart';
import 'weather_glyph_icon.dart';

/// Height of the hero data block (eyebrow + temperature row + 2×2 metrics),
/// so the loading skeleton does not jump.
const _heroSkeletonHeight = 266.0;

/// `.hero`: current observation (O-A0003-001). 體感 and 降雨機率 come from the
/// forecast slot covering now ([slot]); the observation has neither.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.current, required this.slot, required this.onRetry});

  /// null = still loading.
  final Result<CurrentWeather>? current;
  final HourlyForecast? slot;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (current) {
      null => const AppCard.loading(hero: true, skeletonHeight: _heroSkeletonHeight),
      Failure(:final message) => AppCard.error(title: '無法取得目前天氣', message: message, onRetry: onRetry),
      Success(:final data) => AppCard(hero: true, child: _content(data)),
    };
  }

  Widget _content(CurrentWeather c) {
    final pop = slot?.pop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s16,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '即時觀測 · ${clockText(c.observedAt)}',
                style: AppType.caption1.copyWith(color: AppPalette.fg3, fontFeatures: AppType.tabular),
              ),
            ),
            if (pop != null) AppBadge(label: '降雨機率 $pop%', tone: BadgeTone.rain),
          ],
        ),
        Row(
          spacing: AppSpace.s16,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tempText(c.temperature),
                    style: AppType.display.copyWith(color: AppPalette.fg1, fontFeatures: AppType.tabular),
                  ),
                  Row(
                    spacing: AppSpace.s12,
                    children: [
                      _hilo('高', c.dailyHigh, AppPalette.tempHot),
                      _hilo('低', c.dailyLow, AppPalette.tempCold),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              spacing: AppSpace.s4,
              children: [
                WeatherGlyphIcon(text: c.weather, size: AppSize.icon64),
                Text(c.weather ?? '—', style: AppType.subtitle1.copyWith(color: AppPalette.fg1)),
              ],
            ),
          ],
        ),
        MetricGrid(
          children: [
            MetricTile(
              icon: Icons.thermostat_outlined,
              label: '體感',
              value: tempText(slot?.apparentTemperature),
              onHero: true,
            ),
            MetricTile(
              icon: Icons.water_drop_outlined,
              label: '濕度',
              value: c.humidity == null ? '—' : '${c.humidity}%',
              onHero: true,
            ),
            MetricTile(
              icon: Icons.air,
              label: switch (c.windDirection) {
                null => '風',
                final wind => '風 · ${observedWindLabel(wind)}',
              },
              value: speedText(c.windSpeed),
              onHero: true,
            ),
            MetricTile(icon: Icons.umbrella_outlined, label: '降雨機率', value: percentText(pop), onHero: true),
          ],
        ),
        ?_summary(slot?.description),
      ],
    );
  }

  /// `.hero__summary`: the forecast slot's 天氣預報綜合描述, verbatim.
  Widget? _summary(String? text) {
    if (text == null) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s8),
      decoration: BoxDecoration(color: AppPalette.rainBg, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpace.s8,
        children: [
          const Icon(Icons.umbrella_outlined, size: AppSize.icon20, color: AppPalette.rainFg),
          Expanded(child: Text(text, style: AppType.body1.copyWith(color: AppPalette.rainFg))),
        ],
      ),
    );
  }

  Widget _hilo(String label, double? value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpace.s4,
      children: [
        Text(label, style: AppType.caption1.copyWith(color: AppPalette.fg3)),
        Text(
          tempText(value),
          style: AppType.subtitle2.copyWith(color: color, fontFeatures: AppType.tabular),
        ),
      ],
    );
  }
}
