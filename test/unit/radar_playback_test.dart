import 'dart:io';

import 'package:cwb_flutter/data/radar/radar_frame_repository.dart';
import 'package:cwb_flutter/data/radar/radar_source.dart';
import 'package:cwb_flutter/features/radar/radar_playback.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Slot times t(0) oldest … t(n) newest, 10 minutes apart.
DateTime t(int i) => DateTime.utc(2026, 11, 15, 0, 10 * i);

RadarFrame frame(int i) => RadarFrame(
      time: t(i),
      file: File('unused-$i.png'),
      bounds: LatLngBounds(const LatLng(20, 118), const LatLng(27, 124)),
      significantDbz: null,
      width: 2048,
      height: 2132,
    );

RadarSlot ready(int i) => RadarSlot.ready(frame(i));
RadarSlot pending(int i) => RadarSlot.pending(t(i));
RadarSlot failed(int i) =>
    RadarSlot.failed(t(i), const RadarDataException('test', expected: 'a frame', actual: 'HTTP 404'));

const fps4 = Duration(milliseconds: 250);

RadarStep? next(List<RadarSlot> slots, DateTime? after, {bool repeat = true}) =>
    radarNextStep(slots: slots, after: after, fps: 4, repeat: repeat);

void main() {
  test('starts at the oldest at once and advances oldest to newest at 1/fps', () {
    final slots = [ready(0), ready(1), ready(2)];
    expect(next(slots, null), RadarShow(t(0), Duration.zero));
    expect(next(slots, t(0)), RadarShow(t(1), fps4));
    expect(next(slots, t(1)), RadarShow(t(2), fps4));
  });

  test('stops at a pending slot and resumes once it is ready', () {
    final loading = [ready(0), pending(1), pending(2), ready(3)];
    expect(next(loading, t(0)), RadarWait(t(1)));
    final loaded = [ready(0), ready(1), pending(2), ready(3)];
    expect(next(loaded, t(0)), RadarShow(t(1), fps4));
    expect(next(loaded, t(1)), RadarWait(t(2)));
    // Before play with only the newest ready: waits on the oldest.
    expect(next([pending(0), pending(1), ready(2)], null), RadarWait(t(0)));
  });

  test('skips failed slots, also one waited on', () {
    expect(next([ready(0), failed(1), failed(2), ready(3)], t(0)), RadarShow(t(3), fps4));
    expect(next([ready(0), failed(1), pending(2)], t(0)), RadarWait(t(2)));
  });

  test('after the newest restarts at the oldest after the repeat pause, or ends', () {
    final slots = [failed(0), ready(1), ready(2)];
    expect(next(slots, t(2)), RadarShow(t(1), radarRepeatPause));
    expect(next(slots, t(2), repeat: false), isNull);
    expect(next([pending(0), ready(1)], t(1)), RadarWait(t(0)));
  });

  test('nothing playable ends instead of looping', () {
    expect(next([failed(0), failed(1)], null), isNull);
    expect(next(const [], null), isNull);
  });

  test('shows the newest ready slot until a playhead is set', () {
    final slots = [ready(0), pending(1), ready(2), pending(3)];
    expect(radarShownIndex(slots, null), 2);
    expect(radarShownIndex(slots, t(0)), 0);
    expect(radarShownIndex([pending(0), failed(1)], null), isNull);
  });

  test('while buffering the highlighted cell is the waited slot, else the shown one', () {
    final slots = [pending(0), pending(1), ready(2)];
    expect(radarCurrentCell(slots, shown: 2, waitingOn: t(0)), 0);
    expect(radarCurrentCell(slots, shown: 2, waitingOn: null), 2);
    expect(radarCurrentCell(slots, shown: 2, waitingOn: t(9)), 2);
  });

  test('decodes ahead the next ready frames in play order with the wrap', () {
    final slots = [ready(0), pending(1), ready(2), failed(3), ready(4)];
    List<DateTime> upcoming(DateTime? after) =>
        [for (final f in radarUpcomingFrames(slots, after, count: 2)) f.time];
    expect(upcoming(t(0)), [t(2), t(4)]);
    expect(upcoming(t(4)), [t(0), t(2)]);
    expect(upcoming(null), [t(0), t(2)]);
  });
}
