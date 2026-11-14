import 'dart:io';

import 'package:cwb_flutter/data/radar/radar_frame_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  // 64x64 crop at (1536,768) of the real frame CV1_3600_202611142050.png: echo
  // partly covered by a grey coastline. Expected counts measured independently
  // (PIL/numpy against the legend colours, see radar-impl-notes.md).
  final src = img.decodePng(File('test/fixtures/radar/cv1_3600_202611142050_crop_1536_768_64.png').readAsBytesSync())!;
  final identityRows = List<int>.generate(src.height, (i) => i);
  final keyed = keyRadarEcho(src, rowMap: identityRows);

  test('background becomes transparent, echo keeps its RGB exactly', () {
    var echo = 0, background = 0, sumR = 0, sumG = 0, sumB = 0;
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
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
          expect([o.r, o.g, o.b, o.a], [0, 0, 0, 0], reason: 'background pixel ($x,$y)');
        }
      }
    }
    expect((echo, background), (1607, 2489));
    expect((sumR, sumG, sumB), (46818, 266566, 101745));
  });

  test('decoration rectangles are background even in legend colours', () {
    final cut = keyRadarEcho(src, rowMap: identityRows, decorations: const [(left: 0, top: 0, right: 64, bottom: 32)]);
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        expect(cut.getPixel(x, y).a, y < 32 ? 0 : keyed.getPixel(x, y).a, reason: '($x,$y)');
      }
    }
  });

  test('lossless WebP round trip is pixel-identical', () {
    final back = img.decodeWebP(img.encodeWebP(keyed, lossless: true))!;
    expect(back.numChannels, 4);
    expect(back.getBytes(order: img.ChannelOrder.rgba), keyed.getBytes(order: img.ChannelOrder.rgba));
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
