import 'dart:io';
import 'dart:typed_data';

import 'package:cwb_flutter/data/radar/radar_frame_list.dart';
import 'package:cwb_flutter/data/radar/radar_frame_processor.dart';
import 'package:cwb_flutter/data/radar/radar_frame_repository.dart';
import 'package:cwb_flutter/data/radar/radar_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

const _size = 8;
final _now = DateTime.utc(2026, 11, 14, 12, 55);
final _geometry = RadarImageGeometry(
  size: _size,
  bounds: LatLngBounds(const LatLng(24, 120), const LatLng(25, 121)),
  rowMap: List.generate(_size, (i) => i),
  decorations: const [],
);

/// 8x8 RGB frame: one echo pixel of 30 dBZ, the rest background.
final _png = img.encodePng(img.Image(width: _size, height: _size)
  ..setPixelRgb(3, 3, radarEchoPalette[30] >> 16, (radarEchoPalette[30] >> 8) & 0xFF, radarEchoPalette[30] & 0xFF));

RadarFrameRef _ref(Duration age) =>
    RadarFrameRef(time: _now.subtract(age), url: 'https://example.test/${radarStamp(_now.subtract(age))}.png', geometry: _geometry);

class _Source implements RadarSource {
  _Source(this.frames);

  final List<RadarFrameRef>? frames;

  @override
  String get id => 'test';

  @override
  Future<List<RadarFrameRef>> listFrames({required DateTime now, required int windowFrames}) async =>
      frames ?? (throw const RadarDataException('list', expected: 'JS body', actual: 'connection refused'));
}

/// Serves [_png] for every URL except [failing] (HTTP 500).
class _Adapter implements HttpClientAdapter {
  _Adapter({this.failing = const {}});

  final Set<String> failing;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      failing.contains(options.uri.toString())
          ? ResponseBody.fromString('boom', 500)
          : ResponseBody.fromBytes(_png, 200);

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('radar_repo_test'));
  tearDown(() => root.deleteSync(recursive: true));

  RadarFrameRepository repo({Set<String> failing = const {}, DateTime? now}) =>
      RadarFrameRepository(Dio()..httpClientAdapter = _Adapter(failing: failing),
          cacheRoot: () async => root, clock: () => now ?? _now);
  List<String> stamps(RadarLoop l) => [for (final f in l.frames) radarStamp(f.time)];
  Directory cacheDir() => Directory('${root.path}/$radarFrameCacheDirName/test');

  final window = [for (var i = 3; i >= 0; i--) _ref(Duration(minutes: 5 + 10 * i))]; // oldest first

  test('empty cache: newest frame emitted first, then one frame per event, final loop oldest first', () async {
    final events = await repo().watch(_Source(window), windowFrames: 4).toList();
    final all = [for (final f in window) f.stamp];
    expect(stamps(events.first), isEmpty, reason: 'cache emit before the list');
    expect(stamps(events[1]), [all.last], reason: 'newest frame first');
    final counts = [for (final e in events.skip(1)) e.frames.length];
    expect(counts, [1, 2, 3, 4, 4]);
    expect(stamps(events.last), all);
    expect((events.last.loading, events.last.windowSize), (false, 4));
    expect(events.last.frames.first.bounds, _geometry.bounds);
    expect(events.last.frames.first.stats.pixelsPerDbz[30], 1);
    expect(img.decodePng(events.last.frames.first.file.readAsBytesSync())!.getPixel(3, 3).a, 255);
  });

  test('list failure with a cache: cached frames plus the error, not an error state', () async {
    await repo().watch(_Source(window), windowFrames: 4).drain<void>();
    final events = await repo().watch(_Source(null), windowFrames: 4).toList();
    final all = [for (final f in window) f.stamp];
    expect(stamps(events.first), all, reason: 'cache shown before the list answers');
    expect(events.first.loading, isTrue);
    final last = events.last;
    expect(stamps(last), all);
    expect((last.loading, last.windowSize), (false, null));
    expect(last.listError, isA<RadarDataException>());
    expect('${last.listError}', contains('connection refused'));
  });

  test('a failing frame does not fail the window; the failure names the frame', () async {
    final bad = window[1];
    final last = await repo(failing: {bad.url}).watch(_Source(window), windowFrames: 4).last;
    expect(stamps(last), [for (final f in window) if (f != bad) f.stamp]);
    expect((last.loading, last.listError), (false, null));
    expect(last.failures.single.frame, bad);
    expect(last.failures.single.error, isA<DioException>());
  });

  test('24 h retention by the injected clock; frames outside the window but inside 24 h stay', () async {
    final old = _ref(const Duration(hours: 23));
    final outside = _ref(const Duration(hours: 5));
    final recent = _ref(const Duration(minutes: 5));
    await repo().watch(_Source([old, outside, recent]), windowFrames: 4).drain<void>();
    File('${cacheDir().path}/${recent.stamp}.png.tmp').writeAsStringSync('interrupted write');

    final later = _now.add(const Duration(hours: 2));
    final last = await repo(now: later).watch(_Source([recent]), windowFrames: 4).last;
    expect(stamps(last), [recent.stamp]);
    final files = [for (final e in cacheDir().listSync()) e.path.split('/').last]..sort();
    expect(files, [
      '${outside.stamp}.png',
      '${outside.stamp}.stats.gz',
      '${recent.stamp}.png',
      '${recent.stamp}.stats.gz',
    ]);
  });
}
