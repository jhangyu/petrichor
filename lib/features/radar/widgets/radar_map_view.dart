import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/status.dart';
import '../../../data/radar/radar_frame_repository.dart';

/// Map centre and zoom: Taiwan overview when the place is unknown, else the place.
const _taiwanCenter = LatLng(23.7, 121.0);
const _overviewZoom = 6.5;
const _locatedZoom = 8.0;

const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgentPackage = 'com.example.cwbweather';

/// The CWA source image is upsampled from a ~1.27 km grid, so decoding wider
/// than this adds no echo detail (measured 2026-11-15, radar-perf-contract.md
/// item 1). Never lowered to fit memory (user decision).
const radarMaxDecodeWidth = 2048;

/// Frames decoded ahead of the shown one.
const radarPreDecodeCount = 2;

const _fullCircleDegrees = 360.0;
const _webMercatorTileSize = 256.0;

/// Decode widths step up in multiples of this, so pinch-zooming does not decode
/// a frame per gesture event.
const _decodeWidthStep = 256;

/// Pixel width to decode a frame at: the width the whole frame is drawn at on
/// screen (its [lonSpanDegrees] at map [zoom], Web Mercator is linear in
/// longitude) in device pixels, rounded up to [_decodeWidthStep] and capped at
/// [radarMaxDecodeWidth]. Playing or paused, never lower than needed.
int radarDecodeWidth({required double lonSpanDegrees, required double zoom, required double devicePixelRatio}) {
  final onScreen = lonSpanDegrees / _fullCircleDegrees * _webMercatorTileSize * pow(2, zoom) * devicePixelRatio;
  final stepped = (onScreen / _decodeWidthStep).ceil() * _decodeWidthStep;
  return min(stepped, radarMaxDecodeWidth);
}

const _pinDot = 9.0;
const _pinHalo = 20.0;
const _pinHaloAlpha = 0.2;
const _pinBorder = 2.0;

/// `.radar-map`: 5:6 map with the time chip (top left), 「回到我的位置」 button
/// (top right) and the current place's pin. [overlayBuilder] gets the pixel width the
/// radar frame should be decoded at ([radarDecodeWidth] of [frameBounds] at the
/// current zoom), and must return the one shown frame. The image cache stays at Flutter's default; [upcoming] frames are
/// decoded ahead.
class RadarMapView extends StatefulWidget {
  const RadarMapView({
    super.key,
    required this.me,
    this.chipText,
    this.chipIcon,
    this.frameBounds,
    this.overlayBuilder,
    this.upcoming = const [],
    this.extraLayers = const [],
    this.loading = false,
    this.muted = false,
    this.semanticsLabel,
  });

  /// Current place; null = no place (pin hidden, locate button disabled).
  final LatLng? me;

  /// Top-left chip (observation time / 無雷達資料); none while loading.
  final String? chipText;
  final IconData? chipIcon;

  /// Extent of the shown radar frame; required with [overlayBuilder].
  final LatLngBounds? frameBounds;
  final List<OverlayImage> Function(int decodeWidth)? overlayBuilder;

  /// The next ready frames in playback order (at most [radarPreDecodeCount]),
  /// decoded ahead; empty for a single image (rainfall maps).
  final List<RadarFrame> upcoming;
  final List<Widget> extraLayers;

  /// 載入雷達圖… chip centred on the map.
  final bool loading;

  /// `.radar-map--muted`: dimmed base map (loading / no data).
  final bool muted;
  final String? semanticsLabel;

  @override
  State<RadarMapView> createState() => _RadarMapViewState();
}

class _RadarMapViewState extends State<RadarMapView> {
  final _controller = MapController();
  late double _zoom = _initialZoom();

  double _initialZoom() => widget.me == null ? _overviewZoom : _locatedZoom;

