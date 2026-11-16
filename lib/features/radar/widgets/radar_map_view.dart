import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';

import '../../../core/logging/app_log.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status.dart';
import '../../../data/radar/radar_frame_repository.dart';
import '../radar_webp_image.dart';
import 'basemap_theme.dart';
import 'content_scaled_layer.dart';

part 'basemap_loader.dart';
part 'map_overlays.dart';

/// Map centre and zoom: Taiwan overview when the place is unknown, else the place.
const _taiwanCenter = LatLng(23.7, 121.0);
const _overviewZoom = 6.5;
const _locatedZoom = 8.0;

const _styleFailedText = '底圖載入失敗，點按重試';

/// Basemap content scale, like a browser page zoomed to 50%: the basemap
/// alone is laid out on a surface twice the card's size at camera zoom + 1
/// and shrunk back ([ContentScaledLayer]), so the same ground on the same
/// card shows the next zoom level's content with labels, line widths and
/// icons at half size. The radar overlay, pin and controls are not scaled.
/// Measured on the 340×408 card (features drawn, data tile zoom, unscaled →
/// 0.5): located zoom 8: 7521 → 12668, style layers 14 → 17, z8 → z9;
/// overview zoom 6.5: 8250 → 10724, style layers 10 → 11, z6 → z7.
const _basemapContentScale = 0.5;

/// Data tiles and style evaluated at the (scaled) camera zoom rather than
/// the plugin's MapLibre default of one level lower: with the default, the
/// scaled basemap would draw the same features as an unscaled one, only
/// smaller (located zoom 8: 7512 features, data z8).
const _basemapDetail = vt.TileOffset.none;

/// GPU budget for finished basemap tiles, in screenfuls of the plugin's tile
/// grid. One screenful keeps every tile on screen cached, so panning back is
/// free; a zoom round trip re-renders the level left behind from decoded
/// geometry (no network). Radar frames already hold up to ~100 MiB of
/// decoded images, so this stays below the plugin's own 2.5 screenfuls.
const _rasterCacheScreens = 1;

/// The plugin's display tile edge in logical pixels and its buffer ring: a
/// level spans `ceil(extent / 256) + 1` tiles per axis plus one each side
/// (flutter_map_vector_tiles 2.11.0 vector_tile_layer.dart:286-303,
/// GridLayout.forCamera(buffer: 1)).
const _displayTilePixels = 256.0;
const _gridExtraTiles = 3;
const _rgbaBytes = 4;

/// GPU bytes for [_rasterCacheScreens] of finished tiles over a [card] at
/// [devicePixelRatio], as the scaled layer sees them: a surface of card / scale at
/// [ContentScaledLayer.rasterPixelRatio]. A 340×408 card at scale 0.5 is a
/// 680×816 surface, 6×7 tiles of 768 px at dpr 3: 94.5 MiB (unscaled it was
/// 5×5 tiles of 768 px, 56.25 MiB); 6×7 tiles of 512 px, 42 MiB, at dpr 2.
int _rasterCacheBytes(Size card, double devicePixelRatio) {
  final surface = card / _basemapContentScale;
  final tilesX = (surface.width / _displayTilePixels).ceil() + _gridExtraTiles;
  final tilesY = (surface.height / _displayTilePixels).ceil() + _gridExtraTiles;
  final rasterDevicePixelRatio = ContentScaledLayer.rasterPixelRatio(devicePixelRatio, _basemapContentScale);
  final tileEdge = (_displayTilePixels * rasterDevicePixelRatio).ceilToDouble();
  return (tilesX * tilesY * tileEdge * tileEdge * _rgbaBytes * _rasterCacheScreens).round();
}

/// How long the camera has to rest before its zoom is written to the log.
const _zoomLogDebounce = Duration(milliseconds: 400);
/// Frames decoded ahead of the shown one.
const radarPreDecodeCount = 2;

/// Camera shared by maps side by side: a map that the user moves reports its
/// camera, the others follow it. Reports only come from gestures, so a
/// following map moving does not echo back.
class RadarCameraLink extends ChangeNotifier {
  Object? _origin;
  LatLng? _center;
  double? _zoom;

  /// The map that last reported; it ignores its own report.
  Object? get origin => _origin;
  LatLng? get center => _center;
  double? get zoom => _zoom;

