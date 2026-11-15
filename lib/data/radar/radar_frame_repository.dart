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

/// Frames of every source stay on disk this long after their observation
/// time, whatever look-back is selected, so changing the window never deletes
/// or reprocesses frames. 24 h = the longest source window.
const radarFrameRetention = Duration(hours: 24);

/// Frames downloaded and processed at once. Measured on the Mac
/// (docs/logs/2026-11-15/radar-perf-handover.md §9): 2 workers are 2.1x
/// faster than 1 for ~+100 MB RSS; 4 workers cost +410 MB RSS (rejected).
const radarProcessWorkers = 2;

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

  /// Pixel size of [file] (website frames: 3600 x 3748 Mercator rows).
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

  /// Echo statistics of `frames.last`; null when there is no frame.
  final RadarEchoStats? newestStats;

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
    required this.newestStats,
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

  /// Frames of [source] for the last [window] (at most [RadarSource.maxWindow]).
  /// Every event is a complete [RadarLoop]; the last one has `loading == false`.
  Stream<RadarLoop> watch(RadarSource source, {required Duration window}) {
    if (window <= Duration.zero || window > source.maxWindow) {
      throw RangeError('radar window: expected 0 < window <= ${source.maxWindow} for ${source.id}, got $window');
    }
    var cancelled = false;
    final out = StreamController<RadarLoop>();
    out.onCancel = () => cancelled = true;
    out.onListen = () async {
      final previous = _lastLoad;
      final done = Completer<void>();
      _lastLoad = done.future;
      try {
        await previous;
        await _load(source, window, out.add, () => cancelled);
      } catch (e, s) {
        out.addError(e, s);
      } finally {
        done.complete();
        await out.close();
      }
    };
    return out.stream;
  }

  Future<void> _load(RadarSource source, Duration window, void Function(RadarLoop) emit, bool Function() cancelled) async {
    final dir = Directory('${(await cacheRoot()).path}/$radarFrameCacheDirName/${source.id}');
    await dir.create(recursive: true);
    final now = clock();
    final cached = await _pruneCache(dir, now: now);
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

    // Events go out in order; each takes the frames ready when it is sent and
    // the newest frame's statistics (re-read only when the newest changes).
    var sending = Future<void>.value();
    ({String key, RadarEchoStats stats})? newest;
    Future<void> send(List<RadarFrame> Function() frames,
        {required bool loading, int? windowSize, List<RadarFrameFailure> failures = const [], Exception? listError}) {
      return sending = sending.then((_) async {
        final shown = frames();
        if (shown.isNotEmpty) {
          final key = _cacheKey(shown.last.time);
          if (newest?.key != key) newest = (key: key, stats: await readStats(key));
        }
        emit(RadarLoop(
          frames: shown,
          newestStats: shown.isEmpty ? null : newest!.stats,
          loading: loading,
          windowSize: windowSize,
          failures: failures,
          listError: listError,
        ));
      });
    }

    // Cache first: the window span ending at the newest cached frame.
    final cachedShown = <RadarFrame>[];
    if (cached.isNotEmpty) {
      final start = _cacheKeyTime(cached.last).subtract(window);
      for (final key in cached.where((s) => _cacheKeyTime(s).isAfter(start))) {
        await readCached(key);
        cachedShown.add(ready[key]!);
      }
    }
    await send(() => cachedShown, loading: true);

    final List<RadarFrameRef> listed;
    try {
      listed = await source.listFrames(now: now, window: window);
    } on Exception catch (e) {
      await send(() => cachedShown, loading: false, listError: e);
      return;
    }

    final keys = [for (final f in listed) _cacheKey(f.time)]..sort();
    for (final key in keys.where(cached.contains)) {
      await readCached(key);
    }
    final failures = <RadarFrameFailure>[];
    Future<void> sendWindow({required bool loading}) => send(() => [for (final k in keys) ?ready[k]],
        loading: loading, windowSize: listed.length, failures: List.unmodifiable(failures));

    final queue = [for (final f in listed) if (!ready.containsKey(_cacheKey(f.time))) f]
      ..sort((a, b) => b.time.compareTo(a.time));
    Future<void> fetch(RadarFrameRef f) async {
      try {
        ready[_cacheKey(f.time)] = await _fetch(dir, f);
      } on Exception catch (e) {
        failures.add(RadarFrameFailure(f, e));
      }
      await sendWindow(loading: true);
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
    await sendWindow(loading: false);
  }

  /// Deletes every file of [dir] that is not a frame file observed within
  /// [radarFrameRetention] before [now] (including temp files of an
  /// interrupted write); returns the keys of complete frames, oldest first.
  Future<List<String>> _pruneCache(Directory dir, {required DateTime now}) async {
    final cutoff = now.toUtc().subtract(radarFrameRetention);
    final keys = <String>[];
    await for (final entity in dir.list()) {
      final match = _cacheFilePattern.firstMatch(entity.path.substring(dir.path.length + 1));
      if (match == null || _cacheKeyTime(match[1]!).isBefore(cutoff)) {
        await entity.delete(recursive: true);
      } else if (match[2] == 'png') {
        keys.add(match[1]!);
      }
    }
    return keys..sort();
  }

  /// Downloads and processes [f]; the PNG is renamed into place last, so a
  /// `<key>.png` always has its stats file.
  Future<RadarFrame> _fetch(Directory dir, RadarFrameRef f) async {
    final response = await _dio.get<List<int>>(f.url, options: Options(responseType: ResponseType.bytes));
    final body = response.data ??
        (throw RadarDataException(f.url, expected: 'PNG body', actual: 'HTTP ${response.statusCode} without body'));
    final processed = await _processOffUiIsolate(Uint8List.fromList(body), f.geometry);
    final key = _cacheKey(f.time);
    final stats = File('${dir.path}/$key.stats.gz');
    final png = File('${dir.path}/$key.png');
    await (await File('${stats.path}.tmp').writeAsBytes(gzip.encode(processed.stats.toBytes()), flush: true))
        .rename(stats.path);
    await (await File('${png.path}.tmp').writeAsBytes(processed.png, flush: true)).rename(png.path);
    return _frame(f.time, png, processed.stats, _pngSize(processed.png, source: f.url));
  }
}

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

/// Top-level so the isolate closure captures only [png] and [geometry].
Future<ProcessedRadarFrame> _processOffUiIsolate(Uint8List png, RadarImageGeometry geometry) =>
    Isolate.run(() => processRadarFrame(png, geometry));
