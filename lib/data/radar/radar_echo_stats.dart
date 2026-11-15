import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'radar_frame_processor.dart';

// Echo statistics of one radar image (website frame or station image),
// computed from the source pixels by `processRadarFrame`.
//
// Colour → dBZ: [radarEchoPalette] index = dBZ. Evidence: the legend bar of
// the real frame CV1_3600_202611142230 (column 3453, rows 2507–3571) is 66
// equal 16-row steps whose colours are palette indices 65 (top) down to 0
// (bottom), i.e. one colour per 1 dBZ over the legend's 0–65 dBZ scale. The
// O-A0084 station images carry the same 66-colour bar.

/// Echo weaker than this is not "明顯回波". Marshall–Palmer (Z = 200 R^1.6):
/// 20 dBZ ≈ 0.65 mm/h, just above the 0.5 mm resolution of CWA rain gauges;
/// weaker echo is mostly drizzle, clear-air or clutter return.
const radarSignificantEchoDbz = 20;

/// From this dBZ the hero calls the echo strong. Marshall–Palmer: 40 dBZ ≈
/// 11.5 mm/h (heavy rain rate); also the start of the 橙 legend band.
const radarStrongEchoDbz = 40;

/// A dBZ level counts in an area (whole image, region, around the place) only
/// if pixels covering at least this many km² reach it. Measured on the real
/// frame CV1_3600_202611142250: a 4 x 10 px block of 65 dBZ inside a 13–18 dBZ
/// field (an isolated bad bin, ≈ 4.6 km²) must not count; the same frame's
/// real ≥ 50 dBZ echo covers ≈ 170 km². ponytail: an area rule, not a
/// connected-blob one; upgrade if artifacts larger than this show up.
const radarEchoMinAreaKm2 = 12.0;

/// Grid cell of the per-area counts, in source pixels (18 px ≈ 6.4 km on a
/// website frame, ≈ 1.5 km on a station image).
const radarStatsCellPixels = 18;

/// Per-cell counts are kept per legend band of this many dBZ (0–9 … 60–65).
const radarDbzBandWidth = 10;
final radarDbzBands = (radarEchoPalette.length - 1) ~/ radarDbzBandWidth + 1;

const _earthKmPerDegree = 111.195;

/// Named lon/lat box, [west, east) x [south, north).
typedef RadarRegion = ({String name, double west, double east, double south, double north});

/// Region of echo outside every [radarRegions] box.
const radarOpenSeaRegion = '外海';

/// Summary regions, first matching box wins (islands first). Groups follow the
/// CWA weather-description areas 北部 (基隆–新竹), 中部 (苗栗–雲林),
/// 南部 (嘉義–屏東), 東部 (宜蘭、花蓮、臺東; CWA often calls 宜蘭 東北部),
/// 離島 (澎湖、金門、馬祖、綠島、蘭嶼). ponytail: boxes, not county polygons;
/// boundaries are approximate county lines: 北/中 24.6°N (新竹–苗栗),
/// 中/南 23.45°N (雲林–嘉義, 北港溪), 東部 from 121.35°E (Central Range ridge
/// line, 宜蘭/花蓮 western county lines), plus a 臺東 coast box. Each main
/// island box reaches ~0.2° offshore so coastal echo is named after the
/// coast. Upgrade to county polygons if users report wrong region names.
const radarRegions = <RadarRegion>[
  (name: '離島', west: 119.3, east: 119.75, south: 23.15, north: 23.85), // 澎湖
  (name: '離島', west: 118.15, east: 118.55, south: 24.35, north: 24.6), // 金門
  (name: '離島', west: 119.85, east: 120.55, south: 25.9, north: 26.4), // 馬祖
  (name: '離島', west: 121.4, east: 121.65, south: 21.95, north: 22.75), // 綠島、蘭嶼
  (name: '東部', west: 121.35, east: 122.1, south: 21.85, north: 24.95),
  (name: '東部', west: 121.0, east: 121.35, south: 22.4, north: 23.4), // 臺東 coast
  (name: '北部', west: 119.95, east: 122.1, south: 24.6, north: 25.45),
  (name: '中部', west: 119.95, east: 121.35, south: 23.45, north: 24.6),
  (name: '南部', west: 119.95, east: 121.35, south: 21.75, north: 23.45),
];

