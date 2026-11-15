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
}
