import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:petrichor/data/radar/radar_bounds.dart';
import 'package:petrichor/data/radar/radar_echo_stats.dart';import 'package:petrichor/data/radar/radar_frame_list.dart';
import 'package:petrichor/data/radar/radar_frame_processor.dart';
import 'package:petrichor/data/radar/radar_frame_repository.dart';
import 'package:petrichor/data/radar/radar_source.dart';
import 'package:petrichor/data/radar/radar_webp.dart';
import 'package:petrichor/features/radar/radar_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

import '../support/temporary_directory.dart';

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

RadarFrameRef _ref(Duration age) => RadarFrameRef(
    time: _now.subtract(age), url: 'https://example.test/${_now.subtract(age).microsecondsSinceEpoch}.png');

/// Cache file stem of a frame (observation time, UTC, to the second).
String _key(RadarFrameRef f) => f.time.toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);

const _listUrl = 'https://example.test/list.js';

/// Serves [_png] for every URL except [failing] (HTTP 500); records every URL.
class _Adapter implements HttpClientAdapter {
  _Adapter({this.failing = const {}});

  final Set<String> failing;
  final requested = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requested.add(options.uri.toString());
    return failing.contains(options.uri.toString())
        ? ResponseBody.fromString('boom', 500)
        : ResponseBody.fromBytes(_png, 200);
  }

  @override
  void close({bool force = false}) {}
}

/// Answers the list at once; every frame download waits for [release].
/// Records frame requests and the ones whose cancel signal fired.
class _GatedAdapter implements HttpClientAdapter {
  final release = Completer<void>();
  final firstFrameRequest = Completer<void>();
  final requested = <String>[];
  final cancelled = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final url = options.uri.toString();
    if (url == _listUrl) return ResponseBody.fromString('list', 200);
    requested.add(url);
    cancelFuture?.then((_) => cancelled.add(url));
    if (!firstFrameRequest.isCompleted) firstFrameRequest.complete();
    await release.future;
    return ResponseBody.fromBytes(_png, 200);
  }

  @override
  void close({bool force = false}) {}
}

/// Completes [reached] futures once [add] has been called that many times.
class _Count {
  var value = 0;
  final _waiting = <(int, Completer<void>)>[];

  void add() {
    value++;
    for (final w in [..._waiting]) {
      if (value < w.$1) continue;
      _waiting.remove(w);
      w.$2.complete();
    }
  }

  Future<void> reached(int n) {
    if (value >= n) return Future.value();
    final c = Completer<void>();
    _waiting.add((n, c));
    return c.future;
  }
}

/// Answers the list at once; holds each frame download until [release] (or
/// [releaseAll], after which downloads answer at once). Tracks open requests.
class _HeldAdapter implements HttpClientAdapter {
  final requested = <String>[];
  final arrivals = _Count();
  final _held = <String, Completer<void>>{};
  var _holding = true;
  var open = 0;
  var maxOpen = 0;

  void release(String url) => _held.remove(url)!.complete();

  void releaseAll() {
    _holding = false;
    for (final c in _held.values) {
      c.complete();
    }
    _held.clear();
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final url = options.uri.toString();
    if (url == _listUrl) return ResponseBody.fromString('list', 200);
    requested.add(url);
    maxOpen = max(maxOpen, ++open);
    arrivals.add();
    if (_holding) await (_held[url] = Completer<void>()).future;
    open--;
    return ResponseBody.fromBytes(_png, 200);
  }

  @override
  void close({bool force = false}) {}
}

/// A [RadarFrameProcess] (on this isolate) whose calls wait until released, in
/// call order by index or all at once. Tracks calls running at once.
class _HeldProcess {
  final arrivals = _Count();
  final _held = <Completer<void>>[];
  var _holding = true;
  var active = 0;
  var maxActive = 0;

  void release(int call) => _held[call].complete();

  void releaseAll() {
    _holding = false;
    for (final c in _held.where((c) => !c.isCompleted)) {
      c.complete();
    }
  }

  Future<ProcessedRadarFrame> call(Uint8List png, RadarImageGeometry geometry) async {
    maxActive = max(maxActive, ++active);
    final gate = Completer<void>();
    _held.add(gate);
    if (!_holding) gate.complete();
    arrivals.add();
    await gate.future;
    active--;
    return processRadarFrame(png, geometry);
  }
}

