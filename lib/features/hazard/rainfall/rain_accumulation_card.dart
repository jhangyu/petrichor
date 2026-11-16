import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/taiwan_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/choices.dart';
import '../../../core/widgets/status.dart';
import '../../../data/radar/radar_loop.dart';
import '../../../data/rain_accumulation/rain_accumulation_pieces.dart';
import '../../radar/playback_frames.dart';
import '../../radar/radar_playback.dart';
import '../../radar/radar_player.dart';
import '../../radar/radar_provider.dart';
import '../../radar/radar_webp_image.dart';
import '../../radar/widgets/playback_card.dart';
import '../../radar/widgets/radar_map_view.dart';
import 'rain_accumulation_provider.dart';
import 'rain_map_card.dart';

const _cardTitle = '累積雨量';
const _skeletonHeight = 360.0;
const _group = RadarSettingsGroup.rainfall;

/// Peak under this many mm draws nothing (contract decision 11): the frame has no rain.
const _noRainBelowMillimeters = 1;

/// What a loop state puts in the card: optional banner, the map, optional playback.
typedef _Body = ({Widget? banner, RainMapView map, Widget? playback});

/// Legend numbers under the 17-colour bar: the first colour index of each band
/// and its label (the band lower edge of `accumulationScaleEdgesMillimeters`).
const _legendMarks = [(0, '<1'), (4, '10'), (8, '40'), (11, '90'), (14, '150'), (16, '≥300')];

/// 累積雨量 card (design 3): window chips, accumulation map, the radar's
/// playback and the 17-colour legend. [currentPlacePoint] null = no current place.
class AccumulationCard extends ConsumerStatefulWidget {
  const AccumulationCard({super.key, required this.currentPlacePoint, this.cameraLink, required this.wide});

  final LatLng? currentPlacePoint;

  /// Camera shared with the forecast map; only links the cameras.
  final RadarCameraLink? cameraLink;

  /// Map left, controls right ([RainMapCard]); false = one column, square locked map.
  final bool wide;

  @override
  ConsumerState<AccumulationCard> createState() => _AccumulationCardState();
}

class _AccumulationCardState extends ConsumerState<AccumulationCard> {
  late final RadarPlayer _player = RadarPlayer(
    slots: () => ref.read(accumulationLoopProvider(ref.read(rainAccumulationWindowProvider).requireValue)).value?.slots,
    framesPerSecond: () => ref.read(radarFramesPerSecondProvider(_group)).requireValue,
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
    unawaited(ref.read(rainAccumulationWindowProvider.notifier).set(hours));
  }

  void _setFramesPerSecond(int framesPerSecond) {
    unawaited(ref.read(radarFramesPerSecondProvider(_group).notifier).set(framesPerSecond));
    _player.onFramesPerSecondChanged();
  }

  void _retry(int hours) {
    _player.reset();
    ref.invalidate(accumulationLoopProvider(hours));
  }

  void _resetSettings(AsyncValue<int> window, AsyncValue<int> framesPerSecond, AsyncValue<bool> repeat) {
    if (window.hasError) unawaited(ref.read(rainAccumulationWindowProvider.notifier).reset());
    if (framesPerSecond.hasError) unawaited(ref.read(radarFramesPerSecondProvider(_group).notifier).reset());
    if (repeat.hasError) unawaited(ref.read(radarRepeatProvider(_group).notifier).reset());
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
    final window = ref.watch(rainAccumulationWindowProvider);
    final framesPerSecond = ref.watch(radarFramesPerSecondProvider(_group));
    final repeat = ref.watch(radarRepeatProvider(_group));
    if (window.hasError || framesPerSecond.hasError || repeat.hasError) {
      return AppCard(
        title: _cardTitle,
        child: StatusBanner(
          tone: StatusTone.error,
          title: '無法讀取累積雨量設定',
          text: [
            for (final e in [window.error, framesPerSecond.error, repeat.error]) ?e,
          ].join('；'),
          actions: [AppButton(label: '重設設定', small: true, onPressed: () => _resetSettings(window, framesPerSecond, repeat))],
        ),
      );
    }
    if (!window.hasValue || !framesPerSecond.hasValue || !repeat.hasValue) {
      return const AppCard.loading(title: _cardTitle, skeletonHeight: _skeletonHeight);
    }
    final hours = window.requireValue;
    ref.listen(accumulationLoopProvider(hours), (_, _) => _player.onLoopUpdate());
    final loop = ref.watch(accumulationLoopProvider(hours));
    final (meta, (:banner, :map, :playback)) = switch (loop) {
      AsyncError(:final error) => ('無法取得', _failureBody(hours, '$error')),
      AsyncValue(:final value?) => _loopBody(hours, value, framesPerSecond.requireValue, repeat.requireValue),
      _ => ('載入中', _loadingBody()),
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
              style: AppType.caption1.copyWith(color: AppPalette.foreground2, fontWeight: FontWeight.w600),
            ),
            Semantics(
              label: '累積時距',
              container: true,
              child: Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: [for (final h in accumulationWindowHours) AppChip(label: '$h', selected: h == hours, onTap: () => _setWindow(h))],
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
      currentPlacePoint: widget.currentPlacePoint,
      loading: loading,
      muted: muted,
      chipIcon: chipIcon,
      chipText: chipText,
      semanticsLabel: semanticsLabel,
      upcoming: upcoming,
      overlayImages: overlayImages,
    );
  }

  _Body _loadingBody() =>
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

  (String, _Body) _loopBody(int hours, RadarLoop loop, int framesPerSecond, bool repeat) {
    final slots = loop.slots;
    final failed = radarFailedSlots(slots);
    final index = radarShownIndex(slots, _player.playhead);
    if (index == null) {
      if (loop.loading) return ('載入中', _loadingBody());
      return ('無法取得', _failureBody(hours, '${radarNoFrameError(loop, failed)}'));
    }
    final frame = slots[index].frame!;
    // Contract decision 12: the window starts at S = newest slot - window and each frame accumulates from S.
    final start = slots.last.time.subtract(Duration(hours: hours));
    String span(DateTime t) => '${formatTaiwanMonthDayClock(start)} 起累積至 ${formatTaiwanMonthDayClock(t)}';
    final isLast = index == slots.length - 1;
    final noRain = (frame.peakMillimeters ?? double.infinity) < _noRainBelowMillimeters;
    final accumulated = isLast ? '過去 $hours 小時' : span(frame.time);
    final readyCount = radarReadyCount(slots);
    final waiting = _player.waitingOn != null;
    final meta = radarPlaybackMeta(
      buffering: waiting,
      playing: _player.playing,
      loading: loop.loading,
      ready: readyCount,
      total: slots.length,
      framesPerSecond: framesPerSecond,
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
                title: '無法取得 ${failed.length} 張影格',
                text: '${clockText(failed.first.time)} ${firstLine(failed.first.error!)}',
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
                opacity: rainMapOverlayOpacity,
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
            framesPerSecond: framesPerSecond,
            repeat: repeat,
            window: Duration(hours: hours),
            timeText: span,
            onTogglePlay: _player.togglePlay,
            onSeek: _player.seek,
            onFramesPerSecondChanged: _setFramesPerSecond,
            onRepeat: (v) => unawaited(ref.read(radarRepeatProvider(_group).notifier).set(v)),
          ),
        ),
      ),
    );
  }
}
