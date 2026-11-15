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
import '../../data/radar/radar_frame_repository.dart';
import '../location/place_provider.dart';
import 'radar_playback.dart';
import 'radar_provider.dart';
import 'radar_summary.dart';
import 'widgets/playback_card.dart';
import 'widgets/radar_legend.dart';
import 'widgets/radar_map_view.dart';

/// Overlay opacity slider: 10–100 % in 10 % steps, default 60 %.
const _opacityMinPercent = 10;
const _opacityMaxPercent = 100;
const _opacityStepPercent = 10;
const _opacityDefaultPercent = 60;

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
  int _opacityPercent = _opacityDefaultPercent;
  int _fps = radarDefaultFps;
  bool _repeat = true;
  bool _playing = false;

  /// Shown frame; null = the newest one (follows a reload).
  int? _index;
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

  bool get _isComposite => _source == AppConstants.radarTaiwan;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _playing = false;
  }

  int _currentIndex(int count) => (_index ?? count - 1).clamp(0, count - 1);

  /// Chains one single-shot timer per frame: 1/fps between frames, a fixed
  /// pause before restarting.
  void _scheduleTick() {
    _timer?.cancel();
    final count = ref.read(radarLoopProvider(_source)).value?.frames.length;
    if (count == null) {
      setState(_stop);
      return;
    }
    final tick = radarNextTick(index: _currentIndex(count), count: count, fps: _fps, repeat: _repeat);
    if (tick == null) {
      setState(_stop);
      return;
    }
    _timer = Timer(tick.delay, () {
      setState(() => _index = tick.nextIndex);
      _scheduleTick();
    });
  }

  void _togglePlay(int count) {
    if (_playing) {
      setState(_stop);
      return;
    }
    setState(() {
      _playing = true;
      if (_currentIndex(count) == count - 1) _index = 0;
    });
    _scheduleTick();
  }

  void _seek(int i) {
    setState(() => _index = i);
    if (_playing) _scheduleTick();
  }

  void _setFps(int fps) {
    setState(() => _fps = fps);
    if (_playing) _scheduleTick();
  }

  void _setWindow(Duration window) {
    setState(() {
      _stop();
      _index = null;
    });
    ref.read(radarWindowProvider.notifier).set(window);
  }

  void _selectSource(String id) {
    setState(() {
      _stop();
      _index = null;
      _source = id;
    });
  }

  void _refresh() {
    setState(() {
      _stop();
      _index = null;
    });
    ref.invalidate(radarLoopProvider(_source));
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(radarSourceProvider(_source));
    final window = radarEffectiveWindow(ref.watch(radarWindowProvider), source);
    final view = _sourceView(ref.watch(radarLoopProvider(_source)), window, source.maxWindow);
    return AppPageScaffold(
      header: AppPageHeader(
        title: '雷達回波',
        subtitle: view.subtitle,
        subtitleIcon: Icons.schedule,
        actions: [AppIconButton(icon: Icons.refresh, tooltip: '重新整理', onPressed: view.loading ? null : _refresh)],
      ),
      source: view.sourceIds == null ? null : SourceLine(datasetIds: view.sourceIds!),
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
        _sourceCard(),
        if (view.sourceIds != null) _opacityCard(),
        if (view.sourceIds != null && _isComposite) _coverageCard(),
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
    final frames = loop.frames;
    if (frames.isEmpty) {
      return loop.loading ? _loadingView(windowSize: loop.windowSize) : _errorView(loop.listError ?? loop.failures.join('；'));
    }
    final index = _currentIndex(frames.length);
    final frame = frames[index];
    final newest = frames.last;
    final name = _stationNames[_source];
    final summary = radarEchoSummary(
      loop.newestStats!,
      coverage: name == null ? '臺灣本島及周邊海域' : '$name雷達站涵蓋範圍內',
      place: _place,
    );
    final listError = loop.listError;
    final banner = listError != null
        ? StatusBanner(
            tone: StatusTone.error,
            title: '離線，顯示 ${formatTaiwanClock(newest.time)} 的資料',
            text: '$listError',
            actions: [RetryButton(onPressed: _refresh)],
          )
        : loop.failures.isNotEmpty
            ? StatusBanner(
                tone: StatusTone.error,
                title: '${loop.failures.length} 張影格無法取得',
                text: [for (final f in loop.failures) '${formatTaiwanClock(f.frame.time)} ${f.error}'].join('\n'),
                actions: [RetryButton(onPressed: _refresh)],
              )
            : null;
    return _RadarView(
      subtitle: name == null
          ? '觀測 ${formatTaiwanFull(newest.time)} · 每 ${radarFrameStep.inMinutes} 分鐘更新'
          : '$name站 · 觀測 ${formatTaiwanFull(newest.time)}',
      sourceIds: ['雷達回波：官網時間戳記圖', _source],
      loading: loop.loading,
      hero: _heroCard(
        eyebrow: name == null ? '全台合成回波' : '$name雷達站',
        title: summary.title,
        note: name == null ? summary.meta : '${summary.meta}\n僅顯示虛線圈內範圍 · 圈外請改看全台合成',
        banner: banner,
        map: RadarMapView(
          me: _me,
          chipIcon: Icons.schedule,
          chipText: formatTaiwanMonthDayClock(frame.time),
          semanticsLabel: name == null ? '雷達回波地圖' : '$name雷達回波地圖，虛線圈為涵蓋範圍',
          loop: (
            frameCount: frames.length,
            aspect: frame.aspect,
            next: (decodeWidth) => frames[(index + 1) % frames.length].imageProvider(decodeWidth: decodeWidth),
          ),
          overlayBuilder: (decodeWidth) => [
            OverlayImage(
              bounds: frame.bounds,
              opacity: _opacityPercent / 100,
              imageProvider: frame.imageProvider(decodeWidth: decodeWidth),
              gaplessPlayback: true,
            ),
          ],
          extraLayers: name == null ? const [] : _stationLayers(frame.bounds),
        ),
        legend: RadarLegend(showWords: name == null),
      ),
      afterHero: [
        if (loop.loading)
          PlaybackCard(meta: '載入中 ${frames.length} / ${loop.windowSize ?? '…'} 張', loading: true)
        else if (frames.length == 1)
          const PlaybackCard(meta: '僅有最新影格')
        else
          PlaybackCard(
            meta: _playing
                ? '播放中 · $_fps fps${_repeat ? ' · 重複' : ''}'
                : '過去 ${window.inHours} 小時 · ${frames.length} 張',
            frames: PlaybackFrames(
              times: [for (final f in frames) f.time],
              strongestDbz: [for (final f in frames) f.significantDbz],
              index: index,
              playing: _playing,
              fps: _fps,
              repeat: _repeat,
              window: window,
              windowOptions: [for (final w in radarWindowOptions) if (w <= maxWindow) w],
              onTogglePlay: () => _togglePlay(frames.length),
              onSeek: _seek,
              onFps: _setFps,
              onRepeat: (v) => setState(() => _repeat = v),
              onWindow: _setWindow,
            ),
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

  _RadarView _loadingView({int? windowSize}) => _RadarView(
    subtitle: _loadingSubtitle,
    loading: true,
    hero: _heroCard(map: RadarMapView(me: _me, loading: true, muted: true)),
    afterHero: [PlaybackCard(meta: windowSize == null ? '等待影格' : '載入中 0 / $windowSize 張', loading: true)],
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

  AppCard _heroCard({
    String? eyebrow,
    String? title,
    String? note,
    StatusBanner? banner,
    required RadarMapView map,
    Widget? legend,
  }) {
    final titles = eyebrow == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpace.s4,
            children: [
              Text(eyebrow, style: AppType.caption1.copyWith(color: AppPalette.fg3)),
              if (title != null) Text(title, style: AppType.subtitle1.copyWith(color: AppPalette.fg1)),
              if (note != null) Text(note, style: AppType.caption1.copyWith(color: AppPalette.fg3)),
            ],
          );
    return AppCard(
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s16,
        children: [?titles, ?banner, map, ?legend],
      ),
    );
  }

  AppCard _sourceCard() {
    return AppCard(
      title: '雷達來源',
      meta: '${_radarSources.length} 個',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s16,
        children: [
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final (id, label) in _radarSources)
                AppChip(label: label, selected: _source == id, onTap: () => _selectSource(id)),
            ],
          ),
          if (!_isComposite)
            Text('單站雷達：涵蓋範圍以虛線圈表示，越接近圈邊訊號越弱。', style: AppType.caption1.copyWith(color: AppPalette.fg3)),
        ],
      ),
    );
  }

  AppCard _opacityCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s4,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('疊圖透明度', style: AppType.body1.copyWith(color: AppPalette.fg1)),
              Text(
                '$_opacityPercent%',
                style: AppType.body1.copyWith(
                  color: AppPalette.fg1,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppType.tabular,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: const SliderThemeData(
              trackHeight: AppSize.sliderTrack,
              activeTrackColor: AppPalette.brandBg,
              inactiveTrackColor: AppPalette.strokeAccessible,
              thumbColor: AppPalette.brandBg,
              overlayColor: AppPalette.brandBgSubtle,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: AppSize.sliderThumb / 2),
            ),
            child: Slider(
              min: _opacityMinPercent.toDouble(),
              max: _opacityMaxPercent.toDouble(),
              divisions: (_opacityMaxPercent - _opacityMinPercent) ~/ _opacityStepPercent,
              value: _opacityPercent.toDouble(),
              semanticFormatterCallback: (_) => '疊圖透明度',
              onChanged: (v) => setState(() => _opacityPercent = v.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final v in const [_opacityMinPercent, _opacityMaxPercent])
                Text('$v%', style: AppType.caption1.copyWith(color: AppPalette.fg3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coverageCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpace.s16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppPalette.stroke2, width: AppStroke.thin),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpace.s12,
        children: [
          const Icon(Icons.info_outline, size: AppSize.icon20, color: AppPalette.brandFg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpace.s4,
              children: [
                Text('涵蓋範圍：臺灣本島及周邊海域', style: AppType.body1Strong.copyWith(color: AppPalette.fg2)),
                Text('全台合成整合各雷達站。單站雷達僅涵蓋該站周邊，距離越遠、山區背面訊號越弱。', style: AppType.caption1.copyWith(color: AppPalette.fg3)),
              ],
            ),
          ),
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
