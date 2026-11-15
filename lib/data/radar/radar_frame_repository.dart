import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

import 'radar_echo_stats.dart';
import 'radar_frame_list.dart';
import 'radar_frame_processor.dart';
import 'radar_source.dart';

/// Cache sub-directory (one sub-directory per source); the suffix changes
/// whenever processing output changes, so frames made by an older pipeline are
/// never shown.
const radarFrameCacheDirName = 'radar_indexed_png_v1';

/// Frames stay on disk this long after their observation time, whatever
/// look-back is selected, so changing the window never deletes or reprocesses
/// frames. 24 h = all the website lists.
final radarFrameRetention = radarFrameStep * radarMaxWindowFrames;

/// Frames downloaded and processed at once. Measured on the Mac
/// (.claude/tmp/arch-2/parallel.log): 2 workers are 2.1x faster than 1 for
/// ~+100 MB RSS; 4 workers cost +410 MB RSS (rejected).
const radarProcessWorkers = 2;

/// Cache files per frame: `<stamp>.png` (indexed PNG) and `<stamp>.stats.gz`
/// (gzip of [RadarEchoStats.toBytes]; the cell grid is mostly zeros).
final _cacheFilePattern = RegExp(r'^(\d{12})\.(png|stats\.gz)$');

/// One processed, cached frame: transparent indexed PNG with rows linear in
/// Web Mercator, shown as one `OverlayImage` over [bounds].
class RadarFrame {
  final DateTime time;
  final File file;
  final RadarEchoStats stats;

  const RadarFrame({required this.time, required this.file, required this.stats});

  LatLngBounds get bounds => stats.frame;

  /// Decoded at [decodeWidth] px, not at full 3600 px: a full-size decoded
  /// frame is ~54 MB, so a loop must use a display-size width and only the
  /// paused, zoomed-in frame may use the full width.
  ImageProvider imageProvider({required int decodeWidth}) =>
      ResizeImage(FileImage(file), width: decodeWidth, policy: ResizeImagePolicy.fit);
}

/// A listed frame that could not be downloaded or processed.
class RadarFrameFailure {
  final RadarFrameRef frame;
  final Exception error;

  const RadarFrameFailure(this.frame, this.error);

  @override
  String toString() => '${frame.url}: $error';
}

/// What one source currently has to show.
class RadarLoop {
  /// Ready frames, oldest first.
  final List<RadarFrame> frames;

  /// Frames are still being fetched or processed.
  final bool loading;

  /// Frames the source listed for the window; null before the list is known
  /// or when it could not be fetched.
  final int? windowSize;

  /// Listed frames that failed; the other frames are still shown.
  final List<RadarFrameFailure> failures;

  /// The frame list could not be fetched; [frames] then come from the cache.
  final Exception? listError;

  const RadarLoop({
    required this.frames,
    required this.loading,
    this.windowSize,
    this.failures = const [],
    this.listError,
  });
}

/// Loads a source's frames: cached frames first, then the frame list, then
/// the missing frames newest first, each processed off the UI isolate and
/// emitted as soon as it is ready. Keeps [radarFrameRetention] of frames on disk.
class RadarFrameRepository {
  final Dio _dio;
  final Future<Directory> Function() cacheRoot;
  final DateTime Function() clock;

  /// The last started load. Loads run one after another (cache files and the
  /// [radarProcessWorkers] memory bound are shared); a cancelled load stops
  /// after its in-flight frames.
  Future<void> _lastLoad = Future.value();

  RadarFrameRepository(this._dio, {required this.cacheRoot, required this.clock});

  /// Frames of [source] for the last [windowFrames] x [radarFrameStep]. Every
  /// event is a complete [RadarLoop]; the last one has `loading == false`.
  Stream<RadarLoop> watch(RadarSource source, {required int windowFrames}) {
    var cancelled = false;
    final out = StreamController<RadarLoop>();
    out.onCancel = () => cancelled = true;
    out.onListen = () async {
      final previous = _lastLoad;
      final done = Completer<void>();
      _lastLoad = done.future;
      try {
        await previous;
        await _load(source, windowFrames, out.add, () => cancelled);
      } catch (e, s) {
        out.addError(e, s);
      } finally {
        done.complete();
        await out.close();
      }
    };
    return out.stream;
  }

