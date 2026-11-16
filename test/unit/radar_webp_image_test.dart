import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petrichor/data/radar/radar_webp_image.dart';

import '../support/temp_dir.dart';

void main() {
  test('same path with different content is a different image key', () {
    final dir = newTempDir('webp_key');
    final file = File('${dir.path}/frame.webp')..writeAsBytesSync([1, 2, 3]);
    final before = RadarWebpImage(file);
    expect(RadarWebpImage(file), before);
    file.writeAsBytesSync([1, 2, 3, 4]);
    final after = RadarWebpImage(file);
    expect(after, isNot(before));
    expect(after.hashCode, isNot(before.hashCode));
  });
}
