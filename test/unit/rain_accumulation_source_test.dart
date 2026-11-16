import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:petrichor/core/theme/app_tokens.dart';
import 'package:petrichor/data/radar/radar_frame_list.dart';
import 'package:petrichor/data/radar/radar_frame_processor.dart';
import 'package:petrichor/data/radar/radar_frame_repository.dart';
import 'package:petrichor/data/radar/radar_source.dart';
import 'package:petrichor/data/radar/radar_webp.dart';
import 'package:petrichor/data/rain_accum/accum_grid.dart';
import 'package:petrichor/data/rain_accum/accum_pieces.dart';
import 'package:petrichor/data/rain_accum/accum_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/temporary_directory.dart';

/// now − 6 min = 10:54Z: newest grid slot 10:50.
final _now = DateTime.utc(2026, 11, 15, 11);
final _newest = DateTime.utc(2026, 11, 15, 10, 50);

/// A valid all-zero QPEplus grid.
final _zeroGrid = Uint8List.fromList('441,561,c,118.00,20.00,123.50,27.00,int16,0,0,EPSG:4326\n'
        'linearTransform(0.2500,0.0000)\n\nndv:0\ncolIdx:\nrowPtr:${List.filled(562, 0).join(',')}\nvals:\n'
    .codeUnits);