void main() {
  late Directory root;
  setUp(() => root = newTemporaryDirectory('radar_repo_test'));

  // Irregular cadence with seconds, like the station lists (~108 s apart), oldest first.
  final window = [for (final s in [2242, 1011, 497, 303]) _ref(Duration(seconds: s))];
  const span = Duration(minutes: 40);

  /// A source listing [frames] (any list body parses to them).
  RadarSource source(Dio dio, List<RadarFrameRef> frames, {Duration maxWindow = const Duration(hours: 24)}) =>
      RadarSource.website(dio, id: 'test', listUrl: _listUrl, maxWindow: maxWindow, parse: (_) => frames, geometry: _geometry);

  RadarFrameRepository repository(Dio dio, {DateTime? now, RadarFrameProcess process = radarProcessOffUiIsolate}) =>
      RadarFrameRepository(dio, cacheRoot: () async => root, clock: () => now ?? _now, process: process);

  /// One load of a source listing [frames] over [adapter].
  Stream<RadarLoop> load(List<RadarFrameRef> frames,
      {Set<String> failing = const {},
      DateTime? now,
      Duration window = span,
      Duration maxWindow = const Duration(hours: 24),
      _Adapter? adapter}) {
    final dio = Dio()..httpClientAdapter = adapter ?? _Adapter(failing: failing);
    return repository(dio, now: now).watch(source(dio, frames, maxWindow: maxWindow), window: window);
  }

  List<DateTime> stamps(RadarLoop l) => [for (final s in l.slots) ?s.frame?.time];
  List<RadarFrame> frames(RadarLoop l) => [for (final s in l.slots) ?s.frame];

  /// Slot states, oldest first: p(ending), r(eady), f(ailed).
  String states(RadarLoop l) => [for (final s in l.slots) s.state.name[0]].join();
  Directory cacheDir() => Directory('${root.path}/$radarFrameCacheDirName/test');
  List<String> cacheFiles() => [for (final e in cacheDir().listSync()) e.path.split('/').last]..sort();

  test('empty cache: a slot per listed time, newest ready first, then oldest first, one slot per event', () async {
    final events = await load(window).toList();
    final all = [for (final f in window) f.time];
    expect(events.first.slots, isEmpty, reason: 'cache emit before the list');
    expect([for (final e in events) states(e)], ['', 'pppp', 'pppr', 'rppr', 'rrpr', 'rrrr', 'rrrr']);
    expect([for (final s in events[1].slots) s.time], all, reason: 'slot times are the listed times, oldest first');
    expect([for (final e in events) e.loading], [true, true, true, true, true, true, false]);
    expect(stamps(events.last), all);
    expect(frames(events.last).first.bounds, _geometry.bounds);
    expect(frames(events.last).first.significantDbz, 30, reason: '1 px of an 8 px, 1° image is over the area rule');
    expect(frames(events.last).first.peakMm, isNull, reason: 'radar frames have no rain peak');
    final webp = frames(events.last).first.file.readAsBytesSync();
    expect(decodeRadarWebp(webp)[(3 * 8 + 3) * 4 + 3], 255);
  });

  test('list failure with a cache: cached frames plus the error, not an error state', () async {
    await load(window).drain<void>();
    final events = await load(window, failing: {_listUrl}).toList();
    final all = [for (final f in window) f.time];
    expect(stamps(events.first), all, reason: 'cache shown before the list answers');
    expect(events.first.loading, isTrue);
    final last = events.last;
    expect(stamps(last), all);
    expect(states(last), 'rrrr');
    expect(last.loading, isFalse);
    expect(last.listError, isA<RadarDataException>());
    expect('${last.listError}', allOf(contains(_listUrl), contains('HTTP 500')));
    expect(last.listError, isNot(isA<RadarStaleListException>()), reason: 'a failed request is not a stale list');
  });

  test('a list without recent frames is a stale list, told apart from a failed request', () async {
    await load(window).drain<void>();
    final last = await load(window, now: _now.add(const Duration(hours: 1))).last;
    expect(stamps(last), [for (final f in window) f.time]);
    expect(last.listError, isA<RadarStaleListException>());
  });

  test('a failing frame does not fail the window; its slot fails with an error naming the frame', () async {
    final bad = window[1];
    final last = await load(window, failing: {bad.url}).last;
    expect(states(last), 'rfrr');
    expect((last.loading, last.listError), (false, null));
    final failed = last.slots[1];
    expect((failed.time, failed.frame), (bad.time, null));
    expect('${failed.error}', allOf(contains(bad.url), contains('HTTP 500')));
  });

  test('retention = the source max window before the newest frame; outside the selected window stays', () async {
    const maxWindow = Duration(hours: 6);
    // Older than now - 6 h but inside the 6 h window ending at the newest listed frame.
    final edge = _ref(const Duration(hours: 6, minutes: 2));
    final outside = _ref(const Duration(hours: 3));
    final recent = _ref(const Duration(minutes: 5));
    await load([edge, outside, recent], window: maxWindow, maxWindow: maxWindow).drain<void>();

    final again = _Adapter();
    final full = await load([edge, outside, recent], window: maxWindow, maxWindow: maxWindow, adapter: again).last;
    expect(stamps(full), [edge.time, outside.time, recent.time]);
    expect(again.requested, [_listUrl], reason: 'a full window is not pruned and downloaded again');

    File('${cacheDir().path}/${_key(recent)}.webp.tmp').writeAsStringSync('interrupted write');
    final later = _now.add(const Duration(hours: 2));
    final newer = _ref(const Duration(minutes: -115));
    await load([newer], now: later, maxWindow: maxWindow).drain<void>();
    final last = await load([newer], now: later, maxWindow: maxWindow).last;
    expect(stamps(last), [newer.time]);
    expect(cacheFiles(), [
      for (final f in [outside, recent, newer]) ...['${_key(f)}.stats', '${_key(f)}.webp'],
    ]);
  });

  test('cancelling a load aborts its downloads; the next load shows the cache without waiting for them', () async {
    await load(window).drain<void>();
    final gated = _GatedAdapter();
    final dio = Dio()..httpClientAdapter = gated;
    final repo = repository(dio);
    final uncached = _ref(const Duration(seconds: 100));
    final first = repo.watch(source(dio, [...window, uncached]), window: span).listen(null);
    await gated.firstFrameRequest.future;
    await first.cancel();

    final events = await repo.watch(source(dio, window), window: const Duration(minutes: 30)).toList();
    final shown = [for (final f in window.skip(1)) f.time];
    expect(stamps(events.first), shown, reason: 'cached frames first');
    expect(stamps(events.last), shown);
    expect((events.last.loading, states(events.last)), (false, 'rrr'));
    expect(gated.requested, [uncached.url]);
    expect(gated.cancelled, [uncached.url], reason: 'the in-flight download was cancelled, not awaited');
    expect(gated.release.isCompleted, isFalse);
    expect(cacheFiles().where((f) => !f.endsWith('.webp') && !f.endsWith('.stats')), isEmpty);
  }, timeout: const Timeout(Duration(seconds: 2)));

  test('two overlapping loads: events in order, one load after the other, no partial files', () async {
    final gated = _GatedAdapter();
    final dio = Dio()..httpClientAdapter = gated;
    final repo = repository(dio);
    final log = <(String, RadarLoop)>[];
    Future<List<RadarLoop>> collect(String name, Stream<RadarLoop> s) =>
        s.map((l) => (log..add((name, l))).last.$2).toList();

    final first = collect('first', repo.watch(source(dio, window), window: span));
    await gated.firstFrameRequest.future;
    const short = Duration(minutes: 10);
    final second = collect('second', repo.watch(source(dio, window), window: short));
    gated.release.complete();
    final (a, b) = (await first, await second);

    expect([for (final (name, _) in log) name], [...List.filled(a.length, 'first'), ...List.filled(b.length, 'second')]);
    expect([for (final e in a) states(e)], ['', 'pppp', 'pppr', 'rppr', 'rrpr', 'rrrr', 'rrrr']);
    expect([for (final e in a) e.loading], [...List.filled(a.length - 1, true), false]);
    expect(stamps(a.last), [for (final f in window) f.time]);
    final recent = [for (final f in window) if (f.time.isAfter(_now.subtract(short))) f.time];
    expect([stamps(b.first), stamps(b.last)], [recent, recent]);
    expect(b.last.loading, isFalse);
    expect(gated.requested, unorderedEquals([for (final f in window) f.url]), reason: 'the second load reads the cache');
    expect(cacheFiles(), [for (final f in window) ...['${_key(f)}.stats', '${_key(f)}.webp']]);
  });

  test('a load of another cache family does not wait for a running load', () async {
    final gated = _GatedAdapter();
    final dio = Dio()..httpClientAdapter = gated;
    final repo = repository(dio);
    final radar = repo.watch(source(dio, window), window: span).listen(null);
    await gated.firstFrameRequest.future;
    final other = RadarSource(
        id: 'other',
        cachePath: 'other_family/other',
        maxWindow: const Duration(hours: 24),
        listFrames: ({required now, required window, cancelToken}) async => const [],
        step: RadarPngStep(_geometry));
    final first = await repo.watch(other, window: span).first;
    expect(first.loading, isTrue, reason: 'first event arrived while the radar load is still blocked');
    expect(gated.release.isCompleted, isFalse);
    await radar.cancel();
  }, timeout: const Timeout(Duration(seconds: 2)));

  test('schedule: newest first, then oldest first; 4 downloads, 2 processes; slots published in that order', () async {
    final listed = [for (var i = 9; i >= 0; i--) _ref(Duration(minutes: 5 + 10 * i))];
    final newest = listed.last;
    final adapter = _HeldAdapter();
    final proc = _HeldProcess();
    final dio = Dio()..httpClientAdapter = adapter;
    final done = repository(dio, process: proc.call).watch(source(dio, listed), window: const Duration(hours: 2)).toList();

    await adapter.arrivals.reached(1);
    expect(adapter.requested, [newest.url], reason: 'the newest frame alone first');
    adapter.release(newest.url);
    await proc.arrivals.reached(1);
    proc.release(0);

    await adapter.arrivals.reached(5);
    expect(adapter.requested, [newest.url, for (final f in listed.take(4)) f.url], reason: 'then oldest first');
    expect(adapter.open, 4);
    for (final f in listed.take(4)) {
      adapter.release(f.url);
    }
    await proc.arrivals.reached(3);
    await pumpEventQueue();
    expect((proc.active, proc.arrivals.value), (2, 3), reason: 'two process, the other two wait for a slot');
    expect(adapter.requested, hasLength(5), reason: 'a worker holding a body downloads no other');

    // The later of the two finishes first; its slot must wait for the older one.
    proc.release(2);
    await pumpEventQueue();
    proc.release(1);
    proc.releaseAll();
    adapter.releaseAll();
    final events = await done;

    expect(adapter.requested, [newest.url, for (final f in listed.take(9)) f.url]);
    expect((adapter.maxOpen, proc.maxActive), (4, 2));
    final slotEvents = events.skip(1).toList();
    for (final e in slotEvents) {
      expect([for (final s in e.slots) s.time], [for (final f in listed) f.time]);
    }
    final changed = [
      for (var i = 1; i < slotEvents.length; i++)
        for (var s = 0; s < listed.length; s++)
          if (slotEvents[i].slots[s].state != slotEvents[i - 1].slots[s].state) s,
    ];
    expect(changed, [9, 0, 1, 2, 3, 4, 5, 6, 7, 8], reason: 'one slot per event: newest, then oldest first');
    expect(states(events.last), 'r' * 10);
  });

  test('a composed step makes its frames itself, in the processing slots, into its own cache path', () async {
    final adapter = _Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final obtained = <String>[];
    final listed = window;
    final composed = RadarSource(
      id: 'composed',
      cachePath: 'composed_v1/3h',
      maxWindow: const Duration(hours: 3),
      listFrames: ({required now, required window, cancelToken}) async => listed,
      step: RadarComposedStep((frame, cancel, processSlot) {
        obtained.add(frame.url);
        return processSlot(() async => processRadarFrame(_png, _geometry));
      }),
    );
    final events = await repository(dio).watch(composed, window: span).toList();

    expect(states(events.last), 'rrrr');
    expect(obtained, [window.last.url, for (final f in window.take(3)) f.url]);
    expect(adapter.requested, isEmpty, reason: 'nothing downloaded by the repository');
    expect([for (final e in Directory('${root.path}/composed_v1/3h').listSync()) e.path.split('/').last]..sort(),
        [for (final f in window) ...['${_key(f)}.stats', '${_key(f)}.webp']]);
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
