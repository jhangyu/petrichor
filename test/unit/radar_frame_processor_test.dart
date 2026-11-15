import 'dart:io';

import 'package:cwb_flutter/data/radar/radar_frame_processor.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

void main() {
  // 64x64 crop at (1536,768) of the real frame CV1_3600_202611142050.png: echo
  // partly covered by a grey coastline. Expected counts measured independently
  // (PIL/numpy against the legend colours, see radar-impl-notes.md).
  final png = File('test/fixtures/radar/cv1_3600_202611142050_crop_1536_768_64.png').readAsBytesSync();
  final src = img.decodePng(png)!;
  final bounds = LatLngBounds(const LatLng(26.59, 119.9), const LatLng(26.8, 120.11));
  final identityRows = List<int>.generate(64, (i) => i);
  RadarImageGeometry geometry({List<int>? rowMap, List<PixelRect> decorations = const []}) =>
      RadarImageGeometry(
        size: 64, bounds: bounds, rowMap: rowMap ?? identityRows, decorations: decorations, palette: radarEchoPalette);
  img.Image decode(ProcessedRadarFrame p) => img.decodePng(p.png)!;
  final keyed = decode(processRadarFrame(png, geometry()));

  test('output is one indexed PNG; background transparent, echo keeps its RGB exactly', () {
    expect((keyed.hasPalette, keyed.width, keyed.height), (true, 64, 64));
    var echo = 0, background = 0, sumR = 0, sumG = 0, sumB = 0;
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        final o = keyed.getPixel(x, y);
        final s = src.getPixel(x, y);
        if (o.a == 255) {
          echo++;
          expect([o.r, o.g, o.b], [s.r, s.g, s.b], reason: 'echo pixel ($x,$y)');
          sumR += o.r.toInt();
          sumG += o.g.toInt();
          sumB += o.b.toInt();
        } else {
          background++;
          expect(o.a, 0, reason: 'background pixel ($x,$y)');
          final c = (s.r.toInt() << 16) | (s.g.toInt() << 8) | s.b.toInt();
          expect(radarEchoPalette, isNot(contains(c)), reason: 'echo colour keyed out at ($x,$y)');
        }
      }
    }
    expect((echo, background), (1607, 2489));
    expect((sumR, sumG, sumB), (46818, 266566, 101745));
  });

  test('decoration rectangles are background even in legend colours', () {
    final cut = decode(processRadarFrame(png, geometry(decorations: const [(left: 0, top: 0, right: 64, bottom: 32)])));
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        expect(cut.getPixel(x, y).a, y < 32 ? 0 : keyed.getPixel(x, y).a, reason: '($x,$y)');
      }
    }
  });

  test('output row j is source row rowMap[j] (duplicated rows); statistics count each source row once', () {
    final rowMap = [for (var y = 0; y < 64; y++) ...(y.isEven ? [y, y] : [y])];
    final p = processRadarFrame(png, geometry(rowMap: rowMap));
    final out = decode(p);
    expect(out.height, rowMap.length);
    for (var j = 0; j < rowMap.length; j++) {
      for (var x = 0; x < 64; x++) {
        expect(out.getPixel(x, j), keyed.getPixel(x, rowMap[j]), reason: 'output ($x,$j)');
      }
    }
    expect(p.stats.pixelsPerDbz.reduce((a, b) => a + b), 1607);
  });

  test('wrong size or a row map that skips source rows fails loudly', () {
    expect(() => processRadarFrame(png, RadarImageGeometry(size: 3600, bounds: bounds, rowMap: identityRows, decorations: const [], palette: radarEchoPalette)),
        throwsFormatException);
    expect(() => processRadarFrame(png, geometry(rowMap: [0, 2, 1])), throwsArgumentError);
  });

  test('stored image is 2048 wide: nearest source pixel, exact palette indices, statistics from the full source', () {
    const size = 2304; // not a multiple of 2048: exercises the uneven nearest mapping
    int level(int x, int y) => (x * 7 + y * 13) % 70; // 0..65 echo, 66..69 background
    final rgb = img.Image(width: size, height: size);
    final counts = List<int>.filled(66, 0);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final l = level(x, y);
        final c = l < 66 ? radarEchoPalette[l] : 0x808080;
        if (l < 66) counts[l]++;
        rgb.setPixelRgb(x, y, c >> 16, (c >> 8) & 0xFF, c & 0xFF);
      }
    }
    final p = processRadarFrame(
      img.encodePng(rgb),
      RadarImageGeometry(
        size: size,
        bounds: bounds,
        rowMap: List<int>.generate(size, (i) => i),
        decorations: const [],
        palette: radarEchoPalette,
      ),
    );
    final out = img.decodePng(p.png)!;
    expect((out.width, out.height, out.hasPalette), (2048, 2048, true));
    final data = out.toUint8List();
    for (var oy = 0; oy < 2048; oy++) {
      for (var ox = 0; ox < 2048; ox++) {
        final l = level(ox * size ~/ 2048, oy * size ~/ 2048);
        if (data[oy * out.rowStride + ox] != (l < 66 ? l + 1 : 0)) fail('index differs at ($ox,$oy)');
      }
    }
    expect(p.stats.pixelsPerDbz, counts);
    expect((p.stats.imageWidth, p.stats.imageHeight), (size, size));
  });

  test('Mercator row map for the 3600 frame keeps every source row in order', () {
    final rows = mercatorRowMap(srcHeight: 3600, south: 17.75, north: 29.25);
    expect(rows.first, 0);
    expect(rows.last, 3599);
    for (var j = 1; j < rows.length; j++) {
      expect(rows[j] - rows[j - 1], inInclusiveRange(0, 1), reason: 'row $j');
    }
    expect(rows.length, greaterThan(3600));
  });
}
