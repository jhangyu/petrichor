import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/status.dart';

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

/// Image cache ceiling (user decision: 200–500 MB). The top of that range, so
/// a 24-frame composite loop at 2048 px (~420 MiB with other images) is still
/// held whole; longer loops (200 station frames ≈ 3.2 GiB) are decoded during
/// playback instead ([radarImageCachePlan]).
const radarImageCacheCeilingBytes = 500 << 20;

/// Flutter's default ImageCache size (`_kDefaultSizeBytes`, 100 MiB); the cache
/// never shrinks below it.
const _flutterDefaultImageCacheBytes = 100 << 20;

/// Room in the image cache for images other than the radar loop.
const _otherImagesCacheBytes = 20 << 20;

const _bytesPerDecodedPixel = 4;

/// The loop on show: frame count and pixel aspect (height / width) size the
/// image cache; [next] is the frame after the shown one (playback order) at a
/// decode width, decoded ahead so the next tick does not wait.
typedef RadarLoopShape = ({int frameCount, double aspect, ImageProvider Function(int decodeWidth) next});

/// Image cache size for a loop and whether it holds the whole loop.
typedef RadarImageCachePlan = ({int maximumBytes, bool holdsLoop});

/// When every decoded frame plus room for other images fits under
/// [radarImageCacheCeilingBytes], the cache holds the loop (a playback loop
/// never decodes a frame twice; never below Flutter's default). Otherwise the
/// cache is the ceiling and frames are decoded during playback: the map view
/// evicts each frame once it leaves the screen, so the loop cannot push the
/// app's other images out (LRU thrash), and decodes the next frame ahead.
RadarImageCachePlan radarImageCachePlan({required int frameCount, required int decodeWidth, required double aspect}) {
  final decodeHeight = (decodeWidth * aspect).ceil();
  final needed = frameCount * decodeWidth * decodeHeight * _bytesPerDecodedPixel + _otherImagesCacheBytes;
  return needed <= radarImageCacheCeilingBytes
      ? (maximumBytes: max(_flutterDefaultImageCacheBytes, needed), holdsLoop: true)
      : (maximumBytes: radarImageCacheCeilingBytes, holdsLoop: false);
}

const _pinDot = 9.0;
const _pinHalo = 20.0;
const _pinHaloAlpha = 0.2;
const _pinBorder = 2.0;

/// `.radar-map`: 5:6 map with the time chip (top left), 「回到我的位置」 button
/// (top right) and the current place's pin. [overlayBuilder] gets the pixel width the
/// radar frame should be decoded at: the viewport width capped at
/// [radarMaxDecodeWidth], playing or paused, and must return the one shown
/// frame. The image cache follows [radarImageCachePlan] for the [loop]; it goes
/// back to Flutter's default when the map leaves the screen.
class RadarMapView extends StatefulWidget {
  const RadarMapView({
    super.key,
    required this.me,
    this.chipText,
    this.chipIcon,
    this.overlayBuilder,
    this.loop,
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
  final List<OverlayImage> Function(int decodeWidth)? overlayBuilder;
  /// The radar loop shown by [overlayBuilder]; null for a single image that
  /// needs no cache plan (rainfall maps).
  final RadarLoopShape? loop;
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
    PaintingBinding.instance.imageCache.maximumSizeBytes = _flutterDefaultImageCacheBytes;
    super.dispose();
  }

  /// Frame image on screen after the last build.
  ImageProvider? _shown;

  /// The frame overlay at the decode width, with the image cache sized by
  /// [radarImageCachePlan]; after the frame is painted, the frame that left the
  /// screen is evicted (loop not held) and the next frame is decoded ahead.
  List<OverlayImage> _frameOverlay(
      List<OverlayImage> Function(int decodeWidth) builder, double viewportLogical, RadarLoopShape? loop) {
    final width = min((viewportLogical * MediaQuery.devicePixelRatioOf(context)).ceil(), radarMaxDecodeWidth);
    if (loop == null) return builder(width);
    final plan = radarImageCachePlan(frameCount: loop.frameCount, decodeWidth: width, aspect: loop.aspect);
    PaintingBinding.instance.imageCache.maximumSizeBytes = plan.maximumBytes;
    final overlay = builder(width);
    final shown = overlay.single.imageProvider;
    final left = _shown;
    _shown = shown;
    final next = loop.next(width);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!plan.holdsLoop && left != null && left != shown) left.evict();
      precacheImage(next, context);
    });
    return overlay;
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final builder = widget.overlayBuilder;
    final loop = widget.loop;
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
                  ),
                  children: [
                    TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _userAgentPackage),
                    if (builder != null)
                      OverlayImageLayer(overlayImages: _frameOverlay(builder, box.maxWidth, loop)),
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
