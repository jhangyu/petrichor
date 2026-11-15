import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../data/radar/radar_webp.dart';

/// A cached radar frame (lossless WebP) decoded by libwebp on a background
/// isolate at its stored size (the GPU scales it when drawing; an engine
/// downscale measured slower than the full decode). The cache key is the file
/// path, so the map and its pre-decode share one cache entry.
@immutable
class RadarWebpImage extends ImageProvider<RadarWebpImage> {
  const RadarWebpImage(this.file);

  final File file;

  @override
  Future<RadarWebpImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(RadarWebpImage key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(
    key._load(),
    informationCollector: () => [ErrorDescription('Path: ${key.file.path}')],
  );

  Future<ImageInfo> _load() async {
    final path = file.path;
    // Isolate.run returns through Isolate.exit: the RGBA is not copied back.
    final decoded = await Isolate.run(() {
      final data = File(path).readAsBytesSync();
      return (size: radarWebpSize(data), rgba: decodeRadarWebp(data));
    });
    final buffer = await ui.ImmutableBuffer.fromUint8List(decoded.rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: decoded.size.width,
      height: decoded.size.height,
      // Premultiplied, as decodeRadarWebp returns.
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    try {
      final codec = await descriptor.instantiateCodec();
      try {
        final frame = await codec.getNextFrame();
        return ImageInfo(image: frame.image, debugLabel: path);
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }

  @override
  bool operator ==(Object other) => other is RadarWebpImage && other.file.path == file.path;

  @override
  int get hashCode => file.path.hashCode;

  @override
  String toString() => '${objectRuntimeType(this, 'RadarWebpImage')}("${file.path}")';
}
