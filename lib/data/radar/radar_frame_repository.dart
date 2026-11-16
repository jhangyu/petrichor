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
import 'radar_webp_image.dart';
import 'radar_webp.dart';

export 'radar_loop.dart';

/// Frames processed at once (one isolate each). Measured on the Mac
/// (docs/logs/2026-11-15/radar-perf-handover.md §9): 2 workers are 2.1x
/// faster than 1 for ~+100 MB RSS; 4 workers cost +410 MB RSS (rejected).
const _radarProcessWorkers = 2;

/// Frames downloaded at once. Each download worker holds at most one body, so
/// at most `_radarFetchWorkers - _radarProcessWorkers` = 2 downloaded bodies
/// (~0.7 MB composite, ~1.1 MB station each) wait for a processing slot.
const _radarFetchWorkers = 4;

/// Turns a downloaded frame PNG into the cached frame ([RadarPngStep]);
/// [radarProcessOffUiIsolate] except in tests.
typedef RadarFrameProcess = Future<ProcessedRadarFrame> Function(Uint8List png, RadarImageGeometry geometry);

/// Cache files per frame: `<key>.webp` (lossless WebP) and `<key>.stats`
/// ([RadarEchoStats.toBytes]); key = observation time `yyyyMMddHHmmss` UTC
/// (station frames have irregular seconds).
final _cacheFilePattern = RegExp(r'^(\d{14})\.(webp|stats)$');

/// One processed, cached frame: transparent lossless WebP with rows linear in
/// Web Mercator, shown as one `OverlayImage` over [bounds]. Of the echo
/// statistics only the strongest echo is kept.
class RadarFrame {
  final DateTime time;
  final File file;
  final LatLngBounds bounds;

  /// [RadarEchoStats.strongestDbz] when the frame has significant echo, else null.
  final int? significantDbz;

  /// [RadarEchoStats.peakMm]: highest accumulated rain (mm) of an
  /// accumulated-rainfall frame; null for radar frames.
  final double? peakMm;

  /// Pixel size of [file] (website frames: 2048 x 2132 Mercator rows).
  final int width;
  final int height;

