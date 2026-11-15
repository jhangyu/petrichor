import 'dart:io';
import 'dart:typed_data';

import 'package:cwb_flutter/data/radar/radar_bounds.dart';
import 'package:cwb_flutter/data/radar/radar_echo_stats.dart';
import 'package:cwb_flutter/data/radar/radar_frame_processor.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Pixels for [radarEchoMinAreaKm2] on a full website frame (computed
/// independently: 12 km² / (11.5°/3600 · 111.195 km)² / cos 23.5°).
const _frameMinPixels = 104;

/// Full website-frame stats from per-dBZ [counts].
RadarEchoStats _stats({Map<int, int> counts = const {}}) => RadarEchoStats(
      frame: websiteRadarFrameBounds,
      imageWidth: radarFrameSize,
      imageHeight: radarFrameSize,
      pixelsPerDbz: [for (var d = 0; d < radarEchoPalette.length; d++) counts[d] ?? 0],
    );

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

  test('per-dBZ counts and strongest level of a real frame crop', () {
    final s = cropStats();
    expect({for (final (d, n) in s.pixelsPerDbz.indexed) if (n > 0) d: n}, {
      4: 9, 5: 9, 6: 18, 7: 35, 8: 44, 9: 23, 10: 60, 11: 59, 12: 40, 13: 46, 14: 56, 15: 77, 16: 65, //
      17: 51, 18: 28, 19: 71, 20: 118, 21: 113, 22: 111, 23: 97, 24: 45, 25: 107, 26: 110, 27: 42,
      28: 52, 29: 37, 30: 18, 31: 27, 32: 21, 34: 9, 35: 9,
    });
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

  test('bytes round trip; wrong length fails loudly', () {
    final s = cropStats();
    final back = RadarEchoStats.fromBytes(s.toBytes(), source: 'mem');
    expect((back.imageWidth, back.imageHeight), (64, 64));
    expect([back.frame.south, back.frame.west, back.frame.north, back.frame.east],
        [cropFrame.south, cropFrame.west, cropFrame.north, cropFrame.east]);
    expect(back.pixelsPerDbz, s.pixelsPerDbz);
    final bytes = s.toBytes();
    expect(() => RadarEchoStats.fromBytes(bytes.sublist(0, bytes.length - 1), source: 'mem'), throwsFormatException);
    expect(() => RadarEchoStats.fromBytes(Uint8List(4), source: 'mem'), throwsFormatException);
  });
}
