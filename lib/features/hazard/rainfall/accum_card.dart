import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/taiwan_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choices.dart';
import '../../../core/widgets/status.dart';
import '../../../data/radar/radar_frame_repository.dart' show RadarFrame;
import '../../../data/radar/radar_loop.dart';
import '../../../data/rain_accum/accum_pieces.dart';
import '../../radar/radar_playback.dart';
import '../../radar/radar_player.dart';
import '../../radar/radar_provider.dart';
import '../../radar/widgets/playback_card.dart';
import '../../radar/widgets/radar_map_view.dart';
import 'accum_provider.dart';
import 'rain_map_card.dart';

const _cardTitle = '累積雨量';
const _group = RadarGroup.rainfall;
const _overlayOpacity = 0.8;

/// Peak under this many mm draws nothing (contract decision 11): the frame has no rain.
const _noRainBelowMm = 1;

/// What a loop state puts in the card: optional banner, the map, optional playback.
typedef _Body = ({Widget? banner, RainMapView map, Widget? playback});

/// Legend numbers under the 17-colour bar: the first colour index of each band
/// and its label (the band lower edge of `accumScaleEdgesMm`).
const _legendMarks = [(0, '<1'), (4, '10'), (8, '40'), (11, '90'), (14, '150'), (16, '≥300')];

/// 累積雨量 card (design 3): window chips, accumulation map, the radar's
/// playback and the 17-colour legend. [me] null = no current place.
class AccumulationCard extends ConsumerStatefulWidget {
  const AccumulationCard({super.key, required this.me, this.cameraLink, required this.wide});

  final LatLng? me;

  /// Camera shared with the forecast map; only links the cameras.
  final RadarCameraLink? cameraLink;

  /// Map left, controls right ([RainMapCard]); false = one column, square locked map.
  final bool wide;

  @override
  ConsumerState<AccumulationCard> createState() => _AccumulationCardState();
}

class _AccumulationCardState extends ConsumerState<AccumulationCard> {
  late final RadarPlayer _player = RadarPlayer(
    slots: () => ref.read(accumLoopProvider(ref.read(rainAccumWindowProvider).requireValue)).value?.slots,
    fps: () => ref.read(radarFpsProvider(_group)).requireValue,
    repeat: () => ref.read(radarRepeatProvider(_group)).requireValue,
    onChanged: () => setState(() {}),
  );

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _setWindow(int hours) {
    _player.reset();
    unawaited(ref.read(rainAccumWindowProvider.notifier).set(hours));
  }

  void _setFps(int fps) {
    unawaited(ref.read(radarFpsProvider(_group).notifier).set(fps));
    _player.onFpsChanged();
  }

  void _retry(int hours) {
    _player.reset();
    ref.invalidate(accumLoopProvider(hours));
  }

  void _resetSettings(AsyncValue<int> window, AsyncValue<int> fps, AsyncValue<bool> repeat) {
    if (window.hasError) unawaited(ref.read(rainAccumWindowProvider.notifier).set(accumDefaultWindowHours));
    if (fps.hasError) unawaited(ref.read(radarFpsProvider(_group).notifier).set(_group.defaultFps));
    if (repeat.hasError) unawaited(ref.read(radarRepeatProvider(_group).notifier).set(true));
  }

