import 'dart:typed_data';

import 'package:cwb_flutter/data/radar/radar_webp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const width = 37, height = 23; // odd sizes: no alignment luck
  // Opaque colours and transparent pixels written as 0,0,0,0 (decoded alpha is premultiplied,
  // identical to straight alpha for alpha 0 and 255).
  Uint8List fixture() {
    final rgba = Uint8List(width * height * 4);
    for (var i = 0; i < width * height; i++) {
      if (i % 3 != 0) rgba.setAll(i * 4, [i * 5 & 0xFF, i * 11 & 0xFF, i * 13 & 0xFF, 255]);
    }
    return rgba;
  }

  test('encode then decode returns every RGBA byte; transparent pixels stay transparent', () {
    final src = fixture();
    final webp = encodeRadarWebp(src, width, height);
    expect(radarWebpSize(webp), (width: width, height: height));
    final out = decodeRadarWebp(webp);
    for (var i = 0; i < width * height; i++) {
      expect(out.sublist(i * 4, i * 4 + 4), src.sublist(i * 4, i * 4 + 4), reason: 'pixel $i');
    }
  });

  test('size from the first header bytes only', () {
    final webp = encodeRadarWebp(fixture(), width, height);
    expect(radarWebpSize(webp.sublist(0, radarWebpHeaderBytes)), (width: width, height: height));
  });

  test('bad input fails loudly with the call, the code and the affected data', () {
    expect(() => encodeRadarWebp(Uint8List(10), width, height), throwsArgumentError);
    final garbage = Uint8List.fromList(List.filled(64, 7));
    expect(() => radarWebpSize(garbage), throwsA(isA<RadarWebpException>().having((e) => e.code, 'code', isNegative)));
    final webp = encodeRadarWebp(fixture(), width, height);
    expect(() => decodeRadarWebp(webp.sublist(0, webp.length ~/ 2)),
        throwsA(isA<RadarWebpException>().having((e) => e.call, 'call', 'radar_webp_decode_rgba_into')));
  });
}
