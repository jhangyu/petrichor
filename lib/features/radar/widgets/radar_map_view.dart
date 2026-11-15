import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/status.dart';
import '../../../data/radar/radar_frame_repository.dart';

/// Map centre and zoom: Taiwan overview when the place is unknown, else the place.
const _taiwanCenter = LatLng(23.7, 121.0);
const _overviewZoom = 6.5;
const _locatedZoom = 8.0;

/// OpenStreetMap's own keyless vector layer (Shortbread schema, SVWD03 style).
/// The style ships no glyphs, so labels use each device's system fonts.
const _styleUrl = 'https://vector.openstreetmap.org/styles/svwd/svwd03style.json';

/// OSMF vector tile policy: a User-Agent that identifies the app.
const _userAgent = 'com.example.cwbweather.cwb_flutter';
const _attribution = '© OpenStreetMap contributors';
const _styleFailedText = '底圖載入失敗';

/// GPU budget for finished basemap tiles. The plugin's own default is at
/// least 64 MB; radar frames already take most of the memory budget. A
/// 256-logical-px tile costs about 2.25 MB at devicePixelRatio 3, and the
/// 5:6 map card shows at most 3×3 tiles, so 32 MB holds one full card plus
/// part of a zoom level; anything evicted re-renders from decoded geometry
/// without network.
const _basemapRasterCacheBytes = 32 * 1024 * 1024;

Future<vt.Style>? _sharedStyle;

/// The basemap style, loaded once and shared by every map. A failed load is
/// reported and forgotten, so the next map that mounts tries again.
// ponytail: the loaded style is never disposed; it lives as long as the app.
Future<vt.Style> _basemapStyle() => _sharedStyle ??= _loadStyle();

Future<vt.Style> _loadStyle() async {
  try {
    return await vt.StyleReader(uri: _styleUrl, headers: const {'User-Agent': _userAgent}).read();
  } catch (error, stack) {
    _sharedStyle = null;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'radar basemap',
        context: ErrorDescription('loading $_styleUrl'),
      ),
    );
    rethrow;
  }
}

/// Frames decoded ahead of the shown one.
const radarPreDecodeCount = 2;

const _pinDot = 9.0;
const _pinHalo = 20.0;
const _pinHaloAlpha = 0.2;
const _pinBorder = 2.0;

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

  @override
  State<RadarMapView> createState() => _RadarMapViewState();
}

class _RadarMapViewState extends State<RadarMapView> {
  final _controller = MapController();
  final _style = _basemapStyle();
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
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AspectRatio(
        aspectRatio: 5 / 6,
        child: FutureBuilder(
          future: _style,
          builder: (context, style) => Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: widget.muted ? 0.6 : 1,
                child: FlutterMap(
                  mapController: _controller,
                  options: MapOptions(initialCenter: me ?? _taiwanCenter, initialZoom: _initialZoom()),
                  children: [
                    // Same child slot before and after the load, so the layers above keep their state.
                    if (style.data case final style?)
                      vt.VectorTileLayer(
                        theme: style.theme,
                        tileProviders: style.providers,
                        sprites: style.sprites,
                        glyphs: style.glyphs,
                        rasterCacheMaxBytes: _basemapRasterCacheBytes,
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
                const Positioned(
                  bottom: AppSpace.s40,
                  left: AppSpace.s12,
                  right: AppSpace.s12,
                  child: Center(
                    child: _MapChip(icon: Icons.error_outline, text: _styleFailedText),
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

/// Half-transparent backing so the attribution stays legible over the map
/// without drawing attention.
const _attributionBackAlpha = 0.5;

/// OSM licence attribution (OSMF tile policy), kept unobtrusive: a small
/// low-contrast label tucked into the bottom-right corner.
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppPalette.bgOverlay.withValues(alpha: _attributionBackAlpha),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
            child: Text(_attribution, style: AppType.caption2.copyWith(color: AppPalette.fg4)),
          ),
        ),
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
