import 'dart:io';

import 'package:cwb_flutter/data/radar/radar_frame_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Saved copy of www.cwa.gov.tw/Data/js/obs_img/Observe_radar.js (newest frame 2026-11-14 20:50 Taiwan time).
  final frames = parseRadarFrameList(File('test/fixtures/radar/Observe_radar_20261114_2050.js').readAsStringSync());

  List<String> stamps(List<RadarFrameRef> f) => [for (final x in f) x.stamp];

  test('parses only the CV1_3600 set: 145 frames, Taiwan time converted to UTC', () {
    expect(frames, hasLength(145));
    final newest = frames.reduce((a, b) => a.time.isAfter(b.time) ? a : b);
    expect(newest.stamp, '202611142050');
    expect(newest.time, DateTime.utc(2026, 11, 14, 12, 50));
    expect(newest.url, 'https://www.cwa.gov.tw/Data/radar/CV1_3600_202611142050.png');
  });

  test('window at 20:55 Taiwan time = latest 12 frames 19:00..20:50, oldest first', () {
    final w = selectRadarFrameWindow(frames, now: DateTime.utc(2026, 11, 14, 12, 55));
    expect(stamps(w), [
      for (var m = 19 * 60; m <= 20 * 60 + 50; m += 10)
        '20261114${(m ~/ 60).toString().padLeft(2, '0')}${(m % 60).toString().padLeft(2, '0')}',
    ]);
  });

  test('window ends at the newest frame even when the clock is past it; stale list gives nothing', () {
    expect(stamps(selectRadarFrameWindow(frames, now: DateTime.utc(2026, 11, 14, 13, 5))).first, '202611141900');
    expect(selectRadarFrameWindow(frames, now: DateTime.utc(2026, 11, 14, 14, 50)), hasLength(12));
    expect(selectRadarFrameWindow(frames, now: DateTime.utc(2026, 11, 14, 14, 51)), isEmpty);
  });

  test('a missing slot stays missing, not padded with an older frame', () {
    final gap = frames.where((f) => f.stamp != '202611142000').toList();
    final w = selectRadarFrameWindow(gap, now: DateTime.utc(2026, 11, 14, 12, 55));
    expect(w, hasLength(11));
    expect(w.first.stamp, '202611141900');
  });

  test('a list without CV1_3600 entries fails loudly', () {
    expect(() => parseRadarFrameList("var RadarImg = {0:{\"img\":'CV2_3600_202611142050.png'}}"),
        throwsFormatException);
  });
}
