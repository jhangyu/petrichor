import 'dart:io';
import 'dart:typed_data';

import 'package:petrichor/data/radar/radar_echo_statistics.dart';import 'package:petrichor/data/radar/radar_frame_processor.dart';
import 'package:petrichor/data/radar/radar_png_rows.dart';
import 'package:petrichor/data/radar/radar_webp.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:latlong2/latlong.dart';

void main() {
  // 64x64 crop at (1536,768) of the real frame CV1_3600_202611142050.png: echo
  // partly covered by a grey coastline. Expected counts measured independently
  // (PIL/numpy against the legend colours, see radar-impl-notes.md).
  final png = File('test/fixtures/radar/cv1_3600_202611142050_crop_1536_768_64.png').readAsBytesSync();
  final source = image.decodePng(png)!;
  final bounds = LatLngBounds(const LatLng(26.59, 119.9), const LatLng(26.8, 120.11));
  final identityRows = List<int>.generate(64, (i) => i);
  RadarImageGeometry geometry({List<int>? rowMap, List<PixelRect> decorations = const []}) =>
      RadarImageGeometry(
        size: 64, bounds: bounds, rowMap: rowMap ?? identityRows, decorations: decorations);
  image.Image decode(ProcessedRadarFrame p) {
    final size = radarWebpSize(p.webp);
    return image.Image.fromBytes(
        width: size.width, height: size.height, bytes: decodeRadarWebp(p.webp).buffer, numChannels: 4);
  }

  final keyed = decode(processRadarFrame(png, geometry()));

  test('output is one lossless WebP; background transparent, echo keeps its RGB exactly', () {
    expect((keyed.width, keyed.height), (64, 64));
    var echo = 0, background = 0, sumR = 0, sumG = 0, sumB = 0;
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        final o = keyed.getPixel(x, y);
        final s = source.getPixel(x, y);
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
    expect(p.statistics.pixelsPerDbz.reduce((a, b) => a + b), 1607);
  });

  test('wrong source size and a row map that is not non-decreasing fail loudly', () {
    expect(() => processRadarFrame(png, RadarImageGeometry(size: 3600, bounds: bounds, rowMap: identityRows, decorations: const [])),
        throwsFormatException);
    expect(() => processRadarFrame(png, geometry(rowMap: [0, 2, 1])), throwsArgumentError);
  });

  test('stored image is 2048 wide: nearest source pixel, exact colours, statistics from the full source', () {
    const size = 2304; // not a multiple of 2048: exercises the uneven nearest mapping
    int level(int x, int y) => (x * 7 + y * 13) % 70; // 0..65 echo, 66..69 background
    final rgb = image.Image(width: size, height: size);
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
      image.encodePng(rgb),
      RadarImageGeometry(
        size: size,
        bounds: bounds,
        rowMap: List<int>.generate(size, (i) => i),
        decorations: const [],
      ),
    );
    expect(radarWebpSize(p.webp), (width: 2048, height: 2048));
    // Pixels as little-endian RGBA words (bytes R, G, B, A); background 0.
    final out = decodeRadarWebp(p.webp).buffer.asUint32List();
    final expectedOfLevel = Uint32List(70);
    for (var l = 0; l < 66; l++) {
      final c = radarEchoPalette[l];
      expectedOfLevel[l] = 0xFF000000 | ((c & 0xFF) << 16) | (c & 0xFF00) | (c >> 16);
    }
    for (var oy = 0; oy < 2048; oy++) {
      for (var ox = 0; ox < 2048; ox++) {
        final expected = expectedOfLevel[level(ox * size ~/ 2048, oy * size ~/ 2048)];
        final actual = out[oy * 2048 + ox];
        if (actual != expected) {
          fail('pixel ($ox,$oy): expected 0x${expected.toRadixString(16)}, got 0x${actual.toRadixString(16)}');
        }
      }
    }
    expect(p.statistics.pixelsPerDbz, counts);
    expect((p.statistics.imageWidth, p.statistics.imageHeight), (size, size));
  });

  test('row reader returns the decoded pixels for every PNG filter and rejects other formats', () {
    const size = 41;
    final rgb = image.Image(width: size, height: size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        rgb.setPixelRgb(x, y, (x * 37 + y * 11) & 0xFF, (x * y * 5) & 0xFF, (x ^ y) * 7 & 0xFF);
      }
    }
    for (final filter in image.PngFilter.values) {
      final rows = <List<int>>[];
      readPngRgbRows(image.encodePng(rgb, filter: filter), size, (y, row) {
        expect(y, rows.length);
        rows.add(List<int>.of(row));
      });
      expect(rows.length, size, reason: '$filter');
      for (var y = 0; y < size; y++) {
        expect(rows[y], [for (var x = 0; x < size; x++) ...[rgb.getPixel(x, y).r, rgb.getPixel(x, y).g, rgb.getPixel(x, y).b]],
            reason: '$filter row $y');
      }
    }
    expect(() => readPngRgbRows(image.encodePng(rgb), size + 1, (_, _) {}), throwsFormatException);
    expect(() => readPngRgbRows(image.encodePng(image.Image(width: size, height: size, numChannels: 4)), size, (_, _) {}),
        throwsFormatException);
    expect(() => readPngRgbRows(image.encodePng(rgb).sublist(0, 100), size, (_, _) {}), throwsFormatException);
  });

  test('Mercator row map for the 3600 frame keeps every source row in order', () {
    final rows = mercatorRowMap(sourceHeight: 3600, south: 17.75, north: 29.25);
    expect(rows.first, 0);
    expect(rows.last, 3599);
    for (var j = 1; j < rows.length; j++) {
      expect(rows[j] - rows[j - 1], inInclusiveRange(0, 1), reason: 'row $j');
    }
    expect(rows.length, greaterThan(3600));
  });
}