  @override
  void didUpdateWidget(RadarMapView old) {
    super.didUpdateWidget(old);
    final me = widget.me;
    if (me != null && me != old.me) _controller.move(me, _locatedZoom);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _decodeWidth(double zoom) {
    final bounds = widget.frameBounds;
    if (bounds == null) throw StateError('RadarMapView: overlayBuilder given without frameBounds');
    return radarDecodeWidth(
      lonSpanDegrees: bounds.east - bounds.west,
      zoom: zoom,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    final stepChanged = widget.overlayBuilder != null && _decodeWidth(camera.zoom) != _decodeWidth(_zoom);
    _zoom = camera.zoom;
    if (stepChanged) setState(() {});
  }

  /// The frame overlay at the decode width; after it is painted, the
  /// [RadarMapView.upcoming] frames are decoded ahead through the same
  /// provider (and cache key) the map uses, so the next ticks do not wait.
  List<OverlayImage> _frameOverlay(List<OverlayImage> Function(int decodeWidth) builder) {
    final width = _decodeWidth(_zoom);
    final ahead = [for (final frame in widget.upcoming) frame.imageProvider(decodeWidth: width)];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final provider in ahead) {
        precacheImage(provider, context);
      }
    });
    return builder(width);
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final builder = widget.overlayBuilder;
    final chipText = widget.chipText;
    final map = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AspectRatio(
        aspectRatio: 5 / 6,
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: widget.muted ? 0.6 : 1,
                child: FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: me ?? _taiwanCenter,
                    initialZoom: _initialZoom(),
                    onPositionChanged: _onPositionChanged,
                  ),
                  children: [
                    TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _userAgentPackage),
                    if (builder != null)
                      OverlayImageLayer(overlayImages: _frameOverlay(builder)),
                    ...widget.extraLayers,
                    if (me != null)
                      MarkerLayer(
                        markers: [Marker(point: me, width: _pinHalo, height: _pinHalo, child: const _MePin())],
                      ),
                  ],
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
                  child: _LocateFab(onPressed: me == null ? null : () => _controller.move(me, _locatedZoom)),
                ),
            ],
          ),
        ),
      ),
    );
    final label = widget.semanticsLabel;
    return label == null ? map : Semantics(label: label, image: true, child: map);
  }
}

/// `.map-chip`: overlay pill with an icon (or spinner) and text.
class _MapChip extends StatelessWidget {
  const _MapChip({this.icon, required this.text, this.spinner = false, this.large = false});

  final IconData? icon;
  final String text;
  final bool spinner;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final style = (large ? AppType.body1 : AppType.caption1).copyWith(
      color: AppPalette.fg1,
      fontWeight: FontWeight.w600,
      fontFeatures: AppType.tabular,
    );
    final glyph = icon;
    return Container(
      constraints: BoxConstraints(minHeight: large ? AppSize.touch : AppSize.controlSm),
      padding: EdgeInsets.symmetric(
        horizontal: large ? AppSpace.s16 : AppSpace.s12,
        vertical: large ? AppSpace.s8 : AppSpace.s4,
      ),
      decoration: BoxDecoration(
        color: AppPalette.bgOverlay,
        borderRadius: BorderRadius.circular(AppRadius.circular),
        boxShadow: AppShadows.s4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: large ? AppSpace.s8 : AppSpace.s4,
        children: [
          if (spinner)
            const AppSpinner()
          else if (glyph != null)
            Icon(glyph, size: AppSize.icon16, color: AppPalette.fg1),
          Text(text, style: style),
        ],
      ),
    );
  }
}

class _MePin extends StatelessWidget {
  const _MePin();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: _pinHalo,
          height: _pinHalo,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppPalette.dangerSolid.withValues(alpha: _pinHaloAlpha),
          ),
        ),
        Container(
          width: _pinDot,
          height: _pinDot,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppPalette.dangerSolid,
            border: Border.all(color: AppPalette.bg1, width: _pinBorder),
          ),
        ),
      ],
    );
  }
}

/// `.fab` 「回到我的位置」; disabled without a current place.
class _LocateFab extends StatelessWidget {
  const _LocateFab({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: AppPalette.bg1,
      shape: const CircleBorder(),
      elevation: 0,
      shadowColor: AppPalette.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: enabled ? AppShadows.s4 : AppShadows.s2),
        child: AppIconButton(
          icon: Icons.my_location,
          tooltip: enabled ? '回到我的位置' : '回到我的位置（沒有目前地點）',
          onPressed: onPressed,
        ),
      ),
    );
  }
}
