import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pool/pool.dart';

import 'radar_echo_stats.dart';
import 'radar_frame_list.dart';
import 'radar_frame_processor.dart';
import 'radar_loop.dart';
import 'radar_source.dart';

export 'radar_loop.dart';

/// Cache sub-directory (one sub-directory per source); the suffix changes
/// whenever processing output changes, so frames made by an older pipeline are
/// never shown.
const radarFrameCacheDirName = 'radar_indexed_png_2048_v1';

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

/// Cache files per frame: `<key>.png` (indexed PNG) and `<key>.stats.gz`
/// (gzip of [RadarEchoStats.toBytes]; the cell grid is mostly zeros); key =
/// observation time `yyyyMMddHHmmss` UTC (station frames have irregular seconds).
final _cacheFilePattern = RegExp(r'^(\d{14})\.(png|stats\.gz)$');

String _cacheKey(DateTime t) {
  final u = t.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}${two(u.hour)}${two(u.minute)}${two(u.second)}';
}

DateTime _cacheKeyTime(String k) => DateTime.utc(int.parse(k.substring(0, 4)), int.parse(k.substring(4, 6)),
    int.parse(k.substring(6, 8)), int.parse(k.substring(8, 10)), int.parse(k.substring(10, 12)), int.parse(k.substring(12, 14)));

/// One processed, cached frame: transparent indexed PNG with rows linear in
/// Web Mercator, shown as one `OverlayImage` over [bounds]. Only the strongest
/// echo is kept per frame: the full statistics (~560 KB of cell grid each,
/// ~110 MB for a 200-frame station loop) are held for the newest frame only
/// ([RadarLoop.newestStats]).
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

  /// Decoded at [decodeWidth] px, not always at the stored 2048 px: a
  /// full-width decoded website frame is ~17 MB, so decode no wider than the
  /// frame is shown on screen.
  ImageProvider imageProvider({required int decodeWidth}) =>
      ResizeImage(FileImage(file), width: decodeWidth, policy: ResizeImagePolicy.fit);
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
    final dir = Directory('${(await cacheRoot()).path}/$radarFrameCacheDirName/${source.id}');
    await dir.create(recursive: true);
    final now = clock();
    final cached = await _pruneCache(dir, now: now, retention: source.maxWindow);
    final ready = <String, RadarFrame>{};
    Future<RadarEchoStats> readStats(String key) async {
      final file = File('${dir.path}/$key.stats.gz');
      return RadarEchoStats.fromBytes(Uint8List.fromList(gzip.decode(await file.readAsBytes())), source: file.path);
    }

    Future<void> readCached(String key) async {
      if (ready.containsKey(key)) return;
      final png = File('${dir.path}/$key.png');
      final size = _pngSize(await png.openRead(0, _pngHeaderBytes).expand((chunk) => chunk).toList(), source: png.path);
      ready[key] = _frame(_cacheKeyTime(key), png, await readStats(key), size);
    }

    // Events go out in order; each carries the slots as they were when it was
    // queued and the newest ready frame's statistics (re-read only when the
    // newest ready frame changes).
    var sending = Future<void>.value();
    ({String key, RadarEchoStats stats})? newest;
    Future<void> send(List<RadarSlot> slots, {required bool loading, RadarDataException? listError}) {
      final snapshot = List<RadarSlot>.unmodifiable(slots);
      return sending = sending.then((_) async {
        final shown = [for (final s in snapshot) ?s.frame].lastOrNull;
        if (shown != null) {
          final key = _cacheKey(shown.time);
          if (newest?.key != key) newest = (key: key, stats: await readStats(key));
        }
        emit(RadarLoop(
            slots: snapshot, newestStats: shown == null ? null : newest!.stats, loading: loading, listError: listError));
      });
    }

    // Cache first: the window span ending at the newest cached frame.
    final cachedSlots = <RadarSlot>[];
    if (cached.isNotEmpty) {
      final start = _cacheKeyTime(cached.last).subtract(window);
      for (final key in cached.where((s) => _cacheKeyTime(s).isAfter(start))) {
        await readCached(key);
        cachedSlots.add(RadarSlot.ready(ready[key]!));
      }
    }
    await send(cachedSlots, loading: true);

    final List<RadarFrameRef> listed;
    try {
      listed = await source.listFrames(now: now, window: window, cancelToken: cancel);
    } on RadarDataException catch (e) {
      await send(cachedSlots, loading: false, listError: e);
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
    Future<void> sendSlots({required bool loading}) => send([...slots.values], loading: loading);
    await sendSlots(loading: true);

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
        await sendSlots(loading: true);
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
    await sendSlots(loading: false);
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
    final pngKeys = [for (final (_, match) in entries) if (match?[2] == 'png') match![1]!]..sort();
    final newest = pngKeys.isEmpty ? null : _cacheKeyTime(pngKeys.last);
    final end = newest != null && newest.isBefore(now.toUtc()) ? newest : now.toUtc();
    final cutoff = end.subtract(retention);
    for (final (entity, match) in entries) {
      if (match == null || _cacheKeyTime(match[1]!).isBefore(cutoff)) await entity.delete(recursive: true);
    }
    return [for (final key in pngKeys) if (!_cacheKeyTime(key).isBefore(cutoff)) key];
  }

  /// Downloads and processes [f]; the PNG is renamed into place last, so a
  /// `<key>.png` always has its stats file. Throws the cancellation error once
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
    final stats = File('${dir.path}/$key.stats.gz');
    final png = File('${dir.path}/$key.png');
    await (await File('${stats.path}.tmp').writeAsBytes(gzip.encode(processed.stats.toBytes()), flush: true))
        .rename(stats.path);
    await (await File('${png.path}.tmp').writeAsBytes(processed.png, flush: true)).rename(png.path);
    return _frame(f.time, png, processed.stats, _pngSize(processed.png, source: f.url));
  }
}

bool _isCancel(Object e) => e is DioException && CancelToken.isCancel(e);

RadarFrame _frame(DateTime time, File png, RadarEchoStats stats, ({int width, int height}) size) => RadarFrame(
      time: time,
      file: png,
      bounds: stats.frame,
      significantDbz: stats.hasSignificantEcho ? stats.strongestDbz : null,
      width: size.width,
      height: size.height,
    );

/// PNG signature (8) + IHDR length and type (8) + width and height (8).
const _pngHeaderBytes = 24;

/// Pixel size from the IHDR chunk at the start of a PNG.
({int width, int height}) _pngSize(List<int> head, {required String source}) {
  if (head.length < _pngHeaderBytes || String.fromCharCodes(head.sublist(12, 16)) != 'IHDR') {
    throw FormatException('$source: expected a PNG starting with IHDR, got ${head.take(_pngHeaderBytes).toList()}');
  }
  final data = ByteData.sublistView(Uint8List.fromList(head.sublist(0, _pngHeaderBytes)));
  return (width: data.getUint32(16), height: data.getUint32(20));
}

/// Why listed frame [f] has no cached frame, naming the frame by its URL.
RadarDataException _frameFailure(RadarFrameRef f, Exception e) => switch (e) {
      RadarDataException() => e,
      DioException() => RadarDataException(f.url, expected: 'HTTP 200 with the frame PNG', actual: radarHttpFailure(e)),
      _ => RadarDataException(f.url, expected: 'a radar frame PNG that processes', actual: e),
    };

/// Top-level so the isolate closure captures only [png] and [geometry].
Future<ProcessedRadarFrame> radarProcessOffUiIsolate(Uint8List png, RadarImageGeometry geometry) =>
    Isolate.run(() => processRadarFrame(png, geometry));