  Future<void> _load(RadarSource source, int windowFrames, void Function(RadarLoop) emit, bool Function() cancelled) async {
    final dir = Directory('${(await cacheRoot()).path}/$radarFrameCacheDirName/${source.id}');
    await dir.create(recursive: true);
    final now = clock();
    final span = radarFrameStep * windowFrames;
    final cached = await _pruneCache(dir, now: now);
    final ready = <String, RadarFrame>{};
    Future<void> readCached(String stamp) async {
      if (ready.containsKey(stamp)) return;
      final stats = File('${dir.path}/$stamp.stats.gz');
      ready[stamp] = RadarFrame(
        time: radarStampTime(stamp),
        file: File('${dir.path}/$stamp.png'),
        stats: RadarEchoStats.fromBytes(Uint8List.fromList(gzip.decode(await stats.readAsBytes())), source: stats.path),
      );
    }

    // Cache first: the window span ending at the newest cached frame.
    final cachedShown = <RadarFrame>[];
    if (cached.isNotEmpty) {
      final start = radarStampTime(cached.last).subtract(span);
      for (final stamp in cached.where((s) => radarStampTime(s).isAfter(start))) {
        await readCached(stamp);
        cachedShown.add(ready[stamp]!);
      }
    }
    emit(RadarLoop(frames: cachedShown, loading: true));

    final List<RadarFrameRef> window;
    try {
      window = await source.listFrames(now: now, windowFrames: windowFrames);
    } on Exception catch (e) {
      emit(RadarLoop(frames: cachedShown, loading: false, listError: e));
      return;
    }

    final stamps = [for (final f in window) f.stamp]..sort();
    for (final stamp in stamps.where(cached.contains)) {
      await readCached(stamp);
    }
    final failures = <RadarFrameFailure>[];
    void emitWindow({required bool loading}) => emit(RadarLoop(
          frames: [for (final s in stamps) ?ready[s]],
          loading: loading,
          windowSize: window.length,
          failures: List.unmodifiable(failures),
        ));

    final queue = [for (final f in window) if (!ready.containsKey(f.stamp)) f]
      ..sort((a, b) => b.time.compareTo(a.time));
    Future<void> fetch(RadarFrameRef f) async {
      try {
        ready[f.stamp] = await _fetch(dir, f);
      } on Exception catch (e) {
        failures.add(RadarFrameFailure(f, e));
      }
      emitWindow(loading: true);
    }

    // The newest frame alone first (it is the one shown), then the rest.
    if (queue.isNotEmpty) await fetch(queue.first);
    var next = 1;
    Future<void> worker() async {
      while (next < queue.length && !cancelled()) {
        await fetch(queue[next++]);
      }
    }

    await Future.wait([for (var i = 0; i < radarProcessWorkers; i++) worker()]);
    emitWindow(loading: false);
  }

  /// Deletes every file of [dir] that is not a frame file observed within
  /// [radarFrameRetention] before [now] (including temp files of an
  /// interrupted write); returns the stamps of complete frames, oldest first.
  Future<List<String>> _pruneCache(Directory dir, {required DateTime now}) async {
    final cutoff = now.toUtc().subtract(radarFrameRetention);
    final stamps = <String>[];
    await for (final entity in dir.list()) {
      final match = _cacheFilePattern.firstMatch(entity.path.substring(dir.path.length + 1));
      if (match == null || radarStampTime(match[1]!).isBefore(cutoff)) {
        await entity.delete(recursive: true);
      } else if (match[2] == 'png') {
        stamps.add(match[1]!);
      }
    }
    return stamps..sort();
  }

  /// Downloads and processes [f]; the PNG is renamed into place last, so a
  /// `<stamp>.png` always has its stats file.
  Future<RadarFrame> _fetch(Directory dir, RadarFrameRef f) async {
    final response = await _dio.get<List<int>>(f.url, options: Options(responseType: ResponseType.bytes));
    final body = response.data ??
        (throw RadarDataException(f.url, expected: 'PNG body', actual: 'HTTP ${response.statusCode} without body'));
    final processed = await _processOffUiIsolate(Uint8List.fromList(body), f.geometry);
    final stats = File('${dir.path}/${f.stamp}.stats.gz');
    final png = File('${dir.path}/${f.stamp}.png');
    await (await File('${stats.path}.tmp').writeAsBytes(gzip.encode(processed.stats.toBytes()), flush: true))
        .rename(stats.path);
    await (await File('${png.path}.tmp').writeAsBytes(processed.png, flush: true)).rename(png.path);
    return RadarFrame(time: f.time, file: png, stats: processed.stats);
  }
}

/// Top-level so the isolate closure captures only [png] and [geometry].
Future<ProcessedRadarFrame> _processOffUiIsolate(Uint8List png, RadarImageGeometry geometry) =>
    Isolate.run(() => processRadarFrame(png, geometry));
