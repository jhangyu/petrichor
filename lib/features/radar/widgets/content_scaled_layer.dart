import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
// flutter_map 8.3.0 exports no public way to hand a layer its own camera;
// MapCamera.of reads this inherited model (inherited_model.dart:37).
// ignore: implementation_imports
import 'package:flutter_map/src/map/inherited_model.dart';

/// Draws a map layer the way a browser page zoomed to [scale] draws a web
/// map: the same ground on the same screen area, but laid out on a surface
/// 1/[scale] times larger and shrunk back, so labels, line widths and icons
/// shrink by [scale] and the layer shows the content of
/// `log2(1 / scale)` zoom levels deeper. The layer sees a camera with that
/// higher zoom and the larger size; everything outside [child] (gestures,
/// other layers, the map's own camera) is untouched.
///
/// The subtree sees the device pixel ratio [rasterPixelRatio], so its
/// rasters stay at least as sharp as the screen after the shrink.
class ContentScaledLayer extends StatelessWidget {
  const ContentScaledLayer({super.key, required this.scale, required this.child})
    : assert(scale > 0 && scale <= 1, 'scale must be in (0, 1], got $scale');

  final double scale;
  final Widget child;

  /// How far a tile layer stretches its rasters: the vector tile layer
  /// draws tiles of zoom `floor(camera zoom)`, so at camera zoom z + f a
  /// tile is drawn 2^f times its raster's logical size, f in [0, 1)
  /// (flutter_map_vector_tiles 2.11.0 grid_layout.dart:29, :99).
  static const _maxTileStretch = 2.0;

  /// The device pixel ratio the subtree rasterizes at for a screen of
  /// [devicePixelRatio]: a raster is stretched up to [_maxTileStretch]
  /// times, then shrunk by [scale], so `dpr × scale × 2` keeps at least one
  /// raster pixel per device pixel at every fractional zoom (two at integer
  /// zoom). Scale 0.5 gives the screen's own ratio; plain `dpr × scale`
  /// left half a raster pixel per device pixel just below the next zoom,
  /// upsampled 2× and blurred.
  static double rasterPixelRatio(double devicePixelRatio, double scale) =>
      devicePixelRatio * scale * _maxTileStretch;

  /// The camera [child] sees for the map's [camera]: same centre and
  /// rotation, zoom raised by `log2(1 / scale)`, size divided by [scale].
  static MapCamera _scaledCamera(MapCamera camera, double scale) => MapCamera(
    crs: camera.crs,
    center: camera.center,
    zoom: camera.zoom - math.log(scale) / math.ln2,
    rotation: camera.rotation,
    nonRotatedSize: camera.nonRotatedSize / scale,
  );

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final size = camera.nonRotatedSize / scale;
    final media = MediaQuery.of(context);
    return OverflowBox(
      minWidth: size.width,
      maxWidth: size.width,
      minHeight: size.height,
      maxHeight: size.height,
      child: Transform.scale(
        scale: scale,
        child: MediaQuery(
          data: media.copyWith(devicePixelRatio: rasterPixelRatio(media.devicePixelRatio, scale)),
          child: MapInheritedModel(
            camera: _scaledCamera(camera, scale),
            controller: MapController.of(context),
            options: MapOptions.of(context),
            child: child,
          ),
        ),
      ),
    );
  }
}
