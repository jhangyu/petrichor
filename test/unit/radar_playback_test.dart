import 'package:cwb_flutter/features/radar/radar_playback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('advances at 1/fps and waits 3 s after the last frame only when repeating', () {
    final mid = radarNextTick(index: 5, count: 24, fps: 4, repeat: true)!;
    expect(mid.delay, const Duration(milliseconds: 250));
    expect(mid.nextIndex, 6);

    final last = radarNextTick(index: 23, count: 24, fps: 8, repeat: true)!;
    expect(last.delay, const Duration(seconds: 3));
    expect(last.nextIndex, 0);

    expect(radarNextTick(index: 23, count: 24, fps: 4, repeat: false), isNull);
  });

  test('index outside the frame list is rejected', () {
    expect(() => radarNextTick(index: 24, count: 24, fps: 4, repeat: true), throwsRangeError);
  });

  test('times render as Taiwan time', () {
    expect(formatTaiwanMonthDayClock(DateTime.utc(2026, 11, 14, 6, 0)), '11/14 14:00');
    expect(formatTaiwanFull(DateTime.utc(2026, 11, 14, 18, 5)), '2026-11-15 02:05');
  });
}
