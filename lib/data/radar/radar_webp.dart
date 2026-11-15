@DefaultAsset('package:cwb_flutter/radar_webp')
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// The only FFI entry to libwebp (through the C adapter `radar_webp.h`, built by
/// the package build hook): lossless WebP encode and decode of radar frames.
/// Pure synchronous calls, safe from any isolate.

/// libwebp lossless compression level of stored frames (0 fastest .. 9 smallest;
/// 6 measured in .claude/tmp/stream-impl/size-probe/report.md).
const radarWebpLevel = 6;

const _bytesPerPixel = 4;
const _okCode = 0;

/// Bytes of a WebP file that [radarWebpSize] needs (RIFF header, VP8L header).
const radarWebpHeaderBytes = 32;

@Native<Int32 Function(Pointer<Uint8>, Int32, Int32, Int32, Int32, Pointer<Pointer<Uint8>>, Pointer<Size>)>(
    symbol: 'radar_webp_encode_lossless_rgba')
external int _encode(Pointer<Uint8> rgba, int width, int height, int stride, int level, Pointer<Pointer<Uint8>> out,
    Pointer<Size> outSize);

// Leaf (the Dart buffers are passed by address, no copy): decode is tens of ms.
@Native<Int32 Function(Pointer<Uint8>, Size, Pointer<Int32>, Pointer<Int32>)>(symbol: 'radar_webp_get_info', isLeaf: true)
external int _getInfo(Pointer<Uint8> data, int size, Pointer<Int32> width, Pointer<Int32> height);

@Native<Int32 Function(Pointer<Uint8>, Size, Pointer<Uint8>, Size, Int32)>(symbol: 'radar_webp_decode_rgba_into', isLeaf: true)
external int _decodeInto(Pointer<Uint8> data, int size, Pointer<Uint8> out, int outSize, int stride);

@Native<Void Function(Pointer<Void>)>(symbol: 'radar_webp_free')
external void _free(Pointer<Void> ptr);

/// Meaning of the negative codes of `radar_webp.h`.
const _codeNames = {
  -1: 'invalid argument',
  -2: 'libwebp version mismatch',
  -3: 'out of memory',
  -4: 'encode failed',
  -5: 'not a readable WebP header',
  -6: 'output buffer too small',
  -7: 'corrupt or truncated image data',
};

/// A failed libwebp adapter call: [call] with what it expected, what [code] says
/// and what it was applied to.
class RadarWebpException implements Exception {
  final String call;
  final int code;
  final String expected;
  final String affected;

  const RadarWebpException(this.call, this.code, {required this.expected, required this.affected});

  @override
  String toString() =>
      'RadarWebpException: $call returned $code (${_codeNames[code] ?? 'unknown code'}), expected $expected ($affected)';
}

/// Lossless WebP (level [radarWebpLevel]) of the straight-alpha RGBA pixels [rgba]
/// ([width] x [height], rows tightly packed; transparent pixels as 0,0,0,0).
Uint8List encodeRadarWebp(Uint8List rgba, int width, int height) {
  final expectedBytes = width * height * _bytesPerPixel;
  if (width <= 0 || height <= 0 || rgba.length != expectedBytes) {
    throw ArgumentError('radar webp encode: expected $expectedBytes RGBA bytes for ${width}x$height, got ${rgba.length}');
  }
  return using((arena) {
    final input = arena<Uint8>(rgba.length)..asTypedList(rgba.length).setAll(0, rgba);
    final out = arena<Pointer<Uint8>>();
    final outSize = arena<Size>();
    final code = _encode(input, width, height, width * _bytesPerPixel, radarWebpLevel, out, outSize);
    if (code != _okCode) {
      throw RadarWebpException('radar_webp_encode_lossless_rgba', code,
          expected: '$_okCode', affected: '${width}x$height RGBA, level $radarWebpLevel');
    }
    try {
      return Uint8List.fromList(out.value.asTypedList(outSize.value));
    } finally {
      _free(out.value.cast());
    }
  });
}

/// Pixel size from the start ([radarWebpHeaderBytes] suffice) of a WebP file.
({int width, int height}) radarWebpSize(Uint8List data) => using((arena) {
      if (data.isEmpty) throw ArgumentError('radar webp size: expected WebP bytes, got an empty list');
      final width = arena<Int32>();
      final height = arena<Int32>();
      final code = _getInfo(data[0].address, data.length, width, height);
      if (code != _okCode) {
        throw RadarWebpException('radar_webp_get_info', code,
            expected: '$_okCode', affected: 'WebP data of ${data.length} bytes');
      }
      return (width: width.value, height: height.value);
    });

/// Premultiplied-alpha RGBA pixels (what `ui.PixelFormat.rgba8888` takes; rows
/// tightly packed, [radarWebpSize] says how many) of a WebP file.
Uint8List decodeRadarWebp(Uint8List data) {
  final size = radarWebpSize(data);
  final out = Uint8List(size.width * size.height * _bytesPerPixel);
  final code = _decodeInto(data[0].address, data.length, out[0].address, out.length, size.width * _bytesPerPixel);
  if (code != _okCode) {
    throw RadarWebpException('radar_webp_decode_rgba_into', code,
        expected: '$_okCode', affected: '${size.width}x${size.height} WebP of ${data.length} bytes');
  }
  return out;
}
