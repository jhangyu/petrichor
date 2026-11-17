import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/navigation/app_tab.dart' show AppTab, appTabProvider;
import '../../core/api/cwa_datasets.dart';
import '../../core/layout/adaptive.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/time/taiwan_time.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/choices.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/status.dart';
import '../../data/models/place.dart';
import '../../data/radar/radar_bounds.dart' show radarStationById, radarStations;
import '../../data/radar/radar_frame_list.dart';
import '../../data/radar/radar_loop.dart';
import '../../data/radar/radar_source.dart' show RadarStaleListException;
import '../place/place_provider.dart';
import '../place/location_failure_text.dart';
import 'playback_frames.dart';
import 'radar_playback.dart';
import 'radar_player.dart';
import 'radar_provider.dart';
import 'radar_webp_image.dart';
import 'widgets/playback_card.dart';
import 'widgets/radar_legend.dart';
import 'widgets/radar_map_view.dart';
import 'widgets/radar_opacity_slider.dart';
import 'widgets/station_layers.dart';

String? _stationName(String id) => radarStationById(id)?.name;

final _radarSources = [(CwaDatasets.radarTaiwanDatasetId, '全台合成'), for (final s in radarStations) (s.datasetId, s.name)];

const _loadingSubtitle = '正在取得最新觀測…';
const _unreachableSubtitle = '無法連線中央氣象署';
/// Height of the hero card around its map in side-by-side mode: card padding,
/// source chips, legend and the three gaps. The map box takes the rest of the pane.
const _heroChromeHeight =
    AppSpace.s16 + AppSpace.s20 + AppSize.touch + AppSize.legendBar + AppSpace.s4 + AppSize.icon16 + 2 * AppSpace.s16;
