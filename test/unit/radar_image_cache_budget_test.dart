import 'dart:math';

import 'package:cwb_flutter/features/radar/widgets/radar_map_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const defaultBytes = 100 << 20;
  const composite = 3748 / 3600;

  test('a 24-frame composite loop at 2048 px is held whole, under the ceiling', () {
    final plan = radarImageCachePlan(frameCount: 24, decodeWidth: 2048, aspect: composite);
    expect(plan.holdsLoop, isTrue);
    expect(plan.maximumBytes, greaterThanOrEqualTo(24 * 2048 * (2048 * composite).ceil() * 4));
    expect(plan.maximumBytes, lessThanOrEqualTo(radarImageCacheCeilingBytes));
  });

  test('a loop over the ceiling keeps the decode width and caps the cache at the ceiling', () {
    final plan = radarImageCachePlan(frameCount: 200, decodeWidth: 2048, aspect: 1);
    expect((plan.holdsLoop, plan.maximumBytes), (false, radarImageCacheCeilingBytes));
  });

  test('the cache never drops below the Flutter default', () {
    expect(radarImageCachePlan(frameCount: 1, decodeWidth: 200, aspect: composite).maximumBytes, defaultBytes);
  });

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
