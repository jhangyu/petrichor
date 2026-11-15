import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app_shell.dart' show AppTab, appTabProvider;
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/choices.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/status.dart';
import '../../data/models/place.dart';
import '../../data/radar/radar_frame_list.dart';
import '../../data/radar/radar_loop.dart';
import '../../data/radar/radar_source.dart' show RadarStaleListException;
import '../location/place_provider.dart';
import 'radar_playback.dart';
import 'radar_provider.dart';
import 'widgets/playback_card.dart';
import 'widgets/radar_legend.dart';
import 'widgets/radar_map_view.dart';

/// Station coverage ring (dashed): points on the circle and dash pattern in px.
const _ringPoints = 72;
const _ringStrokeWidth = 1.5;
const _ringDash = [4.0, 4.0];
const _stationDotRadius = 3.5;
const _fullCircleDegrees = 360;

const _stationNames = {AppConstants.radarShulin: '樹林', AppConstants.radarNantun: '南屯', AppConstants.radarLinyuan: '林園'};

const _radarSources = [
  (AppConstants.radarTaiwan, '全台合成'),
  (AppConstants.radarShulin, '樹林'),
  (AppConstants.radarNantun, '南屯'),
  (AppConstants.radarLinyuan, '林園'),
];

const _loadingSubtitle = '正在取得最新觀測…';
const _unreachableSubtitle = '無法連線中央氣象署';
const _noEchoNotice = '地圖上沒有回波，不代表沒有下雨。';

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  String _source = AppConstants.radarTaiwan;
  int _fps = radarDefaultFps;
  bool _repeat = true;
  bool _playing = false;

  /// Time of the shown slot; null = the newest ready one (page open, reload,
  /// and before play starts from the oldest).
  DateTime? _playhead;

  /// Time of the pending slot playback stopped at (緩衝中); null when not
  /// buffering. Resumed by the loop update that makes it ready (see [build]),
  /// never by a timer. The map keeps the last shown frame meanwhile.
  DateTime? _waitingOn;

  /// Frame-rate / repeat-pause clock between shown frames.
  Timer? _timer;

  /// Current place; null while loading, on error or without a place.
  Place? get _place => switch (ref.watch(currentPlaceProvider)) {
    AsyncData(value: PlaceSelected(:final place)) => place,
    _ => null,
  };

  /// Current place as a map point.
  LatLng? get _me => switch (_place) {
    final place? => LatLng(place.latitude, place.longitude),
    null => null,
  };

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _playing = false;
    _waitingOn = null;
  }

  List<RadarSlot>? get _slots => ref.read(radarLoopProvider(_source)).value?.slots;

  /// Takes the next step after the playhead: shows the next ready slot after
  /// 1/fps (at once when [immediate]: play start, or resuming from 緩衝中), or
  /// stops at a pending one, or ends.
  void _advance({required bool immediate}) {
    _timer?.cancel();
    final slots = _slots;
    final step = slots == null ? null : radarNextStep(slots: slots, after: _playhead, fps: _fps, repeat: _repeat);
    switch (step) {
      case null:
        setState(_stop);
      case RadarWait(:final time):
        setState(() => _waitingOn = time);
      case RadarShow(:final time, :final delay):
        void show() {
          setState(() {
            _playhead = time;
            _waitingOn = null;
          });
          _advance(immediate: false);
        }
        if (immediate) {
          show();
        } else {
          _timer = Timer(delay, show);
        }
    }
  }

  void _togglePlay() {
    if (_playing) {
      setState(_stop);
      return;
    }
    final slots = _slots!;
    final head = _playhead;
    // At (or before reaching) the newest ready frame: play from the oldest.
    final fromStart = head == null || !slots.any((s) => s.state == RadarSlotState.ready && s.time.isAfter(head));
    setState(() {
      _playing = true;
      if (fromStart) _playhead = null;
    });
    _advance(immediate: fromStart);
  }

  void _seek(DateTime time) {
    setState(() {
      _playhead = time;
      _waitingOn = null;
    });
    if (_playing) _advance(immediate: false);
  }

  void _setFps(int fps) {
    setState(() => _fps = fps);
    if (_playing && _waitingOn == null) _advance(immediate: false);
  }

  void _setWindow(Duration window) {
    setState(() {
      _stop();
      _playhead = null;
    });
    ref.read(radarWindowProvider.notifier).set(window);
  }

  void _selectSource(String id) {
    setState(() {
      _stop();
      _playhead = null;
      _source = id;
    });
  }

  void _setOpacity(int percent) => unawaited(ref.read(radarOpacityProvider.notifier).set(percent));

  void _refresh() {
    setState(() {
      _stop();
      _playhead = null;
    });
    ref.invalidate(radarLoopProvider(_source));
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(radarSourceProvider(_source));
    final window = radarEffectiveWindow(ref.watch(radarWindowProvider), source);
    // Each loop update may make the slot playback waits on ready (or failed).
    ref.listen(radarLoopProvider(_source), (_, _) {
      if (_playing && _waitingOn != null) _advance(immediate: true);
    });
    final view = _sourceView(ref.watch(radarLoopProvider(_source)), window, source.maxWindow);
    return AppPageScaffold(
      header: AppPageHeader(
        title: '雷達回波',
        subtitle: view.subtitle,
        subtitleIcon: Icons.schedule,
        actions: [AppIconButton(icon: Icons.refresh, tooltip: '重新整理', onPressed: view.loading ? null : _refresh)],
      ),
      children: [
        if (ref.watch(currentPlaceProvider) case AsyncData(value: NoPlace(:final reason)))
          StatusBanner(
            tone: StatusTone.permission,
            title: '尚未選定地點',
            text: '${locationFailureMessage(reason)}。雷達圖仍可查看，但地圖上不會標示你的位置。',
            actions: [
              AppButton(
                label: '選擇地點',
                small: true,
                onPressed: () => ref.read(appTabProvider.notifier).select(AppTab.location),
              ),
            ],
          ),
        view.hero,
        ...view.afterHero,
        if (view.sourceIds != null)
          Text(
            '資料來源：中央氣象署 官網雷達回波圖',
            textAlign: TextAlign.center,
            style: AppType.caption1.copyWith(color: AppPalette.fg3),
          ),
      ],
    );
  }

  // ---- views (one path for every source) ----

  _RadarView _sourceView(AsyncValue<RadarLoop> async, Duration window, Duration maxWindow) {
    return switch (async) {
      AsyncError(:final error) => _errorView(error),
      AsyncValue(:final value?) => _loopView(value, window, maxWindow),
      _ => _loadingView(),
    };
  }

  _RadarView _loopView(RadarLoop loop, Duration window, Duration maxWindow) {
    final opacity = ref.watch(radarOpacityProvider);
    final opacityPercent = opacity.value;
    final opacityBanner = switch (opacity) {
      AsyncError(:final error) => RadarOpacityErrorBanner(error: error, onReset: () => _setOpacity(radarOpacityDefaultPercent)),
      _ => null,
    };
    final opacityControl = switch (opacity) {
      AsyncData(:final value) => RadarOpacitySlider(percent: value, onChanged: _setOpacity),
      _ => null,
    };
    final slots = loop.slots;
    final failed = [for (final s in slots) if (s.state == RadarSlotState.failed) s];
    final index = radarShownIndex(slots, _playhead);
    if (index == null) {
      return loop.loading
          ? _loadingView(listed: slots.length)
          : _errorView(loop.listError ?? failed.map((s) => s.error).join('；'));
    }
    final frame = slots[index].frame!;
    final newest = slots[radarShownIndex(slots, null)!].frame!;
    final readyCount = slots.where((s) => s.state == RadarSlotState.ready).length;
    final name = _stationNames[_source];
    final listError = loop.listError;
    final banner = listError != null
        ? StatusBanner(
            tone: StatusTone.error,
            title: listError is RadarStaleListException
                ? '資料未更新，最新影格 ${formatTaiwanClock(newest.time)}'
                : '離線，顯示 ${formatTaiwanClock(newest.time)} 的資料',
            text: '$listError',
            actions: [RetryButton(onPressed: _refresh)],
          )
        : failed.isNotEmpty
            ? _FailureBanner(failed: failed, onRetry: _refresh)
            : null;
    return _RadarView(
      subtitle: name == null
          ? '觀測 ${formatTaiwanFull(newest.time)} · 每 ${radarFrameStep.inMinutes} 分鐘更新'
          : '$name站 · 觀測 ${formatTaiwanFull(newest.time)}',
      sourceIds: [_source],
      loading: loop.loading,
      hero: _heroCard(
        banner: switch ((banner, opacityBanner)) {
          (final a?, final b?) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: AppSpace.s16, children: [a, b]),
          (final a?, null) => a,
          (null, final b) => b,
        },
        map: RadarMapView(
          me: _me,
          chipIcon: Icons.schedule,
          chipText: formatTaiwanMonthDayClock(frame.time),
          semanticsLabel: name == null ? '雷達回波地圖' : '$name雷達回波地圖，虛線圈為涵蓋範圍',
          upcoming: radarUpcomingFrames(slots, _playhead, count: radarPreDecodeCount),
          overlayImages: [
            if (opacityPercent != null)
              OverlayImage(
                bounds: frame.bounds,
                opacity: opacityPercent / 100,
                imageProvider: frame.imageProvider,
                gaplessPlayback: true,
              ),
          ],
          extraLayers: name == null ? const [] : _stationLayers(frame.bounds),
        ),
        legend: const RadarLegend(),
      ),
      afterHero: [
        if (slots.length == 1 && !loop.loading)
          PlaybackCard(meta: '僅有最新影格', opacity: opacityControl)
        else
          PlaybackCard(
            meta: _waitingOn != null
                ? '緩衝中 · 已就緒 $readyCount / ${slots.length} 張'
                : _playing
                    ? '播放中 · $_fps fps${_repeat ? ' · 重複' : ''}'
                    : loop.loading
                        ? '載入中 $readyCount / ${slots.length} 張'
                        : '過去 ${window.inHours} 小時 · ${slots.length} 張',
            playback: PlaybackFrames(
              slots: slots,
              index: index,
              current: radarCurrentCell(slots, shown: index, waitingOn: _waitingOn),
              buffering: _waitingOn != null,
              playing: _playing,
              fps: _fps,
              repeat: _repeat,
              window: window,
              windowOptions: [for (final w in radarWindowOptions) if (w <= maxWindow) w],
              onTogglePlay: _togglePlay,
              onSeek: _seek,
              onFps: _setFps,
              onRepeat: (v) => setState(() => _repeat = v),
              onWindow: _setWindow,
            ),
            opacity: opacityControl,
          ),
      ],
    );
  }

  /// Dashed coverage ring and station dot of a station image covering [bounds].
  List<Widget> _stationLayers(LatLngBounds bounds) {
    final center = bounds.center;
    final radius = const Distance().as(LengthUnit.Meter, center, LatLng(bounds.north, center.longitude));
    return [
      PolygonLayer(
        polygons: [
          Polygon(
            points: [
              for (var i = 0; i < _ringPoints; i++)
                const Distance().offset(center, radius, i * _fullCircleDegrees / _ringPoints),
            ],
            borderColor: AppPalette.brandStroke,
            borderStrokeWidth: _ringStrokeWidth,
            pattern: StrokePattern.dashed(segments: _ringDash),
          ),
        ],
      ),
      MarkerLayer(
        markers: [
          Marker(
            point: center,
            width: _stationDotRadius * 2,
            height: _stationDotRadius * 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppPalette.brandBg,
                border: Border.all(color: AppPalette.bg1, width: _ringStrokeWidth),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  _RadarView _loadingView({int? listed}) => _RadarView(
    subtitle: _loadingSubtitle,
    loading: true,
    hero: _heroCard(map: RadarMapView(me: _me, loading: true, muted: true)),
    afterHero: [PlaybackCard(meta: listed == null || listed == 0 ? '等待影格' : '載入中 0 / $listed 張', loading: true)],
  );

  _RadarView _errorView(Object error) => _RadarView(
    subtitle: _unreachableSubtitle,
    hero: _heroCard(
      banner: StatusBanner(
        tone: StatusTone.error,
        title: '無法取得雷達圖',
        text: '$error。$_noEchoNotice',
        actions: [RetryButton(onPressed: _refresh)],
      ),
      map: RadarMapView(
        me: _me,
        muted: true,
        chipIcon: Icons.cloud_off_outlined,
        chipText: '無雷達資料',
        semanticsLabel: '地圖，無雷達資料',
      ),
    ),
  );

  // ---- cards ----

  /// Radar map card: source switch on top, then [banner], the map and [legend].
  AppCard _heroCard({Widget? banner, required RadarMapView map, Widget? legend}) {
    return AppCard(
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s16,
        children: [
          Semantics(
            label: '雷達站',
            container: true,
            child: Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final (id, label) in _radarSources)
                  AppChip(label: label, selected: _source == id, onTap: () => _selectSource(id)),
              ],
            ),
          ),
          ?banner,
          map,
          ?legend,
        ],
      ),
    );
  }
}