  void report(Object origin, MapCamera camera) {
    _origin = origin;
    _center = camera.center;
    _zoom = camera.zoom;
    notifyListeners();
  }
}

/// Default map shape of [RadarMapView.aspectRatio].
const radarMapDefaultAspectRatio = 5 / 6;

/// Base map opacity of `.radar-map--muted` (loading / no data).
const _mutedOpacity = 0.6;

/// `.radar-map`: 5:6 map with the time chip (top left), 「回到我的位置」 button
/// (top right) and the current place's pin. [overlayImages] holds the one shown
/// frame. The image cache stays at Flutter's default; [upcoming] frames are
/// decoded ahead.
class RadarMapView extends StatefulWidget {
  const RadarMapView({
    super.key,
    required this.me,
    this.chipText,
    this.chipIcon,
    this.overlayImages = const [],
    this.upcoming = const [],
    this.extraLayers = const [],
    this.loading = false,
    this.muted = false,
    this.semanticsLabel,
    this.aspectRatio = radarMapDefaultAspectRatio,
    this.startLocked = false,
    this.cameraLink,
  });

  /// Current place; null = no place (pin hidden, locate button disabled).
  final LatLng? me;

  /// Top-left chip (observation time / 無雷達資料); none while loading.
  final String? chipText;
  final IconData? chipIcon;

  final List<OverlayImage> overlayImages;

  /// The next ready frames in playback order (at most [radarPreDecodeCount]),
  /// decoded ahead; empty for a single image (rainfall maps).
  final List<RadarFrame> upcoming;
  final List<Widget> extraLayers;

  /// 載入雷達圖… chip centred on the map.
  final bool loading;

  /// `.radar-map--muted`: dimmed base map (loading / no data).
  final bool muted;
  final String? semanticsLabel;

  /// Width / height of the map.
  final double aspectRatio;

  /// Pan and zoom are off until the lock button is pressed (maps inside a scrolling page).
  final bool startLocked;

  /// Camera shared with the other maps of the link; null = this map is alone.
  final RadarCameraLink? cameraLink;

  @override
  State<RadarMapView> createState() => _RadarMapViewState();
}

class _RadarMapViewState extends State<RadarMapView> {
  final _controller = MapController();
  late bool _locked = widget.startLocked;
  Timer? _zoomLog;
  double? _loggedZoom;
  int? _loggedCacheBytes;
  double _initialZoom() => widget.me == null ? _overviewZoom : _locatedZoom;

  @override
  void initState() {
    super.initState();
    // After this frame: a retry notifies every mounted map, and notifying
    // the other maps' builders while this one mounts (during build) would
    // mark them dirty mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) => retryRadarBasemap());
    widget.cameraLink?.addListener(_followLink);
  }

  void _followLink() {
    final link = widget.cameraLink!;
    if (identical(link.origin, this)) return;
    _controller.move(link.center!, link.zoom!);
  }

  /// Logs the zoom once the camera has rested for [_zoomLogDebounce]; pans
  /// that keep the zoom are not logged.
  void _onCamera(MapCamera camera, bool hasGesture) {
    if (hasGesture) widget.cameraLink?.report(this, camera);
    _zoomLog?.cancel();
    _zoomLog = Timer(_zoomLogDebounce, () {
      if (camera.zoom == _loggedZoom) return;
      _loggedZoom = camera.zoom;
      final c = camera.center;
      appLog(
        _logTag,
        'zoom ${camera.zoom.toStringAsFixed(2)} centre ${c.latitude.toStringAsFixed(3)},'
        '${c.longitude.toStringAsFixed(3)} gesture $hasGesture',
      );
    });
  }

  int _cacheBytesFor(Size card, double devicePixelRatio) {
    final bytes = _rasterCacheBytes(card, devicePixelRatio);
    if (bytes != _loggedCacheBytes) {
      _loggedCacheBytes = bytes;
      appLog(
        _logTag,
        'raster cache ${(bytes / (1 << 20)).toStringAsFixed(1)} MiB for card '
        '${card.width.round()}x${card.height.round()} dpr $devicePixelRatio content scale $_basemapContentScale '
        'raster dpr ${ContentScaledLayer.rasterPixelRatio(devicePixelRatio, _basemapContentScale)}',
      );
    }
    return bytes;
  }

