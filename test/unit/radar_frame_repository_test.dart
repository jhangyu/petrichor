import 'dart:io';
import 'dart:typed_data';

import 'package:cwb_flutter/data/radar/radar_bounds.dart';
import 'package:cwb_flutter/data/radar/radar_frame_list.dart';
import 'package:cwb_flutter/data/radar/radar_frame_processor.dart';
import 'package:cwb_flutter/data/radar/radar_frame_repository.dart';
import 'package:cwb_flutter/data/radar/radar_source.dart';
import 'package:cwb_flutter/features/radar/radar_provider.dart';
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
  palette: radarEchoPalette,
);

/// 8x8 RGB frame: one echo pixel of 30 dBZ, the rest background.
final _png = img.encodePng(img.Image(width: _size, height: _size)
  ..setPixelRgb(3, 3, radarEchoPalette[30] >> 16, (radarEchoPalette[30] >> 8) & 0xFF, radarEchoPalette[30] & 0xFF));

RadarFrameRef _ref(Duration age) => RadarFrameRef(
    time: _now.subtract(age), url: 'https://example.test/${_now.subtract(age).microsecondsSinceEpoch}.png', geometry: _geometry);

/// Cache file stem of a frame (observation time, UTC, to the second).
String _key(RadarFrameRef f) => f.time.toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);

const _listUrl = 'https://example.test/list.js';

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

  // Irregular cadence with seconds, like the station lists (~108 s apart), oldest first.
  final window = [for (final s in [2242, 1011, 497, 303]) _ref(Duration(seconds: s))];
  const span = Duration(minutes: 40);

  /// One load of a source listing [frames] (any list body parses to them).
  Stream<RadarLoop> load(List<RadarFrameRef> frames,
      {Set<String> failing = const {}, DateTime? now, Duration window = span}) {
    final dio = Dio()..httpClientAdapter = _Adapter(failing: failing);
    final source = RadarSource(dio, id: 'test', listUrl: _listUrl, maxWindow: const Duration(hours: 24), parse: (_) => frames);
    return RadarFrameRepository(dio, cacheRoot: () async => root, clock: () => now ?? _now).watch(source, window: window);
  }

  List<DateTime> stamps(RadarLoop l) => [for (final f in l.frames) f.time];
  Directory cacheDir() => Directory('${root.path}/$radarFrameCacheDirName/test');

  test('empty cache: newest frame emitted first, then one frame per event, final loop oldest first', () async {
    final events = await load(window).toList();
    final all = [for (final f in window) f.time];
    expect(stamps(events.first), isEmpty, reason: 'cache emit before the list');
    expect(stamps(events[1]), [all.last], reason: 'newest frame first');
    final counts = [for (final e in events.skip(1)) e.frames.length];
    expect(counts, [1, 2, 3, 4, 4]);
    expect(stamps(events.last), all);
    expect((events.last.loading, events.last.windowSize), (false, 4));
    expect(events.last.frames.first.bounds, _geometry.bounds);
    expect(events.last.newestStats!.pixelsPerDbz[30], 1);
    expect(events.last.frames.first.significantDbz, 30, reason: '1 px of an 8 px, 1° image is over the area rule');
    expect(img.decodePng(events.last.frames.first.file.readAsBytesSync())!.getPixel(3, 3).a, 255);
  });

  test('list failure with a cache: cached frames plus the error, not an error state', () async {
    await load(window).drain<void>();
    final events = await load(window, failing: {_listUrl}).toList();
    final all = [for (final f in window) f.time];
    expect(stamps(events.first), all, reason: 'cache shown before the list answers');
    expect(events.first.loading, isTrue);
    final last = events.last;
    expect(stamps(last), all);
    expect((last.loading, last.windowSize), (false, null));
    expect(last.listError, isA<RadarDataException>());
    expect('${last.listError}', allOf(contains(_listUrl), contains('HTTP 500')));
  });

  test('a failing frame does not fail the window; the failure names the frame', () async {
    final bad = window[1];
    final last = await load(window, failing: {bad.url}).last;
    expect(stamps(last), [for (final f in window) if (f != bad) f.time]);
    expect((last.loading, last.listError), (false, null));
    expect(last.failures.single.frame, bad);
    expect(last.failures.single.error, isA<DioException>());
  });

  test('24 h retention by the injected clock; frames outside the window but inside 24 h stay', () async {
    final old = _ref(const Duration(hours: 23));
    final outside = _ref(const Duration(hours: 5));
    final recent = _ref(const Duration(minutes: 5));
    await load([old, outside, recent], window: const Duration(hours: 24)).drain<void>();
    File('${cacheDir().path}/${_key(recent)}.png.tmp').writeAsStringSync('interrupted write');

    final later = _now.add(const Duration(hours: 2));
    final last = await load([recent], now: later).last;
    expect(stamps(last), [recent.time]);
    final files = [for (final e in cacheDir().listSync()) e.path.split('/').last]..sort();
    expect(files, [
      '${_key(outside)}.png',
      '${_key(outside)}.stats.gz',
      '${_key(recent)}.png',
      '${_key(recent)}.stats.gz',
    ]);
  });

  test('per-source window limits: composite up to 24 h, stations up to 6 h', () {
    final dio = Dio()..httpClientAdapter = _Adapter();
    final composite = RadarSource.composite(dio);
    final station = RadarSource.station(dio, radarStations.first);
    expect((composite.maxWindow, station.maxWindow), (const Duration(hours: 24), const Duration(hours: 6)));
    final repository = RadarFrameRepository(dio, cacheRoot: () async => root, clock: () => _now);
    expect(() => repository.watch(station, window: const Duration(hours: 7)), throwsRangeError);
    expect(() => repository.watch(composite, window: const Duration(hours: 25)), throwsRangeError);
    expect(radarEffectiveWindow(const Duration(hours: 24), station), const Duration(hours: 6));
    expect(radarEffectiveWindow(const Duration(hours: 24), composite), const Duration(hours: 24));
    expect(radarEffectiveWindow(const Duration(hours: 2), station), const Duration(hours: 2));
  });
}
