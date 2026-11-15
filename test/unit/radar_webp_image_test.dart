import 'dart:io';

import 'package:cwb_flutter/features/radar/widgets/radar_webp_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RadarWebpImage cache key is the file path', () {
    test('the map and its pre-decode build equal keys from separate File objects', () {
      final a = RadarWebpImage(File('cache/20261115010000.webp'));
      final b = RadarWebpImage(File('cache/20261115010000.webp'));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('another frame is another key', () {
      expect(
        RadarWebpImage(File('cache/20261115010000.webp')) == RadarWebpImage(File('cache/20261115011000.webp')),
        isFalse,
      );
    });
  });
}
