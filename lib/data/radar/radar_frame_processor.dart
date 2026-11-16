import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';

import 'radar_echo_statistics.dart';
import 'radar_png_rows.dart';
import 'radar_webp.dart';

// Post-processing of a radar image (website `CV1_3600_` frame or website
// station image): background → transparent, rows reprojected as the
// [RadarImageGeometry] says, stored as one lossless WebP.
//
// Background key (evidence: docs/logs/2026-11-14/radar-impl-notes.md): echo
// pixels are drawn only in the 66 colours of the dBZ legend (one per dBZ,
// 0–65); everything else (land/sea fill, coast/county lines, grid, text,
// logo) is background. The legend bar and the station-status dots also use
// legend-like colours, so their rectangles are always background.

/// Width of the stored image (nearest-neighbour from the source, so the palette
/// stays exact); narrower sources are stored at their own width. The CWA
/// source is upsampled from a ~1.27 km grid, so more width adds no echo
/// detail (radar-perf-contract.md item 1); never lowered to fit memory (user
/// decision). The map view never decodes wider than this.
const _radarStoredWidth = 2048;

/// Pixel rectangle, [left, right) x [top, bottom).
typedef PixelRect = ({int left, int top, int right, int bottom});

/// How one source's images are processed and placed on the map.
class RadarImageGeometry {
  /// Source images are [size] x [size] px.
  final int size;

  /// Extent of the source image (linear in latitude and longitude) and of the
  /// processed image on the map: [rowMap] makes the output rows linear in
  /// Web Mercator, which is what flutter_map's `OverlayImage` stretches by.
  final LatLngBounds bounds;

  /// Full-resolution output row j is source row `rowMap[j]`; non-decreasing, within 0..size-1.
  /// The stored image samples this map at [_radarStoredWidth] scale.
  final List<int> rowMap;

  /// Rectangles (source px) drawn in legend colours that are not echo.
  final List<PixelRect> decorations;

  const RadarImageGeometry({
    required this.size,
    required this.bounds,
    required this.rowMap,
    required this.decorations,
  });
}

/// A processed frame: lossless WebP (transparent background, opaque echo in the
/// source colours) and the echo statistics of the source image.
typedef ProcessedRadarFrame = ({Uint8List webp, RadarEchoStatistics stats});

/// RGBA pixel (bytes R, G, B, A in memory, little-endian host) per palette index
/// of the processed image: index 0 = transparent, index d + 1 = dBZ d
/// ([colours], index = dBZ), opaque.
Uint32List _rgbaOfIndex(List<int> colours) {
  final lut = Uint32List(colours.length + 1);
  for (final (d, c) in colours.indexed) {
    lut[d + 1] = rgbToRgbaWord(c);
  }
  return lut;
}

/// Full pipeline for one downloaded image, in one pass over the source rows
/// (inflated and unfiltered one row at a time, so the 3600x3600 RGB image is
/// never held in memory):
/// key echo pixels to palette indices (decorations → transparent), count the
/// echo statistics (on the full-resolution source), copy each index row,
/// sampled nearest-neighbour to [_radarStoredWidth] px wide, to the output rows
/// [g.rowMap] maps to it, encode one lossless WebP. Pure
/// and synchronous: run it in a background isolate.
ProcessedRadarFrame processRadarFrame(Uint8List png, RadarImageGeometry g) {
  final width = g.size;
  final height = g.size;
  final echoBits = _colourBits(radarEchoPalette);
  final indexOf = {for (final (d, c) in radarEchoPalette.indexed) c: d + 1};
  final counts = List<int>.filled(radarEchoPalette.length, 0);
  for (var j = 0; j < g.rowMap.length; j++) {
    if (g.rowMap[j] < 0 || g.rowMap[j] >= g.size || (j > 0 && g.rowMap[j] < g.rowMap[j - 1])) {
      throw ArgumentError('radar image: expected a non-decreasing row map within source rows 0..${g.size - 1}, '
          'output row $j maps to ${g.rowMap[j]} (previous ${j > 0 ? g.rowMap[j - 1] : 'none'})');
    }
  }
  final outWidth = min(width, _radarStoredWidth);
  final outHeight = (g.rowMap.length * outWidth / width).round();
  final outRows = [for (var k = 0; k < outHeight; k++) g.rowMap[k * g.rowMap.length ~/ outHeight]];
  final outColumns = Uint16List.fromList([for (var x = 0; x < outWidth; x++) x * width ~/ outWidth]);
  final rgbaOfIndex = _rgbaOfIndex(radarEchoPalette);
  final row = Uint8List(width);
  var k = 0;
  final webp = encodeRadarWebp(outWidth, outHeight, (out) => readPngRgbRows(png, g.size, (y, rgb) {
    row.fillRange(0, width, 0);
    for (var x = 0; x < width; x++) {
      final si = x * 3;
      final c = (rgb[si] << 16) | (rgb[si + 1] << 8) | rgb[si + 2];
      if (echoBits[c >> 5] & (1 << (c & 31)) != 0) row[x] = indexOf[c]!;
    }
    for (final rect in g.decorations) {
      if (y >= rect.top && y < rect.bottom) row.fillRange(rect.left, min(rect.right, width), 0);
    }
    for (var x = 0; x < width; x++) {
      final i = row[x];
      if (i != 0) counts[i - 1]++;
    }
    while (k < outHeight && outRows[k] == y) {
      final o = k * outWidth;
      for (var x = 0; x < outWidth; x++) {
        out[o + x] = rgbaOfIndex[row[outColumns[x]]];
      }
      k++;
    }
  }));
  return (
    webp: webp,
    stats: RadarEchoStatistics(
      frame: g.bounds,
      imageWidth: width,
      imageHeight: height,
      pixelsPerDbz: counts,
    ),
  );
}

/// One bit per 24-bit colour, set for the [colours] (2 MB): test
/// `bits[c >> 5] & (1 << (c & 31))`.
Uint32List _colourBits(List<int> colours) {
  final bits = Uint32List(1 << 19);
  for (final c in colours) {
    bits[c >> 5] |= 1 << (c & 31);
  }
  return bits;
}

/// Row map from an image linear in latitude ([south]..[north], [srcHeight]
/// rows) to Web Mercator rows, top row first. The output height is chosen so
/// that no source row is dropped (stretch ≥ 1 row at the southern edge, where
/// Mercator stretches least); northern rows are duplicated.
List<int> mercatorRowMap({required int srcHeight, required double south, required double north}) {
  final yS = _mercY(south), yN = _mercY(north);
  final outHeight = (srcHeight * (yN - yS) * cos(_rad(south)) / _rad(north - south)).ceil();
  return List<int>.generate(outHeight, (j) {
    final lat = _latOf(yN - (j + 0.5) * (yN - yS) / outHeight);
    return ((north - lat) / (north - south) * srcHeight).floor().clamp(0, srcHeight - 1);
  });
}

double _rad(double deg) => deg * pi / 180;
double _mercY(double lat) => log(tan(pi / 4 + _rad(lat) / 2));
double _latOf(double y) => (2 * atan(exp(y)) - pi / 2) * 180 / pi;