/// Header words (uint32): grid columns, grid rows, image width, image height.
const _headerWords = 4;

/// Header doubles after the words: frame south, west, north, east.
const _frameDoubles = 4;

class RadarEchoStats {
  /// Extent of the source image (linear in latitude and longitude).
  final LatLngBounds frame;
  final int imageWidth;
  final int imageHeight;

  /// Echo pixel count per dBZ over the whole image (index = dBZ, 0..65).
  final List<int> pixelsPerDbz;

  /// Echo pixel count per cell and legend band: index
  /// `(row * gridColumns + col) * radarDbzBands + band`, rows from the north.
  final Uint16List cellBandPixels;
  final int gridColumns;
  final int gridRows;

  RadarEchoStats({
    required this.frame,
    required this.imageWidth,
    required this.imageHeight,
    required this.pixelsPerDbz,
    required this.cellBandPixels,
    required this.gridColumns,
    required this.gridRows,
  }) {
    if (pixelsPerDbz.length != radarEchoPalette.length ||
        cellBandPixels.length != gridColumns * gridRows * radarDbzBands ||
        gridColumns != (imageWidth / radarStatsCellPixels).ceil() ||
        gridRows != (imageHeight / radarStatsCellPixels).ceil()) {
      throw ArgumentError(
        'RadarEchoStats: expected ${radarEchoPalette.length} dBZ counts and a '
        '${(imageWidth / radarStatsCellPixels).ceil()} x ${(imageHeight / radarStatsCellPixels).ceil()} x $radarDbzBands '
        'cell grid for $imageWidth x $imageHeight px, got ${pixelsPerDbz.length} counts and '
        '$gridColumns x $gridRows grid with ${cellBandPixels.length} values',
      );
    }
  }

  /// Pixels needed for [radarEchoMinAreaKm2] at this image's scale.
  int get minPixels {
    final midLat = (frame.north + frame.south) / 2;
    final pxKm2 = (frame.north - frame.south) / imageHeight * _earthKmPerDegree *
        (frame.east - frame.west) / imageWidth * _earthKmPerDegree * cos(midLat * pi / 180);
    return (radarEchoMinAreaKm2 / pxKm2).ceil();
  }

  /// Highest dBZ reached over [radarEchoMinAreaKm2]; null when no level is.
  int? get strongestDbz => _highestLevel(pixelsPerDbz);

  /// No level of [radarSignificantEchoDbz] or more: the 「無明顯回波」 image.
  bool get hasSignificantEcho => (strongestDbz ?? -1) >= radarSignificantEchoDbz;

  /// Lowest dBZ of the strongest legend band reached over [radarEchoMinAreaKm2]
  /// in the cell containing [point] and its 8 neighbours (≈ ±10 km on a
  /// website frame); null when no band is, or [point] is outside [frame].
  int? bandNear(LatLng point) {
    final cx = ((point.longitude - frame.west) / (frame.east - frame.west) * imageWidth).floor() ~/ radarStatsCellPixels;
    final cy = ((frame.north - point.latitude) / (frame.north - frame.south) * imageHeight).floor() ~/ radarStatsCellPixels;
    if (point.longitude < frame.west || point.latitude > frame.north || cx >= gridColumns || cy >= gridRows) return null;
    final bands = List<int>.filled(radarDbzBands, 0);
    for (var row = max(0, cy - 1); row <= min(gridRows - 1, cy + 1); row++) {
      for (var col = max(0, cx - 1); col <= min(gridColumns - 1, cx + 1); col++) {
        _addCell(bands, row * gridColumns + col);
      }
    }
    return _highestBand(bands);
  }

