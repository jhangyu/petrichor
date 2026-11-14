import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/status.dart';
import '../../../data/radar/radar_frame_processor.dart';

/// Map centre and zoom: Taiwan overview.
const _taiwanCenter = LatLng(23.7, 121.0);
const _overviewZoom = 6.5;

const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgentPackage = 'com.example.cwbweather';

/// Longitude span of the website frames (115.0–126.5, see radar_bounds.dart).
const _frameLonSpanDegrees = 11.5;
const _webMercatorTileSize = 256.0;
const _fullCircleDegrees = 360.0;

/// `.radar-map`: 5:6 map with the time chip (top left). [overlayBuilder] gets the pixel width the
/// radar bands should be decoded at: the viewport width while [playing] (a
/// full-size decoded frame is ~54 MB), the on-screen image width (capped at the
/// full frame) when paused so a zoomed frame stays sharp.
class RadarMapView extends StatefulWidget {
  const RadarMapView({
    super.key,
    this.chipText,
    this.chipIcon,
    this.overlayBuilder,
    this.extraLayers = const [],
    this.playing = false,
    this.loading = false,
    this.muted = false,
    this.semanticsLabel,
  });

  /// Top-left chip (observation time / 無雷達資料); none while loading.
  final String? chipText;
  final IconData? chipIcon;
  final List<OverlayImage> Function(int decodeWidth)? overlayBuilder;
  final List<Widget> extraLayers;
  final bool playing;

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
  late int _zoomStep = _overviewZoom.ceil();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _decodeWidth(double viewportLogical) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final viewport = (viewportLogical * dpr).ceil();
    if (widget.playing) return viewport;
    final onScreen = _frameLonSpanDegrees / _fullCircleDegrees * _webMercatorTileSize * pow(2, _zoomStep) * dpr;
    return onScreen.ceil().clamp(viewport, radarFrameSize);
  }

  @override
  Widget build(BuildContext context) {
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
                    initialCenter: _taiwanCenter,
                    initialZoom: _overviewZoom,
                    onPositionChanged: (camera, _) {
                      final step = camera.zoom.ceil();
                      if (step != _zoomStep) setState(() => _zoomStep = step);
                    },
                  ),
                  children: [
                    TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _userAgentPackage),
                    if (builder != null) OverlayImageLayer(overlayImages: builder(_decodeWidth(box.maxWidth))),
                    ...widget.extraLayers,
                  ],
                ),
              ),
              if (chipText != null)
                Positioned(top: AppSpace.s12, left: AppSpace.s12, child: _MapChip(icon: widget.chipIcon, text: chipText)),
              if (widget.loading)
                const Center(child: _MapChip(text: '載入雷達圖…', spinner: true, large: true)),
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
    final style = (large ? AppType.body1 : AppType.caption1)
        .copyWith(color: AppPalette.fg1, fontWeight: FontWeight.w600, fontFeatures: AppType.tabular);
    final glyph = icon;
    return Container(
      constraints: BoxConstraints(minHeight: large ? AppSize.touch : AppSize.controlSm),
      padding: EdgeInsets.symmetric(horizontal: large ? AppSpace.s16 : AppSpace.s12, vertical: large ? AppSpace.s8 : AppSpace.s4),
      decoration: BoxDecoration(
        color: AppPalette.bgOverlay,
        borderRadius: BorderRadius.circular(AppRadius.circular),
        boxShadow: AppShadows.s4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: large ? AppSpace.s8 : AppSpace.s4,
        children: [
          if (spinner) const AppSpinner() else if (glyph != null) Icon(glyph, size: AppSize.icon16, color: AppPalette.fg1),
          Text(text, style: style),
        ],
      ),
    );
  }
}
