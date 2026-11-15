import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:image/image.dart' as img;

import '../../core/theme/app_tokens.dart';
import 'radar_echo_stats.dart';

/// Post-processing of a radar image (website `CV1_3600_` frame or open-data
/// station image): background → transparent, rows reprojected as the
/// [RadarImageGeometry] says, stored as one 8-bit indexed PNG.
///
/// Background key (evidence: docs/logs/2026-11-14/radar-impl-notes.md): echo
/// pixels are drawn only in the 66 colours of the dBZ legend (one per dBZ,
/// 0–65); everything else (land/sea fill, coast/county lines, grid, text,
/// logo) is background. The legend bar and the station-status dots also use
/// legend-like colours, so their rectangles are always background.

const radarFrameSize = 3600;

/// dBZ legend colours (0xRRGGBB, index = dBZ), from the CWA scale in
/// [AppPalette.dbzScale] (sampled from the frames' legend bar).
final radarEchoPalette = [for (final c in AppPalette.dbzScale) c.toARGB32() & _rgbMask];

const _rgbMask = 0xFFFFFF;

/// Pixel rectangle, [left, right) x [top, bottom).
typedef PixelRect = ({int left, int top, int right, int bottom});

/// Decorations of the 3600 frame drawn in legend colours (measured on real frames).
const websiteFrameDecorations = <PixelRect>[
  (left: 3419, top: 2507, right: 3488, bottom: 3572), // dBZ colour bar
  (left: 97, top: 223, right: 146, bottom: 718), // radar station status dots
];

/// Decorations of the O-A0084-00x station images drawn in legend colours: only
/// the dBZ colour bar (identical on all three stations, 66 x 1032 px; no other
/// legend-colour pixels outside the 150 km circle, measured 2026-11-14).
const stationFrameDecorations = <PixelRect>[
  (left: 3461, top: 2541, right: 3527, bottom: 3573),
];

/// Extent of the 3600 frame (see radar_bounds.dart).
const radarFrameSouth = 17.75;
const radarFrameNorth = 29.25;
const radarFrameWest = 115.0;
const radarFrameEast = 126.5;

/// Mercator row map of the 3600 frame (3748 output rows).
final radarFrameRowMap = mercatorRowMap(srcHeight: radarFrameSize, south: radarFrameSouth, north: radarFrameNorth);

/// How one source's images are processed and placed on the map.
class RadarImageGeometry {
  /// Source images are [size] x [size] px.
  final int size;

  /// Extent of the source image (linear in latitude and longitude) and of the
  /// processed image on the map: [rowMap] makes the output rows linear in
  /// Web Mercator, which is what flutter_map's `OverlayImage` stretches by.
  final LatLngBounds bounds;

  /// Output row j is source row `rowMap[j]`; non-decreasing, covers 0..size-1.
  final List<int> rowMap;

  /// Rectangles (source px) drawn in legend colours that are not echo.
  final List<PixelRect> decorations;

  const RadarImageGeometry({required this.size, required this.bounds, required this.rowMap, required this.decorations});
}

/// A processed frame: indexed PNG (palette [radarIndexedPalette]) and the
/// echo statistics of the source image.
typedef ProcessedRadarFrame = ({Uint8List png, RadarEchoStats stats});

/// Palette of the processed PNG: index 0 = transparent, index d + 1 = dBZ d
/// ([radarEchoPalette]), opaque.
img.PaletteUint8 radarIndexedPalette() {
  final palette = img.PaletteUint8(radarEchoPalette.length + 1, 4);
  for (final (d, c) in radarEchoPalette.indexed) {
    palette.setRgba(d + 1, c >> 16, (c >> 8) & 0xFF, c & 0xFF, 0xFF);
  }
  return palette;
}

/// Full pipeline for one downloaded image, in one pass over the source rows:
/// key echo pixels to palette indices (decorations → transparent), count the
/// echo statistics, copy each index row to the output rows [g.rowMap] maps to
/// it, encode one indexed PNG (zlib from the platform). Pure and synchronous:
/// run it in a background isolate.
ProcessedRadarFrame processRadarFrame(Uint8List png, RadarImageGeometry g) {
  final src = img.decodePng(png) ?? (throw const FormatException('radar image: expected PNG bytes, decode failed'));
  if (src.width != g.size || src.height != g.size) {
    throw FormatException('radar image: expected ${g.size}x${g.size}, got ${src.width}x${src.height}');
  }
  if (src.numChannels != 3 || src.format != img.Format.uint8 || src.hasPalette) {
    throw FormatException(
      'radar image: expected 8-bit RGB without palette, got ${src.numChannels} channels, '
      '${src.format}, palette=${src.hasPalette}',
    );
  }
  final width = src.width;
  final echoBits = _radarEchoColourBits();
  final indexOf = {for (final (d, c) in radarEchoPalette.indexed) c: d + 1};
  final counts = List<int>.filled(radarEchoPalette.length, 0);
  final columns = (width / radarStatsCellPixels).ceil();
  final cells = Uint16List(columns * (src.height / radarStatsCellPixels).ceil() * radarDbzBands);
  final out = img.Image(width: width, height: g.rowMap.length, numChannels: 1, palette: radarIndexedPalette());
  final s = src.toUint8List();
  final d = out.toUint8List();
  final row = Uint8List(width);
  var j = 0;
  for (var y = 0; y < src.height; y++) {
    row.fillRange(0, width, 0);
    final sRow = y * src.rowStride;
    for (var x = 0; x < width; x++) {
      final si = sRow + x * 3;
      final c = (s[si] << 16) | (s[si + 1] << 8) | s[si + 2];
      if (echoBits[c >> 5] & (1 << (c & 31)) != 0) row[x] = indexOf[c]!;
    }
    for (final rect in g.decorations) {
      if (y >= rect.top && y < rect.bottom) row.fillRange(rect.left, min(rect.right, width), 0);
    }
    final cellRow = (y ~/ radarStatsCellPixels) * columns;
    for (var x = 0; x < width; x++) {
      final i = row[x];
      if (i == 0) continue;
      counts[i - 1]++;
      cells[(cellRow + x ~/ radarStatsCellPixels) * radarDbzBands + (i - 1) ~/ radarDbzBandWidth]++;
    }
    while (j < g.rowMap.length && g.rowMap[j] == y) {
      d.setRange(j * width, (j + 1) * width, row);
      j++;
    }
  }
  if (j != g.rowMap.length) {
    throw ArgumentError('radar image: expected a non-decreasing row map over source rows 0..${g.size - 1}, '
        'output row $j maps to ${g.rowMap[j]}');
  }
  return (
    png: img.encodePng(out),
    stats: RadarEchoStats(
      frame: g.bounds,
      imageWidth: width,
      imageHeight: src.height,
      pixelsPerDbz: counts,
      cellBandPixels: cells,
      gridColumns: columns,
      gridRows: (src.height / radarStatsCellPixels).ceil(),
    ),
  );
}

/// One bit per 24-bit colour, set for the [radarEchoPalette] colours (2 MB):
/// test `bits[c >> 5] & (1 << (c & 31))`.
Uint32List _radarEchoColourBits() {
  final bits = Uint32List(1 << 19);
  for (final c in radarEchoPalette) {
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
