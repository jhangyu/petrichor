import 'dart:io';
import 'dart:typed_data';

import 'package:cwb_flutter/data/radar/radar_bounds.dart';
import 'package:cwb_flutter/data/radar/radar_echo_stats.dart';
import 'package:cwb_flutter/data/radar/radar_frame_processor.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const _columns = radarFrameSize ~/ radarStatsCellPixels;

/// Pixels for [radarEchoMinAreaKm2] on a full website frame (computed
/// independently: 12 km² / (11.5°/3600 · 111.195 km)² / cos 23.5°).
const _frameMinPixels = 104;

/// Full website-frame stats from per-dBZ [counts] and per-cell band pixels
/// keyed (col, row, band).
RadarEchoStats _stats({Map<int, int> counts = const {}, Map<(int, int, int), int> cells = const {}}) {
  final grid = Uint16List(_columns * _columns * radarDbzBands);
  cells.forEach((k, px) => grid[(k.$2 * _columns + k.$1) * radarDbzBands + k.$3] = px);
  return RadarEchoStats(
    frame: websiteRadarFrameBounds,
    imageWidth: radarFrameSize,
    imageHeight: radarFrameSize,
    pixelsPerDbz: [for (var d = 0; d < radarEchoPalette.length; d++) counts[d] ?? 0],
    cellBandPixels: grid,
    gridColumns: _columns,
    gridRows: _columns,
  );
}

void main() {
  // Same 64x64 real-frame crop as radar_frame_processor_test, at source pixel
  // (1536,768) of CV1_3600_202611142050. Expected values computed
  // independently with PIL/numpy against the legend colours.
  final png = File('test/fixtures/radar/cv1_3600_202611142050_crop_1536_768_64.png').readAsBytesSync();
  final cropFrame = LatLngBounds(
    const LatLng(26.592222222222222, 119.90666666666667),
    const LatLng(26.796666666666667, 120.11111111111111),
  );
  RadarEchoStats cropStats({List<PixelRect> decorations = const []}) => processRadarFrame(
        png,
        RadarImageGeometry(
          size: 64,
          bounds: cropFrame,
          rowMap: List.generate(64, (i) => i),
          decorations: decorations,
          palette: radarEchoPalette,
        ),
      ).stats;

  test('per-dBZ counts, per-cell band counts and strongest level of a real frame crop', () {
    final s = cropStats();
    expect({for (final (d, n) in s.pixelsPerDbz.indexed) if (n > 0) d: n}, {
      4: 9, 5: 9, 6: 18, 7: 35, 8: 44, 9: 23, 10: 60, 11: 59, 12: 40, 13: 46, 14: 56, 15: 77, 16: 65, //
      17: 51, 18: 28, 19: 71, 20: 118, 21: 113, 22: 111, 23: 97, 24: 45, 25: 107, 26: 110, 27: 42,
      28: 52, 29: 37, 30: 18, 31: 27, 32: 21, 34: 9, 35: 9,
    });
    expect((s.gridColumns, s.gridRows), (4, 4));
    expect(s.cellBandPixels, [
      11, 70, 47, 6, 0, 0, 0, 5, 67, 87, 27, 0, 0, 0, 71, 81, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, //
      0, 9, 234, 33, 0, 0, 0, 0, 54, 109, 3, 0, 0, 0, 21, 85, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 45, 250, 0, 0, 0, 0, 9, 85, 51, 0, 0, 0, 0, 15, 26, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 45, 15, 0, 0, 0, 0, 31, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ]);
    expect(s.minPixels, 107);
    expect(s.strongestDbz, 29, reason: 'pixels at >= 29 dBZ: 121, at >= 30: 84 (need 107)');
    expect(s.hasSignificantEcho, isTrue);
  });

  test('decoration rectangles are not counted', () {
    final s = cropStats(decorations: const [(left: 0, top: 0, right: 64, bottom: 32)]);
    expect(s.pixelsPerDbz.reduce((a, b) => a + b), 711);
  });

  test('strongest level needs radarEchoMinAreaKm2 at or above it', () {
    expect(_stats().minPixels, _frameMinPixels);
    expect(_stats(counts: {60: _frameMinPixels - 1}).strongestDbz, isNull);
    expect(_stats(counts: {60: _frameMinPixels - 1, 45: 1}).strongestDbz, 45);
    expect(_stats(counts: {60: _frameMinPixels}).strongestDbz, 60);
  });

  test('no significant echo below radarSignificantEchoDbz', () {
    expect(_stats(counts: {radarSignificantEchoDbz - 1: 10000}).hasSignificantEcho, isFalse);
    expect(_stats().hasSignificantEcho, isFalse);
    expect(_stats(counts: {radarSignificantEchoDbz: _frameMinPixels}).hasSignificantEcho, isTrue);
  });

  test('bandNear sums the place cell and its 8 neighbours', () {
    // Taipei 25.046058 N 121.516565 E → pixel (2040.0, 1316.0) → cell (113, 73).
    final s = _stats(cells: {
      (113, 73, 4): 50,
      (114, 72, 4): 60, // diagonal neighbour: 110 px >= 104 in band 40–49
      (116, 73, 6): 500, // two cells away: ignored
    });
    expect(s.bandNear(const LatLng(25.046058, 121.516565)), 40);
    expect(s.bandNear(const LatLng(23.0, 120.0)), isNull);
    expect(s.bandNear(const LatLng(30.0, 121.5)), isNull, reason: 'north of the frame');
    expect(s.bandNear(const LatLng(25.0, 114.99)), isNull, reason: 'west of the frame');
  });

  test('regions: area rule per region; islands before main-island boxes', () {
    final s = _stats(cells: {
      (113, 73, 4): 60, // Taipei 25.02 N 121.53 E (cell centre)
      (112, 73, 4): 60,
      (92, 115, 6): 100, // Kaohsiung 22.61 N 120.32 E: below the area rule
      (79, 98, 3): 120, // Penghu 23.59 N 119.57 E
      (139, 126, 2): 104, // 22.0 N 123.0 E, open sea
    });
    expect(s.regionBands(), {'北部': 40, '離島': 30, radarOpenSeaRegion: 20});
  });

  test('bytes round trip; wrong length fails loudly', () {
    final s = cropStats();
    final back = RadarEchoStats.fromBytes(s.toBytes(), source: 'mem');
    expect((back.gridColumns, back.gridRows, back.imageWidth, back.imageHeight), (4, 4, 64, 64));
    expect([back.frame.south, back.frame.west, back.frame.north, back.frame.east],
        [cropFrame.south, cropFrame.west, cropFrame.north, cropFrame.east]);
    expect(back.pixelsPerDbz, s.pixelsPerDbz);
    expect(back.cellBandPixels, s.cellBandPixels);
    final bytes = s.toBytes();
    expect(() => RadarEchoStats.fromBytes(bytes.sublist(0, bytes.length - 1), source: 'mem'), throwsFormatException);
    expect(() => RadarEchoStats.fromBytes(Uint8List(4), source: 'mem'), throwsFormatException);
  });
}
