import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cwb_flutter/core/theme/app_tokens.dart';
import 'package:cwb_flutter/data/radar/radar_frame_list.dart';
import 'package:cwb_flutter/data/radar/radar_frame_processor.dart';
import 'package:cwb_flutter/data/radar/radar_frame_repository.dart';
import 'package:cwb_flutter/data/radar/radar_source.dart';
import 'package:cwb_flutter/data/radar/radar_webp.dart';
import 'package:cwb_flutter/data/rain_accum/accum_grid.dart';
import 'package:cwb_flutter/data/rain_accum/accum_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// now − 6 min = 10:54Z: newest grid slot 10:50; last aligned frame 10:50
/// (10-min), 10:00 (1 h), 09:00 (3 h).
final _now = DateTime.utc(2026, 11, 15, 11);

/// Serves [bodies] by file name (default: a 1-byte body), 404 for [missing],
/// 304 when the request's If-None-Match equals [etag]; records every request.
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
    return ResponseBody.fromBytes(bodies[name] ?? Uint8List(1), 200, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

class _Skipped implements Exception {}

Future<ProcessedRadarFrame> _skip(Future<ProcessedRadarFrame> Function() work) async => throw _Skipped();

Uint8List _fixture(String name) => File('test/fixtures/rain_accum/$name.dat.gz').readAsBytesSync();

void main() {
  late Directory root;
  late _Adapter adapter;
  setUp(() {
    root = Directory.systemTemp.createTempSync('accum_source_test');
    adapter = _Adapter();
  });
  tearDown(() => root.deleteSync(recursive: true));

  RadarSource source(int w) => accumRadarSource(Dio()..httpClientAdapter = adapter,
      windowHours: w, cacheRoot: () async => root, clock: () => _now);

  Future<List<RadarFrameRef>> list(RadarSource s) => s.listFrames(now: _now, window: s.maxWindow);

  test('frame list per window: aligned frames, then the newest 10-min slot when newer', () async {
    const expected = {
      4: (24, Duration(minutes: 10), '10:50'),
      6: (36, Duration(minutes: 10), '10:50'),
      12: (72, Duration(minutes: 10), '10:50'),
      24: (24, Duration(hours: 1), '10:00'),
      48: (48, Duration(hours: 1), '10:00'),
      168: (56, Duration(hours: 3), '09:00'),
    };
    for (final MapEntry(key: w, value: (count, step, lastAligned)) in expected.entries) {
      final s = source(w);
      expect(s.cachePath, 'rain_accum_frames_v2/${w}h');
      final frames = await list(s);
      expect(frames.last.time, DateTime.utc(2026, 11, 15, 10, 50), reason: '$w h: newest slot is last');
      final aligned = step == accumGridInterval ? frames : frames.sublist(0, frames.length - 1);
      expect(aligned.length, count, reason: '$w h');
      expect(aligned.last.time.toIso8601String(), contains('T$lastAligned'), reason: '$w h');
      for (final (i, f) in aligned.indexed) {
        expect(f.time.microsecondsSinceEpoch % step.inMicroseconds, 0, reason: '$w h frame $i');
        if (i > 0) expect(f.time.difference(aligned[i - 1].time), step, reason: '$w h frame $i');
      }
    }
  });

  test('newest slot equal to the last aligned frame is not appended', () async {
    final s = accumRadarSource(Dio()..httpClientAdapter = adapter,
        windowHours: 24, cacheRoot: () async => root, clock: () => _now);
    // now − 6 min = 11:00Z: the newest slot is the aligned 11:00 frame.
    final frames = await s.listFrames(now: _now.add(const Duration(minutes: 6)), window: s.maxWindow);
    expect(frames.length, 24);
    expect(frames.last.time, DateTime.utc(2026, 11, 15, 11));
  });

  test('unique piece downloads: aligned frames plus the newest slot (+1 for 24 h, +2 for 48 h, +7 for 168 h)', () async {
    for (final (w, unique) in [(24, 24 + 1), (48, 72 + 2), (168, 104 + 7)]) {
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
      expect(urls.toSet().length, unique, reason: '$w h');
      expect(urls.length, unique, reason: '$w h: each grid downloaded once');
    }
  });

  test('offset-0 grid missing: newest steps back one slot', () async {
    adapter.missing.add('GAGE_PCP_3H.20261115.1050.dat');
    final frames = await list(source(4));
    expect(frames.last.time, DateTime.utc(2026, 11, 15, 10, 40));
    expect(frames.length, 24);
  });

  test('composed 4 h frame equals the coloured sum of 4 x 1 h', () async {
    adapter.bodies['GAGE_PCP_3H.20261115.1050.dat'] = gzip.decode(_fixture('g03_20261115_1050')) as Uint8List;
    adapter.bodies['GAGE_PCP_1H.20261115.0750.dat'] = gzip.decode(_fixture('g01_20261115_0750')) as Uint8List;
    final s = source(4);
    final frame = (await list(s)).last;
    final processed = await (s.step as RadarComposedStep).obtain(frame, CancelToken(), (work) => work());
    AccumGrid load(String n) => parseAccumGrid(String.fromCharCodes(gzip.decode(_fixture(n))), url: n);
    final sum = sumAccumGrids([for (final h in ['1050', '0950', '0850', '0750']) load('g01_20261115_$h')]);
    final rowMap = mercatorRowMap(srcHeight: accumGridHeight, south: 20, north: 27);
    final pixels = decodeRadarWebp(processed.webp);
    expect(radarWebpSize(processed.webp), (width: accumGridWidth, height: rowMap.length));
    var coloured = 0;
    for (var j = 0; j < rowMap.length; j++) {
      final src = (accumGridHeight - 1 - rowMap[j]) * accumGridWidth;
      for (var x = 0; x < accumGridWidth; x++) {
        final index = accumColorIndex(sum[src + x]);
        final o = (j * accumGridWidth + x) * 4;
        final argb = (pixels[o + 3] << 24) | (pixels[o] << 16) | (pixels[o + 1] << 8) | pixels[o + 2];
        final want = index < 0 ? 0 : AppPalette.rainfallMapScale[index].toARGB32();
        if (argb != want) fail('row $j col $x: expected ${want.toRadixString(16)}, got ${argb.toRadixString(16)}');
        if (index >= 0) coloured++;
      }
    }
    expect(coloured, greaterThan(0));
    expect(processed.stats.frame, accumBounds);
    expect(processed.stats.peakMm, sum.reduce(max) / accumRawPerMm);
    expect(processed.stats.peakMm, greaterThan(1));
  });

  group('cached frame and a revalidated offset-0 grid', () {
    // One 10-min frame of the 4 h window: 3H@10:50 (young, revalidated) + 1H@07:50.
    late Uint8List g03, g01;
    setUp(() {
      g03 = gzip.decode(_fixture('g03_20261115_1050')) as Uint8List;
      g01 = gzip.decode(_fixture('g01_20261115_0750')) as Uint8List;
      adapter.bodies['GAGE_PCP_3H.20261115.1050.dat'] = g03;
      adapter.bodies['GAGE_PCP_1H.20261115.0750.dat'] = g01;
      adapter.etag = '"v1"';
    });

    Future<RadarFrame> load() async {
      final repo = RadarFrameRepository(Dio(), cacheRoot: () async => root, clock: () => _now);
      final loop = await repo.watch(source(4), window: accumGridInterval).last;
      expect(loop.slots.single.state, RadarSlotState.ready, reason: '${loop.slots.single}');
      return loop.slots.single.frame!;
    }

    test('304: the cached frame is kept', () async {
      final first = await load();
      // A re-render would now fail: the 1 h grid is gone from disk and server.
      for (final f in Directory('${root.path}/$accumPieceCacheDirName/01h').listSync()) {
        f.deleteSync();
      }
      adapter.missing.add('GAGE_PCP_1H.20261115.0750.dat');
      final second = await load();
      expect(second.peakMm, first.peakMm);
    });

    test('200: the dependent frame is made again from the new grid', () async {
      final first = await load();
      // The grid changes: new ETag and a body with a different peak.
      adapter.etag = '"v2"';
      adapter.bodies['GAGE_PCP_3H.20261115.1050.dat'] = g01;
      final second = await load();
      expect(second.peakMm, isNot(first.peakMm));
    });
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
