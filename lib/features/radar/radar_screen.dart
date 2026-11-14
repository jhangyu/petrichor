import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/choices.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/status.dart';
import '../../data/radar/radar_bounds.dart';
import '../../data/radar/radar_frame_list.dart';
import '../../data/radar/radar_frame_repository.dart';
import 'radar_playback.dart';
import 'radar_provider.dart';
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

const _stationNames = {
  AppConstants.radarShulin: '樹林',
  AppConstants.radarNantun: '南屯',
  AppConstants.radarLinyuan: '林園',
};

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
    final count = ref.read(radarFramesProvider).value?.length;
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

  void _setWindow(int frames) {
    setState(() {
      _stop();
      _index = null;
    });
    ref.read(radarWindowFramesProvider.notifier).set(frames);
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
    if (_isComposite) {
      ref.invalidate(radarFramesProvider);
    } else {
      ref.invalidate(openDataRadarProvider(_source));
    }
  }

  @override
  Widget build(BuildContext context) {
    final windowFrames = ref.watch(radarWindowFramesProvider);
    final view = _isComposite
        ? _compositeView(ref.watch(radarFramesProvider), windowFrames)
        : _stationView(ref.watch(openDataRadarProvider(_source)));
    return AppPageScaffold(
      header: AppPageHeader(
        title: '雷達回波',
        subtitle: view.subtitle,
        subtitleIcon: Icons.schedule,
        actions: [AppIconButton(icon: Icons.refresh, tooltip: '重新整理', onPressed: view.loading ? null : _refresh)],
      ),
      source: view.sourceIds == null ? null : SourceLine(datasetIds: view.sourceIds!),
      children: [
        view.hero,
        ...view.afterHero,
        _sourceCard(),
        if (view.sourceIds != null) _opacityCard(),
        if (view.sourceIds != null && _isComposite) _coverageCard(),
      ],
    );
  }

  // ---- views per source ----

  _RadarView _compositeView(AsyncValue<List<RadarFrame>> async, int windowFrames) {
    return async.when(
      loading: () => _loadingView(),
      error: (e, _) => _errorView(e),
      data: (frames) {
        final index = _currentIndex(frames.length);
        final frame = frames[index];
        return _RadarView(
          subtitle: '觀測 ${formatTaiwanFull(frames.last.time)} · 每 ${radarFrameStep.inMinutes} 分鐘更新',
          sourceIds: const ['雷達回波：官網時間戳記圖', AppConstants.radarTaiwan],
          hero: _heroCard(
            eyebrow: '全台合成回波',
            map: RadarMapView(
              playing: _playing,
              chipIcon: Icons.schedule,
              chipText: formatTaiwanMonthDayClock(frame.time),
              semanticsLabel: '雷達回波地圖',
              overlayBuilder: (decodeWidth) => [
                for (final band in frame.bands)
                  OverlayImage(
                    bounds: band.bounds,
                    opacity: _opacityPercent / 100,
                    imageProvider: band.imageProvider(decodeWidth: decodeWidth),
                    gaplessPlayback: true,
                  ),
              ],
            ),
            legend: const RadarLegend(showWords: true),
          ),
          afterHero: [
            PlaybackCard(
              meta: _playing
                  ? '播放中 · $_fps fps${_repeat ? ' · 重複' : ''}'
                  : '過去 ${windowFrames ~/ radarFramesPerHour} 小時 · ${frames.length} 張',
              frames: PlaybackFrames(
                times: [for (final f in frames) f.time],
                index: index,
                playing: _playing,
                fps: _fps,
                repeat: _repeat,
                windowFrames: windowFrames,
                onTogglePlay: () => _togglePlay(frames.length),
                onSeek: _seek,
                onFps: _setFps,
                onRepeat: (v) => setState(() => _repeat = v),
                onWindowFrames: _setWindow,
              ),
            ),
          ],
        );
      },
    );
  }

  _RadarView _stationView(AsyncValue<OpenDataRadarImage> async) {
    final name = _stationNames[_source]!;
    if (!AppConstants.hasApiKey) {
      return _RadarView(
        subtitle: _unreachableSubtitle,
        hero: AppCard(
          hero: true,
          child: EmptyState(title: '尚未設定 API 金鑰', text: '雷達圖需要中央氣象署開放資料金鑰。設定後即可顯示回波。'),
        ),
      );
    }
    return async.when(
      loading: () => _loadingView(),
      error: (e, _) => _errorView(e),
      data: (image) {
        final center = image.bounds.center;
        final radius = const Distance().as(LengthUnit.Meter, center, LatLng(image.bounds.north, center.longitude));
        return _RadarView(
          subtitle: '$name站 · 觀測 ${formatTaiwanFull(image.time)}',
          sourceIds: [_source],
          hero: _heroCard(
            eyebrow: '$name雷達站',
            note: '僅顯示虛線圈內範圍 · 圈外請改看全台合成',
            map: RadarMapView(
              chipIcon: Icons.schedule,
              chipText: formatTaiwanMonthDayClock(image.time),
              semanticsLabel: '$name雷達回波地圖，虛線圈為涵蓋範圍',
              overlayBuilder: (_) => [
                OverlayImage(
                  bounds: image.bounds,
                  opacity: _opacityPercent / 100,
                  imageProvider: NetworkImage(image.imageUrl),
                ),
              ],
              extraLayers: [
                PolygonLayer(polygons: [
                  Polygon(
                    points: [
                      for (var i = 0; i < _ringPoints; i++)
                        const Distance().offset(center, radius, i * _fullCircleDegrees / _ringPoints),
                    ],
                    borderColor: AppPalette.brandStroke,
                    borderStrokeWidth: _ringStrokeWidth,
                    pattern: StrokePattern.dashed(segments: _ringDash),
                  ),
                ]),
                MarkerLayer(markers: [
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
                ]),
              ],
            ),
            legend: const RadarLegend(showWords: false),
          ),
          afterHero: const [PlaybackCard(meta: '單站雷達僅提供最新影格')],
        );
      },
    );
  }

  _RadarView _loadingView() => _RadarView(
        subtitle: _loadingSubtitle,
        loading: true,
        hero: _heroCard(map: const RadarMapView(loading: true, muted: true)),
        afterHero: const [PlaybackCard(meta: '等待影格', loading: true)],
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
            muted: true,
            chipIcon: Icons.cloud_off_outlined,
            chipText: '無雷達資料',
            semanticsLabel: '地圖，無雷達資料',
          ),
        ),
      );

  // ---- cards ----

  AppCard _heroCard({String? eyebrow, String? note, StatusBanner? banner, required RadarMapView map, Widget? legend}) {
    final titles = eyebrow == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpace.s4,
            children: [
              Text(eyebrow, style: AppType.caption1.copyWith(color: AppPalette.fg3)),
              if (note != null) Text(note, style: AppType.caption1.copyWith(color: AppPalette.fg3)),
            ],
          );
    return AppCard(
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s16,
        children: [
          ?titles,
          ?banner,
          map,
          ?legend,
        ],
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
                style: AppType.body1.copyWith(color: AppPalette.fg1, fontWeight: FontWeight.w600, fontFeatures: AppType.tabular),
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
                Text(
                  '全台合成整合各雷達站。單站雷達僅涵蓋該站周邊，距離越遠、山區背面訊號越弱。',
                  style: AppType.caption1.copyWith(color: AppPalette.fg3),
                ),
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
