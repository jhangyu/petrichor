import 'dart:io';

import 'package:petrichor/data/radar/radar_frame_list.dart';
import 'package:flutter_test/flutter_test.dart';

/// `yyyyMMddHHmm` (or with [seconds] `yyyyMMddHHmmss`) Taiwan time of [f].
String _stamp(RadarFrameRef f, {bool seconds = false}) {
  final l = f.time.add(const Duration(hours: 8));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year}${two(l.month)}${two(l.day)}${two(l.hour)}${two(l.minute)}${seconds ? two(l.second) : ''}';
}

void main() {
  // Saved copy of www.cwa.gov.tw/Data/js/obs_img/Observe_radar.js (newest frame 2026-11-14 20:50 Taiwan time).
  final frames = parseRadarFrameList(File('test/fixtures/radar/Observe_radar_20261114_2050.js').readAsStringSync());

  List<String> stamps(List<RadarFrameRef> f) => [for (final x in f) _stamp(x)];

  test('parses only the CV1_3600 set: 145 frames, Taiwan time converted to UTC', () {
    expect(frames, hasLength(145));
    final newest = frames.reduce((a, b) => a.time.isAfter(b.time) ? a : b);
    expect(_stamp(newest), '202611142050');
    expect(newest.time, DateTime.utc(2026, 11, 14, 12, 50));
    expect(newest.url, 'https://www.cwa.gov.tw/Data/radar/CV1_3600_202611142050.png');
  });

  test('window at 20:55 Taiwan time = latest 12 frames 19:00..20:50, oldest first', () {
    final w = selectRadarFrameWindow(frames, now: DateTime.utc(2026, 11, 14, 12, 55), window: const Duration(hours: 2));
    expect(stamps(w), [
      for (var m = 19 * 60; m <= 20 * 60 + 50; m += 10)
        '20261114${(m ~/ 60).toString().padLeft(2, '0')}${(m % 60).toString().padLeft(2, '0')}',
    ]);
  });

  test('default window = 24 frames (4 h) 17:00..20:50; 1 h = 6, max 144 (24 h) = whole list', () {
    final w = selectRadarFrameWindow(frames, now: DateTime.utc(2026, 11, 14, 12, 55), window: const Duration(hours: 4));
    expect((w.length, _stamp(w.first), _stamp(w.last)), (24, '202611141700', '202611142050'));
    final all = selectRadarFrameWindow(frames, now: DateTime.utc(2026, 11, 14, 12, 55), window: radarWebsiteMaxWindow);
    expect((all.length, _stamp(all.first)), (144, '202611132100'));
    expect(() => selectRadarFrameWindow(frames, now: DateTime.utc(2026, 11, 14), window: Duration.zero), throwsArgumentError);
    final hour = selectRadarFrameWindow(frames, now: DateTime.utc(2026, 11, 14, 12, 55), window: const Duration(hours: 1));
    expect(stamps(hour), ['202611142000', '202611142010', '202611142020', '202611142030', '202611142040', '202611142050']);
  });

  test('window ends at the newest frame even when the clock is past it; stale list gives nothing', () {
    List<RadarFrameRef> at(DateTime now) => selectRadarFrameWindow(frames, now: now, window: const Duration(hours: 2));
    expect(stamps(at(DateTime.utc(2026, 11, 14, 13, 5))).first, '202611141900');
    expect(at(DateTime.utc(2026, 11, 14, 14, 50)), hasLength(12));
    expect(at(DateTime.utc(2026, 11, 14, 14, 51)), isEmpty);
  });

  test('a missing slot stays missing, not padded with an older frame', () {
    final gap = frames.where((f) => _stamp(f) != '202611142000').toList();
    final w = selectRadarFrameWindow(gap, now: DateTime.utc(2026, 11, 14, 12, 55), window: const Duration(hours: 2));
    expect(w, hasLength(11));
    expect(_stamp(w.first), '202611141900');
  });

  test('a list without CV1_3600 entries fails loudly', () {
    expect(() => parseRadarFrameList("var RadarImg = {0:{\"img\":'CV2_3600_202611142050.png'}}"),
        throwsFormatException);
  });

  group('station list (Observe_radar_rain.js saved 2026-11-15 11:42, trimmed: 6 newest + 2 oldest per station)', () {
    final js = File('test/fixtures/radar/Observe_radar_rain_20261115_1135.js').readAsStringSync();
    final shulin = parseRadarStationList(js, code: 'RCSL');
    List<String> stamps(List<RadarFrameRef> f) => [for (final x in f) _stamp(x, seconds: true)];

    test("only this station's 3600 set; time to the second from the name; URL from the list", () {
      expect(shulin, hasLength(8));
      final newest = shulin.reduce((a, b) => a.time.isAfter(b.time) ? a : b);
      expect(newest.time, DateTime.utc(2026, 11, 15, 3, 35, 2));
      expect(
        newest.url,
        'https://www.cwa.gov.tw/Data/radar_rain/CV1_RCSL_3600/CV1_RCSL_3600_20261115113502_'
        '815460ea9bfd85c76edf8099653ed3eb2528959a7eb5a4956f771e277900e1b4.png',
      );
      expect(shulin.every((f) => f.url.contains('/CV1_RCSL_3600/')), isTrue);
      expect(parseRadarStationList(js, code: 'RCLY'), hasLength(8));
      expect(() => parseRadarStationList(js, code: 'RCXX'), throwsFormatException);
    });

    test('irregular spacing: the window is a time span, not a frame count', () {
      final now = DateTime.utc(2026, 11, 15, 3, 36);
      final tenMinutes = selectRadarFrameWindow(shulin, now: now, window: const Duration(minutes: 10));
      expect(stamps(tenMinutes), ['20261115112604', '20261115112748', '20261115113000', '20261115113126', '20261115113319', '20261115113502']);
      final sixHours = selectRadarFrameWindow(shulin, now: now, window: radarStationMaxWindow);
      expect(stamps(sixHours).first, '20261115112604', reason: '05:26:29 is 6 h 8 min before the newest frame');
      expect(selectRadarFrameWindow(shulin, now: now, window: const Duration(hours: 7)), hasLength(8));
    });
  });
}