  @override
  Widget build(BuildContext context) {
    // The one platform difference: QPEplus sends no CORS header, so a browser cannot fetch it.
    if (kIsWeb) {
      return const AppCard(
        title: _cardTitle,
        child: StatusBanner(tone: StatusTone.error, title: '網頁版無法取得此資料', text: '累積雨量資料來源不允許瀏覽器存取，請改用 App 查看。'),
      );
    }
    final window = ref.watch(rainAccumWindowProvider);
    final fps = ref.watch(radarFpsProvider(_group));
    final repeat = ref.watch(radarRepeatProvider(_group));
    if (window.hasError || fps.hasError || repeat.hasError) {
      return AppCard(
        title: _cardTitle,
        child: StatusBanner(
          tone: StatusTone.error,
          title: '累積雨量設定無法讀取',
          text: [
            for (final e in [window.error, fps.error, repeat.error]) ?e,
          ].join('；'),
          actions: [AppButton(label: '重設設定', small: true, onPressed: () => _resetSettings(window, fps, repeat))],
        ),
      );
    }
    if (!window.hasValue || !fps.hasValue || !repeat.hasValue) {
      return const AppCard.loading(title: _cardTitle, skeletonHeight: 360);
    }
    final hours = window.requireValue;
    ref.listen(accumLoopProvider(hours), (_, _) => _player.onLoopUpdate());
    final loop = ref.watch(accumLoopProvider(hours));
    final (meta, (:banner, :map, :playback)) = switch (loop) {
      AsyncError(:final error) => ('無法取得', _failureBody(hours, '$error')),
      AsyncValue(:final value?) => _loopBody(hours, value, fps.requireValue, repeat.requireValue),
      _ => ('載入中', _loadingBody(hours)),
    };
    return RainMapCard(
      wide: widget.wide,
      title: _cardTitle,
      meta: meta,
      controlsTitle: '動畫播放',
      banner: banner,
      map: map,
      controls: [?playback],
      legend: RainLegend(
        title: '$hours 小時累積 mm',
        semanticsLabel: '$hours 小時累積雨量圖例（毫米）',
        colours: AppPalette.rainfallMapScale,
        marks: _legendMarks,
      ),
      note: '資料來源：中央氣象署 QPEplus 雨量站分析。低於 1 mm 不著色。',
      leading: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpace.s8,
          children: [
            Text(
              '累積時距（小時）',
              style: AppType.caption1.copyWith(color: AppPalette.fg2, fontWeight: FontWeight.w600),
            ),
            Semantics(
              label: '累積時距',
              container: true,
              child: Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: [for (final h in accumWindowHours) AppChip(label: '$h', selected: h == hours, onTap: () => _setWindow(h))],
              ),
            ),
          ],
        ),
      ],
    );
  }

  RainMapView _map({
    bool loading = false,
    bool muted = false,
    IconData? chipIcon,
    String? chipText,
    String? semanticsLabel,
    List<RadarFrame> upcoming = const [],
    List<OverlayImage> overlayImages = const [],
  }) {
    return RainMapView(
      wide: widget.wide,
      cameraLink: widget.cameraLink,
      me: widget.me,
      loading: loading,
      muted: muted,
      chipIcon: chipIcon,
      chipText: chipText,
      semanticsLabel: semanticsLabel,
      upcoming: upcoming,
      overlayImages: overlayImages,
    );
  }

  _Body _loadingBody(int hours) =>
      (banner: null, map: _map(loading: true, muted: true), playback: const PlaybackBody(playback: null, loading: true));

  _Body _failureBody(int hours, String error) => (
    banner: StatusBanner(
      tone: StatusTone.error,
      title: '無法取得累積雨量',
      text: error,
      actions: [RetryButton(onPressed: () => _retry(hours))],
    ),
    map: _map(muted: true, chipIcon: Icons.cloud_off_outlined, chipText: '無累積雨量資料', semanticsLabel: '地圖，無累積雨量資料'),
    playback: null,
  );

  (String, _Body) _loopBody(int hours, RadarLoop loop, int fps, bool repeat) {
    final slots = loop.slots;
    final failed = radarFailedSlots(slots);
    final index = radarShownIndex(slots, _player.playhead);
    if (index == null) {
      if (loop.loading) return ('載入中', _loadingBody(hours));
      return ('無法取得', _failureBody(hours, '${radarNoFrameError(loop, failed)}'));
    }
    final frame = slots[index].frame!;
    // Contract decision 12: the window starts at S = newest slot - window and each frame accumulates from S.
    final start = slots.last.time.subtract(Duration(hours: hours));
    String span(DateTime t) => '${formatTaiwanMonthDayClock(start)} 起累積至 ${formatTaiwanMonthDayClock(t)}';
    final isLast = index == slots.length - 1;
    final noRain = (frame.peakMm ?? double.infinity) < _noRainBelowMm;
    final accumulated = isLast ? '過去 $hours 小時' : span(frame.time);
    final readyCount = radarReadyCount(slots);
    final waiting = _player.waitingOn != null;
    final meta = radarPlaybackMeta(
      buffering: waiting,
      playing: _player.playing,
      loading: loop.loading,
      ready: readyCount,
      total: slots.length,
      fps: fps,
      repeat: repeat,
      idle: '${slots.length} 張',
    );
    final listError = loop.listError;
    return (
      meta,
      (
        banner: listError != null
            ? StatusBanner(
                tone: StatusTone.error,
                title: '無法更新，顯示 ${clockText(frame.time)} 的資料',
                text: '$listError',
                actions: [RetryButton(onPressed: () => _retry(hours))],
              )
            : failed.isNotEmpty
            ? StatusBanner(
                tone: StatusTone.error,
                title: '${failed.length} 張影格無法取得',
                text: '${clockText(failed.first.time)} ${'${failed.first.error}'.trim().split('\n').first}',
                actions: [RetryButton(onPressed: () => _retry(hours))],
              )
            : null,
        map: _map(
          chipIcon: Icons.schedule,
          chipText: noRain
              ? '$accumulated全臺沒有降雨'
              : isLast
              ? '過去 $hours 小時累積 · ${formatTaiwanMonthDayClock(frame.time)}'
              : accumulated,
          semanticsLabel: noRain ? '地圖，全臺沒有降雨' : '累積雨量圖，${span(frame.time)}',
          upcoming: radarUpcomingFrames(slots, _player.playhead, count: radarPreDecodeCount),
          overlayImages: [
            if (!noRain)
              OverlayImage(
                bounds: frame.bounds,
                opacity: _overlayOpacity,
                imageProvider: frame.imageProvider,
                filterQuality: FilterQuality.none,
                gaplessPlayback: true,
              ),
          ],
        ),
        playback: PlaybackBody(
          playback: PlaybackFrames(
            slots: slots,
            index: index,
            current: radarCurrentCell(slots, shown: index, waitingOn: _player.waitingOn),
            buffering: waiting,
            playing: _player.playing,
            fps: fps,
            repeat: repeat,
            window: Duration(hours: hours),
            timeText: span,
            onTogglePlay: _player.togglePlay,
            onSeek: _player.seek,
            onFps: _setFps,
            onRepeat: (v) => unawaited(ref.read(radarRepeatProvider(_group).notifier).set(v)),
          ),
        ),
      ),
    );
  }
}