/// What the page shows for the current source and data state.
class _RadarView {
  const _RadarView({
    required this.subtitle,
    required this.hero,
    this.afterHero = const [],
    this.sourceIds,
    this.loading = false,
  });

  final String subtitle;
  final Widget hero;
  final List<Widget> afterHero;

  /// Dataset ids for the 資料來源 line; null on loading / error frames.
  final List<String>? sourceIds;
  final bool loading;
}

/// Shown above the map while the saved overlay opacity is unreadable: the radar
/// overlay is hidden until the user resets the setting.
class RadarOpacityErrorBanner extends StatelessWidget {
  const RadarOpacityErrorBanner({super.key, required this.error, required this.onReset});

  final Object error;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return StatusBanner(
      tone: StatusTone.error,
      title: '雷達疊圖已隱藏：儲存的透明度設定無法讀取',
      text: '$error。重設後即可再顯示雷達疊圖。',
      actions: [AppButton(label: '重設為 $radarOpacityDefaultPercent%', small: true, onPressed: onReset)],
    );
  }
}

/// Most failed frames listed in the expandable details; the title always shows
/// the full count.
const _failureDetailMaxLines = 20;

/// Failed-frame banner: count, time range and the first cause on one line; every
/// frame (up to [_failureDetailMaxLines]) with its cause under 「詳細」.
class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failed, required this.onRetry});

  /// Failed slots, oldest first.
  final List<RadarSlot> failed;
  final VoidCallback onRetry;

  static String _oneLine(Object error) => '$error'.trim().split('\n').first.trim();

  @override
  Widget build(BuildContext context) {
    final times = [for (final f in failed) f.time];
    final range = times.first == times.last
        ? formatTaiwanClock(times.first)
        : '${formatTaiwanClock(times.first)}–${formatTaiwanClock(times.last)}';
    final shown = failed.take(_failureDetailMaxLines);
    final hidden = failed.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatusBanner(
          tone: StatusTone.error,
          title: '${failed.length} 張影格無法取得',
          text: '$range · ${_oneLine(failed.first.error!)}',
          actions: [RetryButton(onPressed: onRetry)],
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: AppPalette.transparent),
          child: ExpansionTile(
            title: Text('詳細（${failed.length} 張）', style: AppType.caption1.copyWith(color: AppPalette.fg3)),
            childrenPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            children: [
              for (final f in shown)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${formatTaiwanClock(f.time)} ${_oneLine(f.error!)}',
                    style: AppType.caption1.copyWith(color: AppPalette.fg3),
                  ),
                ),
              if (hidden > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('…另 $hidden 張', style: AppType.caption1.copyWith(color: AppPalette.fg3)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