  @override
  void didUpdateWidget(RadarMapView old) {
    super.didUpdateWidget(old);
    if (old.cameraLink != widget.cameraLink) {
      old.cameraLink?.removeListener(_followLink);
      widget.cameraLink?.addListener(_followLink);
    }
    final me = widget.me;
    if (me != null && me != old.me) _controller.move(me, _locatedZoom);
  }

  @override
  void dispose() {
    widget.cameraLink?.removeListener(_followLink);
    _zoomLog?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// After this frame is painted, the [RadarMapView.upcoming] frames are
  /// decoded ahead through the same provider (and cache key) the map uses, so
  /// the next ticks do not wait.
  void _preDecodeUpcoming() {
    final ahead = [for (final frame in widget.upcoming) frame.imageProvider];
    if (ahead.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final provider in ahead) {
        precacheImage(provider, context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    _preDecodeUpcoming();
    final chipText = widget.chipText;
    final map = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: LayoutBuilder(
          builder: (context, card) => ValueListenableBuilder(
            valueListenable: _basemapLoad,
            builder: (context, load, _) => FutureBuilder(
              future: load,
              builder: (context, style) => Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: widget.muted ? _mutedOpacity : 1,
                    child: FlutterMap(
                      mapController: _controller,
                      options: MapOptions(
                        initialCenter: me ?? _taiwanCenter,
                        initialZoom: _initialZoom(),
                        onPositionChanged: _onCamera,
                        interactionOptions: InteractionOptions(
                          flags: _locked ? InteractiveFlag.none : InteractiveFlag.all,
                        ),
                      ),
                      children: [
                        // Same child slot before and after the load, so the layers above keep their state.
                        if (style.data case (:final style, :final theme, :final tiles))
                          ContentScaledLayer(
                            scale: _basemapContentScale,
                            child: vt.VectorTileLayer(
                              theme: theme,
                              tileProviders: tiles,
                              sprites: style.sprites,
                              glyphs: style.glyphs,
                              tileOffset: _basemapDetail,
                              rasterCacheMaxBytes: _cacheBytesFor(card.biggest, MediaQuery.devicePixelRatioOf(context)),
                              logger: const vt.Logger.custom(onLog: _pluginLog, onWarn: _pluginWarn),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        if (widget.overlayImages.isNotEmpty) OverlayImageLayer(overlayImages: widget.overlayImages),
                        ...widget.extraLayers,
                        if (me != null)
                          MarkerLayer(
                            markers: [Marker(point: me, width: _pinHalo, height: _pinHalo, child: const _MePin())],
                          ),
                        const _Attribution(),
                      ],
                    ),
                  ),
                  if (style.hasError)
                    Positioned(
                      bottom: AppSpace.s40,
                      left: AppSpace.s12,
                      right: AppSpace.s12,
                      child: Center(
                        child: Semantics(
                          button: true,
                          child: GestureDetector(
                            onTap: retryRadarBasemap,
                            child: const _MapChip(icon: Icons.refresh, text: _styleFailedText),
                          ),
                        ),
                      ),
                    ),
                  if (chipText != null)
                    Positioned(
                      top: AppSpace.s12,
                      left: AppSpace.s12,
                      child: _MapChip(icon: widget.chipIcon, text: chipText),
                    ),
                  if (widget.loading)
                    const Center(child: _MapChip(text: '載入雷達圖…', spinner: true, large: true))
                  else
                    Positioned(
                      top: AppSpace.s12,
                      right: AppSpace.s12,
                      child: Column(
                        spacing: AppSpace.s8,
                        children: [
                          _MapFab(
                            icon: Icons.my_location,
                            tooltip: me == null ? '回到我的位置（沒有目前地點）' : '回到我的位置',
                            onPressed: me == null ? null : () => _controller.move(me, _locatedZoom),
                          ),
                          if (widget.startLocked)
                            _MapFab(
                              icon: _locked ? Icons.lock_outline : Icons.lock_open,
                              tooltip: _locked ? '解除鎖定，可拖曳縮放地圖' : '鎖定地圖，頁面可捲動',
                              onPressed: () => setState(() => _locked = !_locked),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final label = widget.semanticsLabel;
    return label == null ? map : Semantics(label: label, image: true, child: map);
  }
}
