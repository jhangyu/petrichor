import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:petrichor/data/radar/radar_loop.dart';
import 'package:petrichor/features/radar/radar_player.dart';

/// Slot times t(0) oldest … t(n) newest, 10 minutes apart.
DateTime t(int i) => DateTime.utc(2026, 11, 15, 0, 10 * i);

RadarSlot ready(int i) => RadarSlot.ready(RadarFrame(
      time: t(i),
      file: File('unused-$i.png'),
      bounds: LatLngBounds(const LatLng(20, 118), const LatLng(27, 124)),
      significantDbz: null,
      width: 2048,
      height: 2132,
    ));

const _frameDelay = Duration(milliseconds: 250);

RadarPlayer player() =>
    RadarPlayer(slots: () => [ready(0), ready(1), ready(2), ready(3)], framesPerSecond: () => 4, repeat: () => true);

void main() {
  // testWidgets runs the player's Timer on the fake clock.
  testWidgets('a suspended loop holds at the playhead and resume continues from it', (tester) async {
    final p = player();
    p.togglePlay();
    await tester.pump(_frameDelay);
    expect(p.playhead, t(1));

    p.suspend();
    await tester.pump(_frameDelay * 8);
    p.onFramesPerSecondChanged(); // a settings change while hidden must not restart the steps
    await tester.pump(_frameDelay * 8);
    expect((p.playhead, p.playing), (t(1), true));

    p.resume();
    await tester.pump(_frameDelay);
    expect(p.playhead, t(2));
    p.dispose();
  });

  testWidgets('resume does not start a loop that was stopped or reset', (tester) async {
    final idle = player();
    idle.suspend();
    idle.resume();
    await tester.pump(_frameDelay * 4);
    expect((idle.playhead, idle.playing), (null, false));

    final reset = player();
    reset.togglePlay();
    reset.suspend();
    reset.reset();
    reset.resume();
    await tester.pump(_frameDelay * 4);
    expect((reset.playhead, reset.playing), (null, false));
    idle.dispose();
    reset.dispose();
  });
}
