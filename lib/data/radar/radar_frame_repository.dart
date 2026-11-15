import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pool/pool.dart';

import '../../features/radar/widgets/radar_webp_image.dart';
import 'radar_echo_stats.dart';
import 'radar_frame_list.dart';
import 'radar_frame_processor.dart';
import 'radar_loop.dart';
import 'radar_source.dart';
import 'radar_webp.dart';

export 'radar_loop.dart';

/// Cache sub-directory (one sub-directory per source); the suffix changes
/// whenever processing output changes, so frames made by an older pipeline are
/// never shown.
const radarFrameCacheDirName = 'radar_webp_2048_v2';

/// Cache directories of earlier pipelines (each was [radarFrameCacheDirName]
/// once); deleted by [deleteLegacyRadarCaches]. Never contains the current name.
const radarLegacyCacheDirNames = [
  'radar_cv1_3600_webp_v1',
  'radar_cv1_3600_webp_v2',
  'radar_cv1_3600_webp_v3',
  'radar_cv1_3600_webp_v4',
  'radar_indexed_png_v1',
  'radar_indexed_png_2048_v1',
  'radar_webp_2048_v1',
];

/// Deletes the [radarLegacyCacheDirNames] directories under [root]; anything
/// else is kept. A failed delete is rethrown naming the directory.
Future<void> deleteLegacyRadarCaches(Directory root) async {
  for (final name in radarLegacyCacheDirNames) {
    final dir = Directory('${root.path}/$name');
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException catch (e) {
      throw FileSystemException('radar cache cleanup: expected ${dir.path} deleted, got ${e.message}', dir.path, e.osError);
    }
  }
}

/// Frames processed at once (one isolate each). Measured on the Mac
/// (docs/logs/2026-11-15/radar-perf-handover.md §9): 2 workers are 2.1x
/// faster than 1 for ~+100 MB RSS; 4 workers cost +410 MB RSS (rejected).
const radarProcessWorkers = 2;

/// Frames downloaded at once. Each download worker holds at most one body, so
/// at most `radarFetchWorkers - radarProcessWorkers` = 2 downloaded bodies
/// (~0.7 MB composite, ~1.1 MB station each) wait for a processing slot.
const radarFetchWorkers = 4;

/// Turns a downloaded frame into the cached frame; [radarProcessOffUiIsolate]
/// except in tests.
typedef RadarFrameProcess = Future<ProcessedRadarFrame> Function(Uint8List png, RadarImageGeometry geometry);

/// Cache files per frame: `<key>.webp` (lossless WebP) and `<key>.stats`
/// ([RadarEchoStats.toBytes]); key = observation time `yyyyMMddHHmmss` UTC
/// (station frames have irregular seconds).
final _cacheFilePattern = RegExp(r'^(\d{14})\.(webp|stats)$');

String _cacheKey(DateTime t) {
  final u = t.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}${two(u.hour)}${two(u.minute)}${two(u.second)}';
}

DateTime _cacheKeyTime(String k) => DateTime.utc(int.parse(k.substring(0, 4)), int.parse(k.substring(4, 6)),
    int.parse(k.substring(6, 8)), int.parse(k.substring(8, 10)), int.parse(k.substring(10, 12)), int.parse(k.substring(12, 14)));

/// One processed, cached frame: transparent lossless WebP with rows linear in
/// Web Mercator, shown as one `OverlayImage` over [bounds]. Of the echo
/// statistics only the strongest echo is kept.
class RadarFrame {
  final DateTime time;
  final File file;
  final LatLngBounds bounds;

  /// [RadarEchoStats.strongestDbz] when the frame has significant echo, else null.
  final int? significantDbz;

  /// Pixel size of [file] (website frames: 2048 x 2132 Mercator rows).
  final int width;
  final int height;

  const RadarFrame({
    required this.time,
    required this.file,
    required this.bounds,
    required this.significantDbz,
    required this.width,
    required this.height,
  });

  /// Height / width of the decoded image.
  double get aspect => height / width;

  /// Decoded at the stored size (~17 MB for a website frame); the map and its
  /// pre-decode share this provider's cache entry.
  ImageProvider get imageProvider => RadarWebpImage(file);
}

/// Loads a source's frames: cached frames first, then the frame list, then
/// the missing frames: the newest alone first (it is the one shown), then the
/// rest oldest first (playback order). Up to [radarFetchWorkers] downloads run
/// at once, processing (off the UI isolate) is limited to [radarProcessWorkers],
/// and slots are published strictly in that order, one event per slot. Keeps
/// [RadarSource.maxWindow] of frames on disk per source, so changing the
/// window never deletes or reprocesses frames.
class RadarFrameRepository {
  final Dio _dio;
  final Future<Directory> Function() cacheRoot;
  final DateTime Function() clock;
  final RadarFrameProcess process;

  /// Shared by all loads so the processing bound holds across back-to-back loads.
  final _processPool = Pool(radarProcessWorkers);