  const RadarFrame({
    required this.time,
    required this.file,
    required this.bounds,
    required this.significantDbz,
    this.peakMm,
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
/// rest oldest first (playback order). Up to [_radarFetchWorkers] downloads run
/// at once, processing (off the UI isolate) is limited to [_radarProcessWorkers],
/// and slots are published strictly in that order, one event per slot. Keeps
/// [RadarSource.maxWindow] of frames on disk per source, so changing the
/// window never deletes or reprocesses frames. How a frame is obtained is the
/// source's [RadarSource.step].
class RadarFrameRepository {
  final Dio _dio;
  final Future<Directory> Function() cacheRoot;
  final DateTime Function() clock;
  final RadarFrameProcess process;

  /// Shared by all loads so the processing bound holds across back-to-back loads.
  final _processPool = Pool(_radarProcessWorkers);

  /// The last started load per cache family (first segment of
  /// [RadarSource.cachePath]). Loads of a family run one after another (they
  /// share cache files), loads of different families do not wait for each
  /// other (the processing memory bound is [_processPool]); cancelling a load
  /// aborts its HTTP requests and drops its frames still in processing, so the
  /// next load starts at once.
  final _lastLoad = <String, Future<void>>{};

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
      final family = source.cachePath.split('/').first;
      final previous = _lastLoad[family] ?? Future<void>.value();
      final done = Completer<void>();
      _lastLoad[family] = done.future;
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
    final dir = Directory('${root.path}/${source.cachePath}');
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
      ready[key] = _frame(parseUtcStamp(key), webp, await readStats(key), size);
    }

    // Each event carries the slots as they were when it was sent.
    void send(List<RadarSlot> slots, {required bool loading, RadarDataException? listError}) =>
        emit(RadarLoop(slots: List<RadarSlot>.unmodifiable(slots), loading: loading, listError: listError));

    // Cache first: the window span ending at the newest cached frame.
    final cachedSlots = <RadarSlot>[];
    if (cached.isNotEmpty) {
      final start = parseUtcStamp(cached.last).subtract(window);
      for (final key in cached.where((s) => parseUtcStamp(s).isAfter(start))) {
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
      final key = formatUtcStamp(f.time, seconds: true);
      if (cached.contains(key)) {
        try {
          if (await source.cachedFrameStale?.call(f, cancel) ?? false) {
            ready.remove(key);
          } else {
            await readCached(key);
          }
        } on RadarDataException catch (e) {
          slots[key] = RadarSlot.failed(f.time, e);
          continue;
        }
      }
      slots[key] = switch (ready[key]) { final frame? => RadarSlot.ready(frame), null => RadarSlot.pending(f.time) };
    }
    // Cached frames the next cache-first view would show but the list does not
    // list (an accumulation window that moved by 10 min lists other times):
    // deleted, WebP first (a frame without its WebP is not a cached frame).
    if (byTime.isNotEmpty) {
      final from = byTime.last.time.subtract(window);
      for (final key in cached) {
        final t = parseUtcStamp(key);
        if (t.isAfter(from) && !t.isAfter(byTime.last.time) && !slots.containsKey(key)) {
          await File('${dir.path}/$key.webp').delete();
          await File('${dir.path}/$key.stats').delete();
        }
      }
    }
    void sendSlots({required bool loading}) => send([...slots.values], loading: loading);
    sendSlots(loading: true);

    final pending = [for (final f in byTime) if (slots[formatUtcStamp(f.time, seconds: true)]!.state == RadarSlotState.pending) f];
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
        finished[formatUtcStamp(f.time, seconds: true)] = RadarSlot.ready(await _fetch(dir, source.step, f, token));
      } on Exception catch (e) {
        if (_isCancel(e)) rethrow;
        finished[formatUtcStamp(f.time, seconds: true)] = RadarSlot.failed(f.time, _frameFailure(f, e));
      } finally {
        frameTokens.remove(token);
      }
      while (published < order.length) {
        final key = formatUtcStamp(order[published].time, seconds: true);
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

    await Future.wait([for (var i = 0; i < _radarFetchWorkers; i++) worker()]);
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
    final newest = webpKeys.isEmpty ? null : parseUtcStamp(webpKeys.last);
    final end = newest != null && newest.isBefore(now.toUtc()) ? newest : now.toUtc();
    final cutoff = end.subtract(retention);
    for (final (entity, match) in entries) {
      if (match == null || parseUtcStamp(match[1]!).isBefore(cutoff)) await entity.delete(recursive: true);
    }
    return [for (final key in webpKeys) if (!parseUtcStamp(key).isBefore(cutoff)) key];
  }

  /// Obtains [f] by [step] and caches it; the WebP is renamed into place last,
  /// so a `<key>.webp` always has its stats file. Throws the cancellation error
  /// once [cancel] fires, before any file is written: a frame still in
  /// processing is dropped (its isolate runs to the end unobserved) and a frame
  /// waiting for a processing slot is never processed.
  Future<RadarFrame> _fetch(Directory dir, RadarFrameStep step, RadarFrameRef f, CancelToken cancel) async {
    Future<ProcessedRadarFrame> processSlot(Future<ProcessedRadarFrame> Function() work) =>
        _processPool.withResource(() {
          if (cancel.cancelError case final e?) throw e;
          return Future.any([work(), cancel.whenCancel.then<ProcessedRadarFrame>((e) => throw e)]);
        });
    final processed = switch (step) {
      RadarPngStep(:final geometry) => await _downloadAndProcess(f, geometry, cancel, processSlot),
      RadarComposedStep(:final obtain) => await obtain(f, cancel, processSlot),
    };
    final key = formatUtcStamp(f.time, seconds: true);
    final stats = File('${dir.path}/$key.stats');
    final webp = File('${dir.path}/$key.webp');
    await writeAtomic(stats, processed.stats.toBytes());
    await writeAtomic(webp, processed.webp);
    return _frame(f.time, webp, processed.stats, radarWebpSize(processed.webp));
  }

  /// The [RadarPngStep]: download the frame PNG, then [process] it.
  Future<ProcessedRadarFrame> _downloadAndProcess(
      RadarFrameRef f, RadarImageGeometry geometry, CancelToken cancel, RadarProcessSlot processSlot) async {
    final response =
        await _dio.get<List<int>>(f.url, options: Options(responseType: ResponseType.bytes), cancelToken: cancel);
    final body = response.data ??
        (throw RadarDataException(f.url, expected: 'PNG body', actual: 'HTTP ${response.statusCode} without body'));
    return processSlot(() => process(Uint8List.fromList(body), geometry));
  }
}

bool _isCancel(Object e) => e is DioException && CancelToken.isCancel(e);

RadarFrame _frame(DateTime time, File webp, RadarEchoStats stats, ({int width, int height}) size) => RadarFrame(
      time: time,
      file: webp,
      bounds: stats.frame,
      significantDbz: stats.hasSignificantEcho ? stats.strongestDbz : null,
      peakMm: stats.peakMm,
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
