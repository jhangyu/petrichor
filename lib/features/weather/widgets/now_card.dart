import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/taiwan_time.dart';
import '../../../core/widgets/api_key_notice.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/data_display.dart';
import '../../../core/widgets/status.dart';
import '../../../data/models/weather_models.dart';
import '../../../core/api/result.dart';
import '../../hazard/warnings/warning_groups.dart';
import '../../hazard/warnings/warning_style.dart';
import 'home_logic.dart';
import 'sky_arc.dart';
import 'sun_now.dart';
import 'weather_format.dart';
import 'weather_glyph_icon.dart';

/// Height of the now card's data block at phone width (arc, two tile groups,
/// notes), so the loading skeleton does not jump.
const _skeletonHeight = 520.0;

/// `.now` (home v1): current observation (O-A0003-001) on the sun arc
/// (A-B0062-001 + computed 仰角), the 體感與環境 and 太陽 tile groups and the
/// 天氣建議 / 日照 notes. [warning] = the county's top active warning: shows the
/// jump badge, which calls [onJumpToWarnings].
class NowCard extends StatelessWidget {
  const NowCard({
    super.key,
    required this.state,
    required this.warning,
    required this.onJumpToWarnings,
    required this.onRetry,
  });

  final NowCardState state;
  final WarningGroup? warning;
  final VoidCallback onJumpToWarnings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      NowCardLoading() => const AppCard.loading(hero: true, skeletonHeight: _skeletonHeight),
      NowCardApiKey(:final issue) => ApiKeyNotice(issue: issue),
      NowCardFailed(:final message) => AppCard.error(title: '無法取得目前天氣', message: message, onRetry: onRetry),
      NowCardReady() && final ready => AppCard(
        hero: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.s12,
          children: [_eyebrow(ready.observation), _body(ready)],
        ),
      ),
    };
  }

  /// `.now__eyebrow`: 即時觀測 time · station, and the jump badge.
  Widget _eyebrow(CurrentWeather c) {
    final top = warning;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSize.controlSmall),
      child: Row(
        spacing: AppSpace.s8,
        children: [
          Expanded(
            child: Text(
              '即時觀測 ${clockText(c.observedAt)} · ${c.stationName}測站',
              style: AppType.caption1.copyWith(color: AppPalette.foreground3, fontFeatures: AppType.tabular),
            ),
          ),
          if (top != null)
            Semantics(
              button: true,
              label: '${top.name}，跳到頁尾警特報',
              excludeSemantics: true,
              child: InkWell(
                onTap: onJumpToWarnings,
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSize.touch),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppSpace.s4,
                    children: [
                      AppBadge(label: top.name, tone: WarningLevelStyle.of(top.level).tone, icon: warningIcon(top)),
                      const Icon(Icons.expand_more, size: AppSize.icon16, color: AppPalette.foreground3),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// `.now__body`: arc above the side column, or beside it once the card is wide.
  Widget _body(NowCardReady ready) {
    final c = ready.observation;
    final sun = switch (ready.sun) {
      Success(:final data) => data,
      Failure() => null,
    };
    final top = sun == null ? _FlatTemperature(observation: c) : SkyArc(observation: c, sun: sun);
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s12,
      children: [
        _TileGroup(label: '體感與環境', tiles: _comfortTiles(c, ready.slot)),
        switch (ready.sun) {
          Success(:final data) => _TileGroup(
            label: '太陽',
            meta: data.tilesMeta,
            tiles: [
              for (final t in data.tiles)
                MetricTile(
                  label: t.event.label,
                  value: clockText(t.time),
                  dense: true,
                  tone: switch (t.tone) {
                    SunTileTone.normal => MetricTone.normal,
                    SunTileTone.next => MetricTone.next,
                    SunTileTone.past => MetricTone.past,
                  },
                ),
            ],
          ),
          Failure(:final message) => StatusBanner(
            tone: StatusTone.error,
            title: '無法取得日出日落資料',
            text: message,
            actions: [RetryButton(onPressed: onRetry)],
          ),
        },
        ?_notes(ready.slot?.description, sun),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < AppLayout.cardWideWidth) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: AppSpace.s12, children: [top, side]);
        }
        return Row(
          spacing: AppSpace.s24,
          children: [
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: skyMaxWidth), child: top),
            Expanded(child: side),
          ],
        );
      },
    );
  }

  List<MetricTile> _comfortTiles(CurrentWeather c, HourlyForecast? slot) {
    final pop = slot?.pop;
    return [
      MetricTile(label: '體感', value: tempText(slot?.apparentTemperature), dense: true),
      MetricTile(label: '濕度', value: percentText(c.humidity), dense: true),
      MetricTile(
        label: switch (c.windDirection) {
          null => '風',
          final wind => '風 · ${observedWindLabel(wind)}',
        },
        value: speedText(c.windSpeed),
        dense: true,
      ),
      MetricTile(
        label: '降雨機率',
        value: percentText(pop),
        dense: true,
        tone: pop != null && pop < rainLowThresholdPercent ? MetricTone.past : MetricTone.rain,
      ),
    ];
  }

  /// `.notes--list`: 天氣建議 (forecast slot description, verbatim) and the 日照 note.
  Widget? _notes(String? advice, SunNow? sun) {
    final notes = [
      if (advice != null) AppNote(icon: Icons.umbrella_outlined, text: advice, tone: NoteTone.rain),
      if (sun != null)
        AppNote(
          icon: sun.isNight ? Icons.bedtime_outlined : Icons.wb_sunny_outlined,
          text: sun.note,
          tone: NoteTone.neutral,
        ),
    ];
    return notes.isEmpty ? null : AppNoteList(children: notes);
  }
}

/// `.group`: caption label row (+ meta) over a 4-column dense tile grid.
class _TileGroup extends StatelessWidget {
  const _TileGroup({required this.label, required this.tiles, this.meta});

  final String label;
  final String? meta;
  final List<MetricTile> tiles;

  @override
  Widget build(BuildContext context) {
    final trailing = meta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s4,
      children: [
        Row(
          spacing: AppSpace.s8,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppType.caption1.copyWith(color: AppPalette.foreground2, fontWeight: FontWeight.w600),
              ),
            ),
            if (trailing != null)
              Text(trailing, style: AppType.caption1.copyWith(color: AppPalette.foreground3, fontFeatures: AppType.tabular)),
          ],
        ),
        MetricGrid(columns: tiles.length, children: tiles),
      ],
    );
  }
}

/// `.now__flat`: temperature beside the weather glyph, used when the sun data
/// failed (the arc cannot be drawn; the error sits in the 太陽 group's place).
class _FlatTemperature extends StatelessWidget {
  const _FlatTemperature({required this.observation});

  final CurrentWeather observation;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpace.s16,
      children: [
        Expanded(child: TemperatureBlock(observation: observation, crossAxisAlignment: CrossAxisAlignment.start)),
        WeatherGlyphIcon(text: observation.weather, size: AppSize.icon64),
      ],
    );
  }
}
