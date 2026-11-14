import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

import 'radar_frame_processor.dart';

// Echo statistics of one website frame, computed from the source pixels while
// the frame is processed and stored next to its bands.
//
// Colour → dBZ: [radarEchoPalette] index = dBZ. Evidence: the legend bar of
// the real frame CV1_3600_202611142230 (column 3453, rows 2507–3571) is 66
// equal 16-row steps whose colours are palette indices 65 (top) down to 0
// (bottom), i.e. one colour per 1 dBZ over the legend's 0–65 dBZ scale.

/// Echo weaker than this is not "明顯回波". Marshall–Palmer (Z = 200 R^1.6):
/// 20 dBZ ≈ 0.65 mm/h, just above the 0.5 mm resolution of CWA rain gauges;
/// weaker echo is mostly drizzle, clear-air or clutter return.
const radarSignificantEchoDbz = 20;

/// From this dBZ the hero calls the echo strong. Marshall–Palmer: 40 dBZ ≈
/// 11.5 mm/h (heavy rain rate); also the start of the 橙 legend band.
const radarStrongEchoDbz = 40;

/// A dBZ level counts only if at least this many pixels reach it, so a few
/// isolated clutter pixels cannot set the frame's strongest echo. 16 px ≈ 2 km²
/// (1 px ≈ 0.355 km). ponytail: a pixel-count rule, not a connected-area one;
/// upgrade to blob sizes if speckle still leaks through on real frames.
const radarEchoMinPixels = 16;

/// Grid cell of the per-area maximum, in source pixels: 18 px ≈ 6.4 km.
const radarStatsCellPixels = 18;

/// Cell value for "no echo pixel in this cell".
const radarNoEcho = 255;

/// Header: grid columns, grid rows (uint32 each), then one uint32 per dBZ.
const _headerWords = 2;

class RadarEchoStats {
  /// Echo pixel count per dBZ (index = dBZ, 0..65).
  final List<int> pixelsPerDbz;

  /// Strongest dBZ per grid cell, row-major from the frame's north-west corner;
  /// [radarNoEcho] where the cell has no echo.
  final Uint8List cellMaxDbz;
  final int gridColumns;
  final int gridRows;

  RadarEchoStats({required this.pixelsPerDbz, required this.cellMaxDbz, required this.gridColumns, required this.gridRows}) {
    if (pixelsPerDbz.length != radarEchoPalette.length || cellMaxDbz.length != gridColumns * gridRows) {
      throw ArgumentError(
        'RadarEchoStats: expected ${radarEchoPalette.length} dBZ counts and $gridColumns x $gridRows cells, '
        'got ${pixelsPerDbz.length} counts and ${cellMaxDbz.length} cells',
      );
    }
  }

  /// Highest dBZ reached by at least [radarEchoMinPixels] pixels; null when no
  /// level is.
  int? get strongestDbz {
    var atOrAbove = 0;
    for (var d = pixelsPerDbz.length - 1; d >= 0; d--) {
      atOrAbove += pixelsPerDbz[d];
      if (atOrAbove >= radarEchoMinPixels) return d;
    }
    return null;
  }

  /// No level of [radarSignificantEchoDbz] or more: the 「無明顯回波」 frame.
  bool get hasSignificantEcho => (strongestDbz ?? -1) >= radarSignificantEchoDbz;

  /// Strongest dBZ in the cell containing [point] of a full website frame and
  /// its 8 neighbours (≈ ±10 km); null when none of them has echo or [point]
  /// is outside the frame. ponytail: raw cell maxima, no speckle rule.
  int? maxDbzNear(LatLng point) {
    final x = (point.longitude - radarFrameWest) / (radarFrameEast - radarFrameWest) * radarFrameSize;
    final y = (radarFrameNorth - point.latitude) / (radarFrameNorth - radarFrameSouth) * radarFrameSize;
    if (x < 0 || y < 0 || x >= radarFrameSize || y >= radarFrameSize) return null;
    final cx = x ~/ radarStatsCellPixels, cy = y ~/ radarStatsCellPixels;
    int? best;
    for (var row = max(0, cy - 1); row <= min(gridRows - 1, cy + 1); row++) {
      for (var col = max(0, cx - 1); col <= min(gridColumns - 1, cx + 1); col++) {
        final v = cellMaxDbz[row * gridColumns + col];
        if (v != radarNoEcho && (best == null || v > best)) best = v;
      }
    }
    return best;
  }

  Uint8List toBytes() {
    final words = Uint32List.fromList([gridColumns, gridRows, ...pixelsPerDbz]);
    return (BytesBuilder(copy: false)
          ..add(words.buffer.asUint8List())
          ..add(cellMaxDbz))
        .takeBytes();
  }

  /// Inverse of [toBytes]; [source] names the file in errors.
  factory RadarEchoStats.fromBytes(Uint8List bytes, {required String source}) {
    final headerBytes = (_headerWords + radarEchoPalette.length) * Uint32List.bytesPerElement;
    if (bytes.length < headerBytes) {
      throw FormatException('$source: expected at least $headerBytes bytes of echo stats, got ${bytes.length}');
    }
    final words = bytes.buffer.asByteData(bytes.offsetInBytes, headerBytes);
    int word(int i) => words.getUint32(i * Uint32List.bytesPerElement, Endian.host);
    final columns = word(0), rows = word(1);
    if (bytes.length != headerBytes + columns * rows) {
      throw FormatException(
          '$source: expected ${headerBytes + columns * rows} bytes for a $columns x $rows grid, got ${bytes.length}');
    }
    return RadarEchoStats(
      gridColumns: columns,
      gridRows: rows,
      pixelsPerDbz: [for (var d = 0; d < radarEchoPalette.length; d++) word(_headerWords + d)],
      cellMaxDbz: Uint8List.fromList(bytes.sublist(headerBytes)),
    );
  }
}

/// Counts echo pixels of [src] (source rows, before reprojection) per dBZ and
/// the strongest dBZ per [radarStatsCellPixels] cell. Pixels inside
/// [decorations] are not echo (same rule as `keyRadarEcho`).
RadarEchoStats radarEchoStats(img.Image src, {List<PixelRect> decorations = const []}) {
  requireRgb8(src);
  final echoBits = radarEchoColourBits();
  final dbzOf = {for (final (d, c) in radarEchoPalette.indexed) c: d};
  final counts = List<int>.filled(radarEchoPalette.length, 0);
  final columns = (src.width / radarStatsCellPixels).ceil();
  final rows = (src.height / radarStatsCellPixels).ceil();
  final cells = Uint8List(columns * rows)..fillRange(0, columns * rows, radarNoEcho);
  final s = src.toUint8List();
  for (var y = 0; y < src.height; y++) {
    final sRow = y * src.rowStride;
    final cellRow = (y ~/ radarStatsCellPixels) * columns;
    for (var x = 0; x < src.width; x++) {
      final si = sRow + x * 3;
      final c = (s[si] << 16) | (s[si + 1] << 8) | s[si + 2];
      if (echoBits[c >> 5] & (1 << (c & 31)) == 0) continue;
      final d = dbzOf[c]!;
      if (decorations.any((r) => x >= r.left && x < r.right && y >= r.top && y < r.bottom)) continue;
      counts[d]++;
      final ci = cellRow + x ~/ radarStatsCellPixels;
      if (cells[ci] == radarNoEcho || d > cells[ci]) cells[ci] = d;
    }
  }
  return RadarEchoStats(pixelsPerDbz: counts, cellMaxDbz: cells, gridColumns: columns, gridRows: rows);
}