const _noEchoNotice = '地圖上沒有回波，不代表沒有下雨。';

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  String _selectedDatasetId = CwaDatasets.radarTaiwanDatasetId;
  late final RadarPlayer _player = RadarPlayer(
    slots: () => ref.read(radarLoopProvider(_selectedDatasetId)).value?.slots,
    framesPerSecond: () => ref.read(radarFramesPerSecondProvider(_group)).requireValue,
    repeat: () => ref.read(radarRepeatProvider(_group)).requireValue,
    onChanged: () => setState(() {}),
  );

  /// Current place; null while loading, on error or without a place.
  Place? get _place => switch (ref.watch(currentPlaceProvider)) {
    AsyncData(value: PlaceSelected(:final place)) => place,
    _ => null,
  };

  /// Current place as a map point.
  LatLng? get _currentPlacePoint => switch (_place) {
    final place? => LatLng(place.latitude, place.longitude),
    null => null,
  };

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  RadarSettingsGroup get _group => radarSettingsGroupOf(_selectedDatasetId);

  void _setFramesPerSecond(int framesPerSecond) {
    unawaited(ref.read(radarFramesPerSecondProvider(_group).notifier).set(framesPerSecond));
    _player.onFramesPerSecondChanged();
  }

  void _setWindow(Duration window) {
    _player.reset();
    unawaited(ref.read(radarWindowProvider(_group).notifier).set(window));
  }

  void _selectSource(String id) {
    _selectedDatasetId = id;
    _player.reset();
  }

  void _setOpacity(int percent) => unawaited(ref.read(radarOpacityProvider(_group).notifier).set(percent));

  void _refresh() {
    _player.reset();
    retryRadarBasemap();
    ref.invalidate(radarLoopProvider(_selectedDatasetId));
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(radarSourceProvider(_selectedDatasetId));
    final selectedWindow = ref.watch(radarWindowProvider(_group));
    final framesPerSecond = ref.watch(radarFramesPerSecondProvider(_group));
    final repeat = ref.watch(radarRepeatProvider(_group));
    // Each loop update may make the slot playback waits on ready (or failed).
    ref.listen(radarLoopProvider(_selectedDatasetId), (_, _) {
      _player.onLoopUpdate();
    });
    final loop = ref.watch(radarLoopProvider(_selectedDatasetId));
    final view = switch ((selectedWindow, framesPerSecond, repeat)) {
      (AsyncValue(hasValue: true), AsyncValue(hasValue: true), AsyncValue(hasValue: true)) => _sourceView(
        loop,
        radarEffectiveWindow(selectedWindow.requireValue, source),
        source.maxWindow,
        framesPerSecond.requireValue,
        repeat.requireValue,
      ),
      _ => _settingsView(selectedWindow, framesPerSecond, repeat),
    };
    final header = AppPageHeader(
      title: '雷達回波',
      subtitle: view.subtitle,
      subtitleIcon: Icons.schedule,
      actions: [AppIconButton(icon: Icons.refresh, tooltip: '重新整理', onPressed: view.loading ? null : _refresh)],
    );
    final placeBanner = switch (ref.watch(currentPlaceProvider)) {
      AsyncData(value: NoPlace(:final reason)) => StatusBanner(
        tone: StatusTone.permission,
        title: '尚未選定地點',
        text: '${locationFailureMessage(reason)}。雷達圖仍可查看，但地圖上不會標示你的位置。',
        actions: [
          AppButton(
            label: '選擇地點',
            small: true,
            onPressed: () => ref.read(appTabProvider.notifier).select(AppTab.settings),
          ),
        ],
      ),
      _ => null,
    };
    final sourceLine = !view.showSourceLine
        ? null
        : Text(
            '資料來源：中央氣象署 官網雷達回波圖',
            textAlign: TextAlign.center,
            style: AppType.caption1.copyWith(color: AppPalette.foreground3),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final margin = WindowSizeClass.of(context).pageMargin;
        final sideBySide = AppTwoPane.fitsWindow(context, constraints.maxWidth - 2 * margin);
        if (!sideBySide) {
          return AppPageScaffold(
            header: header,
            children: [
              if (placeBanner != null) AppGridItem.full(child: placeBanner),
              view.hero(null),
              ...view.afterHero,
              if (sourceLine != null) AppGridItem.full(child: sourceLine),
            ],
          );
        }
        return AppPageScaffold.fill(
          header: header,
          body: AppTwoPane(
            mainPane: LayoutBuilder(
              builder: (context, pane) => _PaneScroll(
                child: view.hero(math.max(AppLayout.paneMinimumWidth, pane.maxHeight - _heroChromeHeight)),
              ),
            ),
            sidePane: _PaneScroll(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpace.s16,
                children: [?placeBanner, ...view.afterHero, ?sourceLine],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---- views (one path for every source) ----

  _RadarView _sourceView(AsyncValue<RadarLoop> async, Duration window, Duration maxWindow, int framesPerSecond, bool repeat) {
    return switch (async) {
      AsyncError(:final error) => _errorView(error),
      AsyncValue(:final value?) => _loopView(value, window, maxWindow, framesPerSecond, repeat),
      _ => _loadingView(),
    };
  }

  _RadarView _loopView(RadarLoop loop, Duration window, Duration maxWindow, int framesPerSecond, bool repeat) {
    final opacity = ref.watch(radarOpacityProvider(_group));
    final opacityPercent = opacity.value;
    final opacityBanner = switch (opacity) {
      AsyncError(:final error) => RadarOpacityErrorBanner(error: error, overlayHidden: !opacity.hasValue, onReset: () => _setOpacity(radarOpacityDefaultPercent)),
      _ => null,
    };
    final opacityControl = switch (opacity) {
      AsyncData(:final value) => RadarOpacitySlider(percent: value, onChanged: _setOpacity),
      _ => null,
    };
    final slots = loop.slots;
    final failed = radarFailedSlots(slots);
    final index = radarShownIndex(slots, _player.playhead);
    if (index == null) {
      return loop.isLoading
          ? _loadingView(listed: slots.length)
          : _errorView(radarNoFrameError(loop, failed));
    }
    final frame = slots[index].frame!;
    final newest = slots[radarShownIndex(slots, null)!].frame!;
    final name = _stationName(_selectedDatasetId);
    return _RadarView(
      subtitle: _loopSubtitle(name, newest),
      showSourceLine: true,
      loading: loop.isLoading,
      hero: _heroCard(
        banner: switch ((_loopBanner(loop, failed, newest), opacityBanner)) {
          (final a?, final b?) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: AppSpace.s16, children: [a, b]),
          (final a?, null) => a,
          (null, final b) => b,
        },
        map: RadarMapView(
          currentPlacePoint: _currentPlacePoint,
          chipIcon: Icons.schedule,
          chipText: formatTaiwanMonthDayClock(frame.time),
          semanticsLabel: name == null ? '雷達回波地圖' : '$name雷達回波地圖，虛線圈為涵蓋範圍',
          upcoming: radarUpcomingFrames(slots, _player.playhead, count: radarPreDecodeCount),
          overlayImages: [
            if (opacityPercent != null)
              OverlayImage(
                bounds: frame.bounds,
                opacity: opacityPercent / 100,
                imageProvider: frame.imageProvider,
                gaplessPlayback: true,
              ),
          ],
          extraLayers: name == null ? const [] : radarStationLayers(frame.bounds),
        ),
        legend: const RadarLegend(),
      ),
      afterHero: [_playbackCard(loop, index, window, maxWindow, framesPerSecond, repeat, opacityControl)],
    );
  }

  Widget? _loopBanner(RadarLoop loop, List<RadarSlot> failed, RadarFrame newest) {
    final listError = loop.listError;
    return listError != null
        ? StatusBanner(
            tone: StatusTone.error,
            title: listError is RadarStaleListException
                ? '資料未更新，最新影格 ${clockText(newest.time)}'
                : '離線，顯示 ${clockText(newest.time)} 的資料',
            text: '$listError',
            actions: [RetryButton(onPressed: _refresh)],
          )
        : failed.isNotEmpty
            ? _FailureBanner(failed: failed, onRetry: _refresh)
            : null;
  }

  String _loopSubtitle(String? name, RadarFrame newest) => name == null
      ? '觀測 ${formatTaiwanDateTime(newest.time)} · 每 ${radarWebsiteFrameInterval.inMinutes} 分鐘更新'
      : '$name站 · 觀測 ${formatTaiwanDateTime(newest.time)}';

  Widget _playbackCard(
    RadarLoop loop,
    int index,
    Duration window,
    Duration maxWindow,
    int framesPerSecond,
    bool repeat,
    Widget? opacityControl,
  ) {
    final slots = loop.slots;
    if (slots.length == 1 && !loop.isLoading) return PlaybackCard(meta: '僅有最新影格', opacity: opacityControl);
    final readyCount = radarReadyCount(slots);
    return PlaybackCard(
      meta: radarPlaybackMeta(
        buffering: _player.waitingOn != null,
        playing: _player.playing,
        loading: loop.isLoading,
        ready: readyCount,
        total: slots.length,
        framesPerSecond: framesPerSecond,
        repeat: repeat,
        idle: '過去 ${window.inHours} 小時 · ${slots.length} 張',
      ),
      playback: PlaybackFrames(
        slots: slots,
        index: index,
        current: radarCurrentCell(slots, shown: index, waitingOn: _player.waitingOn),
        buffering: _player.waitingOn != null,
        playing: _player.playing,
        framesPerSecond: framesPerSecond,
        repeat: repeat,
        window: window,
        windowOptions: [for (final w in radarWindowOptions) if (w <= maxWindow) w],
        onTogglePlay: () {
          loop.loadRest();
          _player.togglePlay();
        },
        onSeek: _player.seek,
        onFramesPerSecondChanged: _setFramesPerSecond,
        onRepeat: (v) => unawaited(ref.read(radarRepeatProvider(_group).notifier).set(v)),
        onWindow: _setWindow,
      ),
      opacity: opacityControl,
    );
  }

  _RadarView _loadingView({int? listed}) => _RadarView(
    subtitle: _loadingSubtitle,
    loading: true,
    hero: _heroCard(map: RadarMapView(currentPlacePoint: _currentPlacePoint, loading: true, muted: true)),
    afterHero: [PlaybackCard(meta: listed == null || listed == 0 ? '等待影格' : '載入中 0 / $listed 張', loading: true)],
  );

  /// Playback settings still loading, or unreadable (error without a value):
  /// the error with a reset to the group's defaults.
  _RadarView _settingsView(AsyncValue<Duration> window, AsyncValue<int> framesPerSecond, AsyncValue<bool> repeat) {
    final windowBroken = window.hasError && !window.hasValue;
    final framesPerSecondBroken = framesPerSecond.hasError && !framesPerSecond.hasValue;
    final repeatBroken = repeat.hasError && !repeat.hasValue;
    if (!windowBroken && !framesPerSecondBroken && !repeatBroken) return _loadingView();
    return _RadarView(
      subtitle: _unreachableSubtitle,
      hero: _heroCard(
        banner: StatusBanner(
          tone: StatusTone.error,
          title: '無法讀取播放設定',
          text: [if (windowBroken) '${window.error}', if (framesPerSecondBroken) '${framesPerSecond.error}', if (repeatBroken) '${repeat.error}'].join('；'),
          actions: [
            AppButton(
              label: '重設播放設定',
              small: true,
              onPressed: () {
                if (windowBroken) unawaited(ref.read(radarWindowProvider(_group).notifier).reset());
                if (framesPerSecondBroken) unawaited(ref.read(radarFramesPerSecondProvider(_group).notifier).reset());
                if (repeatBroken) unawaited(ref.read(radarRepeatProvider(_group).notifier).reset());
              },
            ),
          ],
        ),
        map: RadarMapView(currentPlacePoint: _currentPlacePoint, muted: true, chipIcon: Icons.cloud_off_outlined, chipText: '無雷達資料', semanticsLabel: '地圖，無雷達資料'),
      ),
    );
  }

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
        currentPlacePoint: _currentPlacePoint,
        muted: true,
        chipIcon: Icons.cloud_off_outlined,
        chipText: '無雷達資料',
        semanticsLabel: '地圖，無雷達資料',
      ),
    ),
  );

  // ---- cards ----

  /// Radar map card: source switch on top, then [banner], the map and [legend].
  Widget Function(double? mapHeight) _heroCard({Widget? banner, required RadarMapView map, Widget? legend}) {
    return (mapHeight) => AppCard(
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
                  AppChip(label: label, selected: _selectedDatasetId == id, onTap: () => _selectSource(id)),
              ],
            ),
          ),
          ?banner,
          mapHeight == null
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: AppLayout.paneMaximumWidth),
                    child: map,
                  ),
                )
              : SizedBox(height: mapHeight, child: map),
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
    this.showSourceLine = false,
    this.loading = false,
  });

  final String subtitle;
  /// Hero card for a map box of the given height; null = the map's natural aspect.
  final Widget Function(double? mapHeight) hero;
  final List<Widget> afterHero;

  /// Whether the 資料來源 line shows; false on loading / error frames.
  final bool showSourceLine;
  final bool loading;
}