  /// Lowest dBZ of the strongest legend band reached over
  /// [radarEchoMinAreaKm2] per region of [radarRegions] (by cell centre; cells
  /// in no box count as [radarOpenSeaRegion]). Regions without one are absent.
  Map<String, int> regionBands() {
    final bandsOf = <String, List<int>>{};
    for (var row = 0; row < gridRows; row++) {
      final lat = frame.north - (row + 0.5) * radarStatsCellPixels / imageHeight * (frame.north - frame.south);
      for (var col = 0; col < gridColumns; col++) {
        final lon = frame.west + (col + 0.5) * radarStatsCellPixels / imageWidth * (frame.east - frame.west);
        final region = radarRegions
                .where((r) => lon >= r.west && lon < r.east && lat >= r.south && lat < r.north)
                .firstOrNull
                ?.name ??
            radarOpenSeaRegion;
        _addCell(bandsOf[region] ??= List<int>.filled(radarDbzBands, 0), row * gridColumns + col);
      }
    }
    return {for (final MapEntry(:key, :value) in bandsOf.entries) key: ?_highestBand(value)};
  }

  void _addCell(List<int> bands, int cell) {
    for (var b = 0; b < radarDbzBands; b++) {
      bands[b] += cellBandPixels[cell * radarDbzBands + b];
    }
  }

  int? _highestBand(List<int> bands) => switch (_highestLevel(bands)) {
        final b? => b * radarDbzBandWidth,
        null => null,
      };

  /// Highest index whose count, summed with all higher ones, reaches [minPixels].
  int? _highestLevel(List<int> counts) {
    final need = minPixels;
    var atOrAbove = 0;
    for (var i = counts.length - 1; i >= 0; i--) {
      atOrAbove += counts[i];
      if (atOrAbove >= need) return i;
    }
    return null;
  }

  Uint8List toBytes() {
    final words = Uint32List.fromList([gridColumns, gridRows, imageWidth, imageHeight]);
    final doubles = Float64List.fromList([frame.south, frame.west, frame.north, frame.east]);
    return (BytesBuilder(copy: false)
          ..add(words.buffer.asUint8List())
          ..add(doubles.buffer.asUint8List())
          ..add(Uint32List.fromList(pixelsPerDbz).buffer.asUint8List())
          ..add(cellBandPixels.buffer.asUint8List(cellBandPixels.offsetInBytes, cellBandPixels.lengthInBytes)))
        .takeBytes();
  }

  /// Inverse of [toBytes]; [source] names the file in errors.
  factory RadarEchoStats.fromBytes(Uint8List bytes, {required String source}) {
    const wordBytes = Uint32List.bytesPerElement, doubleBytes = Float64List.bytesPerElement;
    final countsAt = _headerWords * wordBytes + _frameDoubles * doubleBytes;
    final cellsAt = countsAt + radarEchoPalette.length * wordBytes;
    if (bytes.length < cellsAt) {
      throw FormatException('$source: expected at least $cellsAt bytes of echo stats, got ${bytes.length}');
    }
    final data = ByteData.sublistView(bytes);
    int word(int offset) => data.getUint32(offset, Endian.host);
    double float(int i) => data.getFloat64(_headerWords * wordBytes + i * doubleBytes, Endian.host);
    final columns = word(0), rows = word(wordBytes);
    final expected = cellsAt + columns * rows * radarDbzBands * Uint16List.bytesPerElement;
    if (bytes.length != expected) {
      throw FormatException('$source: expected $expected bytes for a $columns x $rows grid, got ${bytes.length}');
    }
    return RadarEchoStats(
      frame: LatLngBounds(LatLng(float(0), float(1)), LatLng(float(2), float(3))),
      gridColumns: columns,
      gridRows: rows,
      imageWidth: word(2 * wordBytes),
      imageHeight: word(3 * wordBytes),
      pixelsPerDbz: [for (var d = 0; d < radarEchoPalette.length; d++) word(countsAt + d * wordBytes)],
      cellBandPixels: Uint16List.fromList([
        for (var i = cellsAt; i < bytes.length; i += Uint16List.bytesPerElement) data.getUint16(i, Endian.host),
      ]),
    );
  }
}