/// Serves [bodies] by file name (default: an all-zero grid), 404 for
/// [missing], 304 when the request's If-None-Match equals [etag]; records
/// every request.
class _Adapter implements HttpClientAdapter {
  final bodies = <String, Uint8List>{};
  final missing = <String>{};
  String? etag;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final name = options.uri.pathSegments.last;
    if (missing.contains(name)) return ResponseBody.fromString('', 404);
    final headers = {if (etag != null) HttpHeaders.etagHeader: [etag!]};
    if (etag != null && options.headers[HttpHeaders.ifNoneMatchHeader] == etag) {
      return ResponseBody.fromBytes(const [], 304, headers: headers);
    }
    return ResponseBody.fromBytes(bodies[name] ?? _zeroGrid, 200, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

class _Skipped implements Exception {}

Future<ProcessedRadarFrame> _skip(Future<ProcessedRadarFrame> Function() work) async => throw _Skipped();

Uint8List _body(String fixture) =>
    gzip.decode(File('test/fixtures/rain_accumulation/$fixture.dat.gz').readAsBytesSync()) as Uint8List;

AccumGrid _grid(String fixture) => parseAccumGrid(String.fromCharCodes(_body(fixture)), url: fixture);

String _name(int hours, DateTime t) => Uri.parse(accumPieceUrl(hours, t)).pathSegments.last;

void main() {
  late Directory root;
  late _Adapter adapter;
  setUp(() {
    root = newTemporaryDirectory('accum_source_test');
    adapter = _Adapter();
  });

  RadarSource source(int w) => accumRadarSource(Dio()..httpClientAdapter = adapter,
      windowHours: w, cacheRoot: () async => root, clock: () => _now);

  Future<List<RadarFrameReference>> list(RadarSource s) => s.listFrames(now: _now, window: s.maxWindow);

  Future<ProcessedRadarFrame> render(RadarSource s, RadarFrameReference f) =>
      (s.step as RadarComposedStep).obtain(f, CancelToken(), (work) => work());

  /// Peak and colour of every pixel of [processed] match the raw total [sum].
  void expectFrame(ProcessedRadarFrame processed, Int32List sum) {
    final rowMap = mercatorRowMap(sourceHeight: accumGridHeight, south: 20, north: 27);
    final pixels = decodeRadarWebp(processed.webp);
    expect(radarWebpSize(processed.webp), (width: accumGridWidth, height: rowMap.length));
    var coloured = 0;
    for (var j = 0; j < rowMap.length; j++) {
      final source = (accumGridHeight - 1 - rowMap[j]) * accumGridWidth;
      for (var x = 0; x < accumGridWidth; x++) {
        final index = accumColorIndex(sum[source + x]);
        final o = (j * accumGridWidth + x) * 4;
        final argb = (pixels[o + 3] << 24) | (pixels[o] << 16) | (pixels[o + 1] << 8) | pixels[o + 2];
        final want = index < 0 ? 0 : AppPalette.rainfallMapScale[index].toARGB32();
        if (argb != want) fail('row $j col $x: expected ${want.toRadixString(16)}, got ${argb.toRadixString(16)}');
        if (index >= 0) coloured++;
      }
    }
    expect(coloured, greaterThan(0));
    expect(processed.statistics.bounds, accumBounds);
    expect(processed.statistics.peakMm, sum.reduce(max) / accumRawPerMm);
  }

  test('frame list per window: S = newest - W, frames S + step*k for k = 1..N, last = newest', () async {
    const expected = {
      4: (24, Duration(minutes: 10)),
      6: (36, Duration(minutes: 10)),
      12: (72, Duration(minutes: 10)),
      24: (24, Duration(hours: 1)),
      48: (48, Duration(hours: 1)),
      168: (56, Duration(hours: 3)),
    };
    for (final MapEntry(key: w, value: (count, step)) in expected.entries) {
      final s = source(w);
      expect(s.cachePath, 'rain_accum_frames_v3/${w}h');
      final start = _newest.subtract(Duration(hours: w));
      expect(accumWindowStart(_newest, w), start);
      final frames = await list(s);
      expect(frames.length, count, reason: '$w h');
      for (final (i, f) in frames.indexed) {
        expect(f.time, start.add(step * (i + 1)), reason: '$w h frame $i');
        expect((f as AccumFrameRef).start, start, reason: '$w h frame $i');
      }
      expect(frames.last.time, _newest, reason: '$w h');
    }
  });

  test('newest grid missing: newest steps back one slot', () async {
    adapter.missing.add('GAGE_PCP_3H.20261115.1050.dat');
    final frames = await list(source(168));
    expect(frames.last.time, DateTime.utc(2026, 11, 15, 10, 40));
    expect((frames.last as AccumFrameRef).start, DateTime.utc(2026, 11, 8, 10, 40));
    expect(frames.length, 56);
  });

  test('frame plans: cumulative 1 h / 3 h grids, and a partial first hour for 10-min frames', () {
    final s = DateTime.utc(2026, 11, 15, 6, 50);
    String show(int w, Duration into) {
      final p = accumFramePlan(start: s, time: s.add(into), windowHours: w);
      String hm(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
      return '${p.nativeHours}h ${p.partialEnd == null ? '-' : hm(p.partialEnd!)} ${p.ends.map(hm).join(',')}';
    }

    expect(show(24, const Duration(hours: 1)), '1h - 7:50');
    expect(show(24, const Duration(hours: 3)), '1h - 7:50,8:50,9:50');
    expect(show(168, const Duration(hours: 6)), '3h - 9:50,12:50');
    expect(show(4, const Duration(minutes: 10)), '1h 7:00 ');
    expect(show(4, const Duration(minutes: 60)), '1h - 7:50');
    expect(show(4, const Duration(hours: 2, minutes: 30)), '1h 7:20 8:20,9:20');
    expect(show(4, const Duration(hours: 4)), '1h - 7:50,8:50,9:50,10:50');
  });

  test('unique grid downloads per window, each downloaded once', () async {
    final counts = <int, int>{};
    for (final w in [4, 6, 12, 24, 48, 168]) {
      // Cold cache per window (windows share the piece cache).
      for (final e in root.listSync()) {
        e.deleteSync(recursive: true);
      }
      adapter.requests.clear();
      final s = source(w);
      final step = s.step as RadarComposedStep;
      for (final f in await list(s)) {
        await expectLater(step.obtain(f, CancelToken(), _skip), throwsA(isA<_Skipped>()));
      }
      final urls = [for (final r in adapter.requests) r.uri.toString()];
      expect(urls.length, urls.toSet().length, reason: '$w h: each grid downloaded once');
      counts[w] = urls.length;
    }
    // 10-min windows: every 1 h grid ending at S + 10i min (i = 0..6W);
    // 24/48 h: W 1 h grids; 168 h: 56 3 h grids.
    expect(counts, {4: 25, 6: 37, 12: 73, 24: 24, 48: 48, 168: 56});
  });

  test('last 4 h frame is the exact sum of four 1 h grids', () async {
    for (final h in ['1050', '0950', '0850', '0750']) {
      adapter.bodies['GAGE_PCP_1H.20261115.$h.dat'] = _body('g01_20261115_$h');
    }
    final s = source(4);
    final frame = (await list(s)).last;
    expect(frame.time, _newest);
    final processed = await render(s, frame);
    expectFrame(processed, accumFrameSum([for (final h in ['1050', '0950', '0850', '0750']) _grid('g01_20261115_$h')]));
    expect(processed.statistics.peakMm, greaterThan(1));
  });

  test('first 24 h frame is the 1 h grid ending at S + 1 h', () async {
    final s = source(24);
    final first = (await list(s)).first;
    expect(first.time, DateTime.utc(2026, 11, 14, 11, 50));
    adapter.bodies[_name(1, first.time)] = _body('g01_20261115_0950');
    expectFrame(await render(s, first), Int32List.fromList(_grid('g01_20261115_0950').raw));
  });

  test('sub-hour 4 h frame: R1(S+20m) - R1(S)*40/60 clamped at 0, plus the next 1 h grid', () async {
    final s = source(4);
    final frames = await list(s);
    final start = (frames.first as AccumFrameRef).start;
    expect(start, DateTime.utc(2026, 11, 15, 6, 50));
    // Frame S + 1 h 20 min = 08:10: C(07:10) + R1(08:10).
    final frame = frames.firstWhere((f) => f.time == DateTime.utc(2026, 11, 15, 8, 10));
    final end = _grid('g01_20261115_1050'), base = _grid('g01_20261115_0950'), next = _grid('g01_20261115_0850');
    adapter.bodies[_name(1, DateTime.utc(2026, 11, 15, 7, 10))] = _body('g01_20261115_1050');
    adapter.bodies[_name(1, start)] = _body('g01_20261115_0950');
    adapter.bodies[_name(1, frame.time)] = _body('g01_20261115_0850');
    final want = Int32List(accumGridWidth * accumGridHeight);
    var clamped = 0;
    for (var i = 0; i < want.length; i++) {
      final estimate = end.raw[i] - (base.raw[i] * 40 / 60).round();
      if (estimate < 0 && base.raw[i] > 0) clamped++;
      want[i] = max(0, estimate) + next.raw[i];
    }
    expect(clamped, greaterThan(0), reason: 'the fixtures have negative estimates');
    expectFrame(await render(s, frame), want);
  });

  group('cached newest 4 h frame', () {
    setUp(() {
      for (final h in ['1050', '0950', '0850', '0750']) {
        adapter.bodies[_name(1, DateTime.utc(2026, 11, 15, int.parse(h.substring(0, 2)), 50))] =
            _body('g01_20261115_$h');
      }
      adapter.etag = '"v1"';
    });

    Future<RadarFrame> load({DateTime? now}) async {
      final repository = RadarFrameRepository(Dio(), cacheRoot: () async => root, clock: () => now ?? _now);
      final loop = await repository.watch(source(4), window: accumGridInterval).last;
      expect(loop.slots.single.state, RadarSlotState.ready, reason: '${loop.slots.single}');
      return loop.slots.single.frame!;
    }

    test('304: the cached frame is kept', () async {
      final first = await load();
      // A re-render would now fail: the 07:50 grid is gone from disk and server.
      File('${root.path}/$accumPieceCacheDirName/01h/202611150750.dat.gz').deleteSync();
      adapter.missing.add('GAGE_PCP_1H.20261115.0750.dat');
      final second = await load();
      expect(second.peakMm, first.peakMm);
    });

    test('200: the frame is made again from the new newest grid', () async {
      final first = await load();
      adapter.etag = '"v2"';
      adapter.bodies['GAGE_PCP_1H.20261115.1050.dat'] = _body('g03_20261115_1050');
      final second = await load();
      expect(second.peakMm, isNot(first.peakMm));
    });
  });

  Future<RadarLoop> watch(RadarSource s, DateTime now, Duration window) =>
      RadarFrameRepository(Dio(), cacheRoot: () async => root, clock: () => now).watch(s, window: window).last;

  test('another S: a cached frame at the same time is made again', () async {
    final s = source(24);
    const window = Duration(hours: 2);
    // S 11-14 10:50: 10:50 sums 1 h grids from 11-14 11:50 (rain) to 10:50.
    adapter.bodies[_name(1, DateTime.utc(2026, 11, 14, 11, 50))] = _body('g01_20261115_1050');
    final first = await watch(s, _now, window);
    expect([for (final x in first.slots) x.time], [DateTime.utc(2026, 11, 15, 9, 50), _newest]);
    expect(first.slots.last.frame!.peakMm, greaterThan(1));
    // An hour later S is 11-14 11:50: 10:50 no longer has that grid.
    final second = await watch(s, _now.add(const Duration(hours: 1)), window);
    expect([for (final x in second.slots) x.time], [_newest, DateTime.utc(2026, 11, 15, 11, 50)]);
    expect(second.slots.first.frame!.peakMm, 0);
  });

  test('S moved by 10 min: frames of the old S leave the cache-first view', () async {
    final s = source(24);
    const window = Duration(hours: 2);
    await watch(s, _now, window);
    await watch(s, _now.add(accumGridInterval), window);
    final cached = [for (final f in Directory('${root.path}/${s.cachePath}').listSync()) f.uri.pathSegments.last]..sort();
    expect(cached, ['20261115100000.stats', '20261115100000.webp', '20261115110000.stats', '20261115110000.webp']);
  });

  test('young cached grid is revalidated by ETag; 304 keeps it', () async {
    adapter.etag = '"v1"';
    final s = source(4);
    await list(s);
    adapter.requests.clear();
    await list(s);
    expect(adapter.requests.single.headers[HttpHeaders.ifNoneMatchHeader], '"v1"');
  });
}
