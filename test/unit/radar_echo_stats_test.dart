import 'dart:io';
import 'dart:typed_data';

import 'package:cwb_flutter/data/radar/radar_echo_stats.dart';
import 'package:cwb_flutter/data/radar/radar_frame_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

RadarEchoStats _stats(Map<int, int> counts, {int columns = 1, int rows = 1, Uint8List? cells}) => RadarEchoStats(
      pixelsPerDbz: [for (var d = 0; d < radarEchoPalette.length; d++) counts[d] ?? 0],
      cellMaxDbz: cells ?? (Uint8List(columns * rows)..fillRange(0, columns * rows, radarNoEcho)),
      gridColumns: columns,
      gridRows: rows,
    );

void main() {
  // Same 64x64 real-frame crop as radar_frame_processor_test. Expected values
  // computed independently with PIL/numpy against the legend colours.
  final src = img.decodePng(File('test/fixtures/radar/cv1_3600_202611142050_crop_1536_768_64.png').readAsBytesSync())!;

  test('per-dBZ pixel counts and 18 px cell maxima of a real frame crop', () {
    final s = radarEchoStats(src);
    expect({for (final (d, n) in s.pixelsPerDbz.indexed) if (n > 0) d: n}, {
      4: 9, 5: 9, 6: 18, 7: 35, 8: 44, 9: 23, 10: 60, 11: 59, 12: 40, 13: 46, 14: 56, 15: 77, 16: 65, //
      17: 51, 18: 28, 19: 71, 20: 118, 21: 113, 22: 111, 23: 97, 24: 45, 25: 107, 26: 110, 27: 42,
      28: 52, 29: 37, 30: 18, 31: 27, 32: 21, 34: 9, 35: 9,
    });
    const n = radarNoEcho;
    expect((s.gridColumns, s.gridRows), (4, 4));
    expect(s.cellMaxDbz, [34, 35, 15, 8, 34, 30, 19, n, 29, 25, 16, n, 31, 20, n, n]);
    expect(s.strongestDbz, 34, reason: '35 and 34 have 9 px each: 18 >= $radarEchoMinPixels first at 34');
    expect(s.hasSignificantEcho, isTrue);
  });

  test('decoration rectangles are not counted', () {
    final s = radarEchoStats(src, decorations: const [(left: 0, top: 0, right: 64, bottom: 32)]);
    expect(s.pixelsPerDbz.reduce((a, b) => a + b), 711);
  });

  test('strongest level needs radarEchoMinPixels pixels at or above it', () {
    expect(_stats({60: radarEchoMinPixels - 1}).strongestDbz, isNull);
    expect(_stats({60: radarEchoMinPixels - 1, 45: 1}).strongestDbz, 45);
    expect(_stats({60: radarEchoMinPixels}).strongestDbz, 60);
  });

  test('no significant echo below radarSignificantEchoDbz', () {
    expect(_stats({radarSignificantEchoDbz - 1: 1000}).hasSignificantEcho, isFalse);
    expect(_stats({}).hasSignificantEcho, isFalse);
    expect(_stats({radarSignificantEchoDbz: radarEchoMinPixels}).hasSignificantEcho, isTrue);
  });

  test('maxDbzNear reads the place cell and its neighbours of the full frame', () {
    const columns = radarFrameSize ~/ radarStatsCellPixels;
    final cells = Uint8List(columns * columns)..fillRange(0, columns * columns, radarNoEcho);
    // Taipei 25.046058 N 121.516565 E → pixel (2040.0, 1316.0) → cell (113, 73).
    cells[72 * columns + 114] = 42; // diagonal neighbour
    cells[73 * columns + 116] = 60;
    final s = _stats({}, columns: columns, rows: columns, cells: cells);
    expect(s.maxDbzNear(const LatLng(25.046058, 121.516565)), 42);
    expect(s.maxDbzNear(const LatLng(23.0, 120.0)), isNull);
    expect(s.maxDbzNear(const LatLng(30.0, 121.5)), isNull, reason: 'outside the frame');
  });

  test('bytes round trip; wrong length fails loudly', () {
    final s = radarEchoStats(src);
    final back = RadarEchoStats.fromBytes(s.toBytes(), source: 'mem');
    expect((back.gridColumns, back.gridRows), (s.gridColumns, s.gridRows));
    expect(back.pixelsPerDbz, s.pixelsPerDbz);
    expect(back.cellMaxDbz, s.cellMaxDbz);
    final bytes = s.toBytes();
    expect(() => RadarEchoStats.fromBytes(bytes.sublist(0, bytes.length - 1), source: 'mem'), throwsFormatException);
    expect(() => RadarEchoStats.fromBytes(Uint8List(4), source: 'mem'), throwsFormatException);
  });
}