/// How far card shadows may spill sideways out of a pane: past the deepest
/// shadow (AppShadows.s8), within the pane gap and page margin.
const _paneShadowBleed = AppSpace.s16;

/// Vertical scroll of one side-by-side pane. The cards fill the pane width, so
/// a scroll view clipping at its own edges cuts their side shadows; this one
/// clips only at the top and bottom (where scrolled content must stop).
class _PaneScroll extends StatelessWidget {
  const _PaneScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    clipper: const _VerticalClipper(),
    child: SingleChildScrollView(clipBehavior: Clip.none, child: child),
  );
}

class _VerticalClipper extends CustomClipper<Rect> {
  const _VerticalClipper();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-_paneShadowBleed, 0, size.width + _paneShadowBleed, size.height);

  @override
  bool shouldReclip(_VerticalClipper oldClipper) => false;
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

  @override
  Widget build(BuildContext context) {
    final times = [for (final f in failed) f.time];
    final range = times.first == times.last
        ? clockText(times.first)
        : '${clockText(times.first)}–${clockText(times.last)}';
    final shown = failed.take(_failureDetailMaxLines);
    final hidden = failed.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatusBanner(
          tone: StatusTone.error,
          title: '無法取得 ${failed.length} 張影格',
          text: '$range · ${firstLine(failed.first.error!)}',
          actions: [RetryButton(onPressed: onRetry)],
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: AppPalette.transparent),
          child: ExpansionTile(
            title: Text('詳細（${failed.length} 張）', style: AppType.caption1.copyWith(color: AppPalette.foreground3)),
            childrenPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            children: [
              for (final f in shown)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${clockText(f.time)} ${firstLine(f.error!)}',
                    style: AppType.caption1.copyWith(color: AppPalette.foreground3),
                  ),
                ),
              if (hidden > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('…另 $hidden 張', style: AppType.caption1.copyWith(color: AppPalette.foreground3)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