  /// Old cache directories are deleted once, by the first load.
  bool _legacyCachesDeleted = false;

  /// The last started load. Loads run one after another (cache files and the
  /// processing memory bound are shared); cancelling a load aborts its HTTP
  /// requests and drops its frames still in processing, so the next load
  /// starts at once.
  Future<void> _lastLoad = Future.value();

  RadarFrameRepository(this._dio,
      {required this.cacheRoot, required this.clock, this.process = radarProcessOffUiIsolate});

  /// Slots of [source] for the last [window] (at most [RadarSource.maxWindow]).
  /// Every event is a complete [RadarLoop]; the last one has `loading == false`.
  Stream<RadarLoop> watch(RadarSource source, {required Duration window}) {
    if (window <= Duration.zero || window > source.maxWindow) {
      throw RangeError('radar window: expected 0 < window <= ${source.maxWindow} for ${source.id}, got $window');
    }
    final cancel = CancelToken();
    final out = StreamController<RadarLoop>();
    out.onCancel = () => cancel.cancel('radar load of ${source.id} cancelled');
    out.onListen = () async {
      final previous = _lastLoad;
      final done = Completer<void>();
      _lastLoad = done.future;
      try {
        await previous;
        await _load(source, window, out.add, cancel);
      } catch (e, s) {
        // The cancellation error is how a cancelled load ends; nobody listens.
        if (!(cancel.isCancelled && _isCancel(e))) out.addError(e, s);
      } finally {
        done.complete();
        await out.close();
      }
    };
    return out.stream;
  }

  Future<void> _load(RadarSource source, Duration window, void Function(RadarLoop) emit, CancelToken cancel) async {
    final root = await cacheRoot();
    if (!_legacyCachesDeleted) {
      await deleteLegacyRadarCaches(root);
      _legacyCachesDeleted = true;
    }
    final dir = Directory('${root.path}/$radarFrameCacheDirName/${source.id}');
    await dir.create(recursive: true);
    final now = clock();
    final cached = await _pruneCache(dir, now: now, retention: source.maxWindow);
    final ready = <String, RadarFrame>{};
    Future<RadarEchoStats> readStats(String key) async {
      final file = File('${dir.path}/$key.stats');
      return RadarEchoStats.fromBytes(await file.readAsBytes(), source: file.path);
    }

    Future<void> readCached(String key) async {
      if (ready.containsKey(key)) return;
      final webp = File('${dir.path}/$key.webp');
      final size = radarWebpSize(Uint8List.fromList(
          await webp.openRead(0, radarWebpHeaderBytes).expand((chunk) => chunk).toList()));
      ready[key] = _frame(_cacheKeyTime(key), webp, await readStats(key), size);
    }

    // Each event carries the slots as they were when it was sent.
    void send(List<RadarSlot> slots, {required bool loading, RadarDataException? listError}) =>
        emit(RadarLoop(slots: List<RadarSlot>.unmodifiable(slots), loading: loading, listError: listError));

    // Cache first: the window span ending at the newest cached frame.
    final cachedSlots = <RadarSlot>[];
    if (cached.isNotEmpty) {
      final start = _cacheKeyTime(cached.last).subtract(window);
      for (final key in cached.where((s) => _cacheKeyTime(s).isAfter(start))) {
        await readCached(key);
        cachedSlots.add(RadarSlot.ready(ready[key]!));
      }
    }
    send(cachedSlots, loading: true);

    final List<RadarFrameRef> listed;
    try {
      listed = await source.listFrames(now: now, window: window, cancelToken: cancel);
    } on RadarDataException catch (e) {
      send(cachedSlots, loading: false, listError: e);
      return;
    }

    // One slot per listed time, oldest first (map insertion order).
    final byTime = [...listed]..sort((a, b) => a.time.compareTo(b.time));
    final slots = <String, RadarSlot>{};
    for (final f in byTime) {
      final key = _cacheKey(f.time);
      if (cached.contains(key)) await readCached(key);
      slots[key] = switch (ready[key]) { final frame? => RadarSlot.ready(frame), null => RadarSlot.pending(f.time) };
    }
    void sendSlots({required bool loading}) => send([...slots.values], loading: loading);
    sendSlots(loading: true);

    final pending = [for (final f in byTime) if (slots[_cacheKey(f.time)]!.state == RadarSlotState.pending) f];
    final order = pending.isEmpty ? const <RadarFrameRef>[] : [pending.last, ...pending.sublist(0, pending.length - 1)];
    // Finished slots wait here until every slot before them in [order] is published.
    final finished = <String, RadarSlot>{};
    var published = 0;
    // One token per frame, cancelled with the load: dio and the processing race
    // keep listeners on a token until it fires, and those listeners hold the
    // response body and the processed frame, so a load-wide token would keep
    // every frame of the load in memory (~1.5 MB per station frame).
    final frameTokens = <CancelToken>{};
    cancel.whenCancel.then((e) {
      for (final token in [...frameTokens]) {
        token.cancel(e.error);
      }
    });
    Future<void> fetch(RadarFrameRef f) async {
      if (cancel.cancelError case final e?) throw e;
      final token = CancelToken();
      frameTokens.add(token);
      try {
        finished[_cacheKey(f.time)] = RadarSlot.ready(await _fetch(dir, f, token));
      } on Exception catch (e) {
        if (_isCancel(e)) rethrow;
        finished[_cacheKey(f.time)] = RadarSlot.failed(f.time, _frameFailure(f, e));
      } finally {
        frameTokens.remove(token);
      }
      while (published < order.length) {
        final key = _cacheKey(order[published].time);
        final slot = finished.remove(key);
        if (slot == null) break;
        slots[key] = slot;
        published++;
        sendSlots(loading: true);
      }
    }

    if (order.isNotEmpty) await fetch(order.first);
    var next = 1;
    Future<void> worker() async {
      while (next < order.length && !cancel.isCancelled) {
        await fetch(order[next++]);
      }
    }

    await Future.wait([for (var i = 0; i < radarFetchWorkers; i++) worker()]);
    sendSlots(loading: false);
  }

