import 'dart:math';

import 'package:cwb_flutter/features/radar/widgets/radar_map_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('radarDecodeWidth follows the on-screen frame width, not the widget width', () {
    const compositeSpan = 126.5 - 115.0;
    int width(double zoom, double dpr) =>
        radarDecodeWidth(lonSpanDegrees: compositeSpan, zoom: zoom, devicePixelRatio: dpr);

    test('zoom 8 at dpr 2 is capped at 2048', () => expect(width(8, 2), 2048));

    test('a frame drawn 600 logical px wide at dpr 2 decodes at 1280 (1200 stepped up)', () {
      final zoom = log(600 / (compositeSpan / 360 * 256)) / ln2;
      expect(width(zoom, 2), 1280);
    });

    test('default zooms: overview 6.5 and located 8.0', () {
      expect([width(6.5, 2), width(6.5, 3), width(8, 2), width(8, 3)], [1536, 2048, 2048, 2048]);
    });
  });
}
