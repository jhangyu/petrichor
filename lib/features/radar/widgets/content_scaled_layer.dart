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
/// The subtree's device pixel ratio is multiplied by [scale] too, so tiles
/// rasterized at the larger logical size land 1:1 on device pixels after
/// the shrink instead of costing 1/scale² the GPU memory.
class ContentScaledLayer extends StatelessWidget {
  const ContentScaledLayer({super.key, required this.scale, required this.child})
    : assert(scale > 0 && scale <= 1, 'scale must be in (0, 1], got $scale');

  final double scale;
  final Widget child;

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
          data: media.copyWith(devicePixelRatio: media.devicePixelRatio * scale),
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