  /// Deletes every file of [dir] that is not a frame file observed within
  /// [retention] before the newest cached frame, or before [now] if that is
  /// earlier (including temp files of an interrupted write); returns the keys
  /// of complete frames, oldest first. Anchored like the windows (which end at
  /// the newest frame, a few minutes before [now]), so a full window is never
  /// pruned and downloaded again.
  Future<List<String>> _pruneCache(Directory dir, {required DateTime now, required Duration retention}) async {
    final entries = [
      for (final entity in await dir.list().toList())
        (entity, _cacheFilePattern.firstMatch(entity.path.substring(dir.path.length + 1)))
    ];
    final webpKeys = [for (final (_, match) in entries) if (match?[2] == 'webp') match![1]!]..sort();
    final newest = webpKeys.isEmpty ? null : _cacheKeyTime(webpKeys.last);
    final end = newest != null && newest.isBefore(now.toUtc()) ? newest : now.toUtc();
    final cutoff = end.subtract(retention);
    for (final (entity, match) in entries) {
      if (match == null || _cacheKeyTime(match[1]!).isBefore(cutoff)) await entity.delete(recursive: true);
    }
    return [for (final key in webpKeys) if (!_cacheKeyTime(key).isBefore(cutoff)) key];
  }

  /// Downloads and processes [f]; the WebP is renamed into place last, so a
  /// `<key>.webp` always has its stats file. Throws the cancellation error once
  /// [cancel] fires, before any file is written: a frame still in processing
  /// is dropped (its isolate runs to the end unobserved) and a frame waiting
  /// for a processing slot is never processed.
  Future<RadarFrame> _fetch(Directory dir, RadarFrameRef f, CancelToken cancel) async {
    final response =
        await _dio.get<List<int>>(f.url, options: Options(responseType: ResponseType.bytes), cancelToken: cancel);
    final body = response.data ??
        (throw RadarDataException(f.url, expected: 'PNG body', actual: 'HTTP ${response.statusCode} without body'));
    final processed = await _processPool.withResource(() {
      if (cancel.cancelError case final e?) throw e;
      return Future.any([
        process(Uint8List.fromList(body), f.geometry),
        cancel.whenCancel.then<ProcessedRadarFrame>((e) => throw e),
      ]);
    });
    final key = _cacheKey(f.time);
    final stats = File('${dir.path}/$key.stats');
    final webp = File('${dir.path}/$key.webp');
    await (await File('${stats.path}.tmp').writeAsBytes(processed.stats.toBytes(), flush: true)).rename(stats.path);
    await (await File('${webp.path}.tmp').writeAsBytes(processed.webp, flush: true)).rename(webp.path);
    return _frame(f.time, webp, processed.stats, radarWebpSize(processed.webp));
  }
}

bool _isCancel(Object e) => e is DioException && CancelToken.isCancel(e);

RadarFrame _frame(DateTime time, File webp, RadarEchoStats stats, ({int width, int height}) size) => RadarFrame(
      time: time,
      file: webp,
      bounds: stats.frame,
      significantDbz: stats.hasSignificantEcho ? stats.strongestDbz : null,
      width: size.width,
      height: size.height,
    );

/// Why listed frame [f] has no cached frame, naming the frame by its URL.
RadarDataException _frameFailure(RadarFrameRef f, Exception e) => switch (e) {
      RadarDataException() => e,
      DioException() => RadarDataException(f.url, expected: 'HTTP 200 with the frame PNG', actual: radarHttpFailure(e)),
      _ => RadarDataException(f.url, expected: 'a radar frame PNG that processes', actual: e),
    };

/// Top-level so the isolate closure captures only [png] and [geometry].
Future<ProcessedRadarFrame> radarProcessOffUiIsolate(Uint8List png, RadarImageGeometry geometry) =>
    Isolate.run(() => processRadarFrame(png, geometry));
