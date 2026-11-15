import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_tokens.dart';
import '../radar/radar_echo_stats.dart';
import '../radar/radar_frame_list.dart';
import '../radar/radar_frame_processor.dart';
import '../radar/radar_source.dart';
import '../radar/radar_webp.dart';
import 'accum_grid.dart';
import 'accum_pieces.dart';

/// 累積雨量 frames as a [RadarSource]: each frame is the rolling [accumPieces]
/// sum of QPEplus native gauge grids ending at the frame time
/// (docs/design/rainfall/arch-accumulation.md §6, contract decisions 10–11).

/// Downloaded grids (gzipped), shared by every window:
/// `<root>/rain_accum_pieces_v1/<WW>h/<yyyyMMddHHmm>.dat.gz` (+ `.etag`).
const accumPieceCacheDirName = 'rain_accum_pieces_v1';

/// Rendered frames: `<root>/rain_accum_frames_v2/<W>h` (the repository's cache).
const accumFrameCacheDirName = 'rain_accum_frames_v2';

/// QPEplus publishes every native grid every 10 min.
const accumGridInterval = Duration(minutes: 10);

/// The newest grid is the [accumGridInterval] slot at least this long ago
/// (QPEplus publishes a grid a few minutes after its end time).
const accumPublishDelay = Duration(minutes: 6);

/// A cached grid this young (by its end time) is revalidated with its ETag:
/// QPEplus rewrites a grid once, 4–10 min after it first appears.
const accumRevalidateAge = Duration(minutes: 20);

/// Grids kept on disk: the 168 h window over a 168 h span, plus one hour.
const accumPieceRetention = Duration(hours: 168 + 168 + 1);

/// Grid extent (lon 118–123.5, lat 20–27, linear in degrees).
final accumBounds = LatLngBounds(const LatLng(20, 118), const LatLng(27, 123.5));

/// Frame step of a window: 10 min for 4/6/12 h, 1 h for 24/48 h, 3 h for 168 h.
Duration accumFrameStep(int windowHours) => switch (windowHours) {
      4 || 6 || 12 => accumGridInterval,
      24 || 48 => const Duration(hours: 1),
      168 => const Duration(hours: 3),
      _ => throw ArgumentError.value(windowHours, 'windowHours', 'expected one of $accumWindowHours'),
    };

DateTime _floor(DateTime t, Duration step) {
  final us = t.toUtc().microsecondsSinceEpoch;
  return DateTime.fromMicrosecondsSinceEpoch(us - us % step.inMicroseconds, isUtc: true);
}

/// The [window] span of frames ending at [newest], [step] apart, oldest first.
List<DateTime> accumFrameTimes(DateTime newest, {required Duration step, required Duration window}) => [
      for (var i = window.inMicroseconds ~/ step.inMicroseconds - 1; i >= 0; i--) newest.subtract(step * i),
    ];

/// The accumulated-rainfall source of a [windowHours] window (one of
/// [accumWindowHours]); playback span = window. Frames are step-aligned, plus
/// the newest grid slot as a last frame when it is newer than the last aligned
/// one (so the newest frame is at most [accumGridInterval] behind). [cacheRoot]
/// holds the piece cache; [clock] decides which cached grids are young enough
/// to revalidate.
RadarSource accumRadarSource(
  Dio dio, {
  required int windowHours,
  Future<Directory> Function() cacheRoot = getApplicationCacheDirectory,
  DateTime Function() clock = DateTime.now,
}) {
  final step = accumFrameStep(windowHours);
  final pieces = accumPieces(windowHours);
  final cache = _PieceCache(dio, cacheRoot, clock);
  String frameUrl(DateTime t) => accumPieceUrl(pieces.first.nativeHours, t);
  return RadarSource(
    id: 'rain_accum_${windowHours}h',
    cachePath: '$accumFrameCacheDirName/${windowHours}h',
    maxWindow: Duration(hours: windowHours),
    listFrames: ({required now, required window, cancelToken}) async {
      await cache.prune(now);
      var newest = _floor(now.toUtc().subtract(accumPublishDelay), accumGridInterval);
      // Not published yet: one slot back, once (a second miss is a failed slot).
      if (await cache.get(pieces.first.nativeHours, newest, cancelToken) == null) {
        newest = newest.subtract(accumGridInterval);
      }
      final aligned = _floor(newest, step);
      return [
        for (final t in [...accumFrameTimes(aligned, step: step, window: window), if (newest.isAfter(aligned)) newest])
          RadarFrameRef(time: t, url: frameUrl(t)),
      ];
    },
    // Only the offset-0 grid can change once its frame exists: the others ended
    // an hour or more before the frame, past [accumRevalidateAge]. Stale when
    // that grid's ETag (revalidated if young; another window may have done it)
    // is not the one the frame was made from.
    cachedFrameStale: (frame, cancel) async {
      final first = pieces.first.nativeHours;
      if (cache.young(frame.time)) await cache.get(first, frame.time, cancel);
      return await cache.etag(first, frame.time) != await cache.renderedEtag(windowHours, frame.time);
    },
    step: RadarComposedStep((frame, cancel, processSlot) async {
      final inputs = <AccumPieceInput>[];
      String? firstEtag;
      for (final p in pieces) {
        final end = frame.time.subtract(Duration(hours: p.offsetHours));
        final url = accumPieceUrl(p.nativeHours, end);
        final gz = await cache.get(p.nativeHours, end, cancel) ??
            (throw RadarDataException(url, expected: 'HTTP 200 with the QPEplus grid', actual: 'HTTP 404'));
        if (p.offsetHours == 0) firstEtag = await cache.etag(p.nativeHours, end);
        inputs.add((url: url, gz: gz));
      }
      final processed = await processSlot(() => _renderOffUiIsolate(inputs));
      await cache.setRenderedEtag(windowHours, frame.time, firstEtag);
      return processed;
    }),
  );
}

/// One downloaded grid: its URL (named in errors) and its gzipped text.
typedef AccumPieceInput = ({String url, Uint8List gz});

/// Top-level so the isolate closure captures only [inputs].
Future<ProcessedRadarFrame> _renderOffUiIsolate(List<AccumPieceInput> inputs) =>
    Isolate.run(() => renderAccumFrame(inputs));

/// RGBA words (bytes R, G, B, A in memory) of `AppPalette.rainfallMapScale`, opaque.
final _rgba = Uint32List.fromList([
  for (final c in AppPalette.rainfallMapScale)
    0xFF000000 | ((c.toARGB32() & 0xFF) << 16) | (c.toARGB32() & 0xFF00) | ((c.toARGB32() >> 16) & 0xFF),
]);

final _rowMap = mercatorRowMap(srcHeight: accumGridHeight, south: accumBounds.south, north: accumBounds.north);

/// Parses and sums [pieces], colours the sum ([accumColorIndex]), reprojects
/// rows to Web Mercator and encodes one lossless WebP (441 px wide). Pure and
/// synchronous: run it in a background isolate. A grid that does not parse
/// throws [RadarDataException] naming its URL.
ProcessedRadarFrame renderAccumFrame(List<AccumPieceInput> pieces) {
  final sum = sumAccumGrids([for (final p in pieces) _parse(p)]);
  var peak = 0;
  for (final v in sum) {
    if (v > peak) peak = v;
  }
  final webp = encodeRadarWebp(accumGridWidth, _rowMap.length, (out) {
    for (var j = 0; j < _rowMap.length; j++) {
      // Row map counts from the north edge; grid row 0 is the south edge.
      final src = (accumGridHeight - 1 - _rowMap[j]) * accumGridWidth;
      final o = j * accumGridWidth;
      for (var x = 0; x < accumGridWidth; x++) {
        final index = accumColorIndex(sum[src + x]);
        if (index >= 0) out[o + x] = _rgba[index];
      }
    }
  });
  return (
    webp: webp,
    stats: RadarEchoStats(
      frame: accumBounds,
      imageWidth: accumGridWidth,
      imageHeight: accumGridHeight,
      // No echo statistics for rain totals: significantDbz stays null.
      pixelsPerDbz: List.filled(radarEchoPalette.length, 0),
      peakMm: peak / accumRawPerMm,
    ),
  );
}

AccumGrid _parse(AccumPieceInput p) {
  try {
    return parseAccumGrid(utf8.decode(gzip.decode(p.gz)), url: p.url);
  } on FormatException catch (e) {
    throw RadarDataException(p.url, expected: 'a QPEplus 441x561 gauge grid', actual: e.message);
  }
}

final _pieceFilePattern = RegExp(r'^(\d{12})\.(dat\.gz|etag)$');

/// Gzipped grid files, written once (temp file renamed into place); a grid
/// younger than [accumRevalidateAge] is revalidated by ETag on each read.
class _PieceCache {
  _PieceCache(this._dio, this._root, this._clock);

  final Dio _dio;
  final Future<Directory> Function() _root;
  final DateTime Function() _clock;

  /// Unique temp names: two frames may fetch the same grid at once.
  var _tmpSeq = 0;

  Future<Directory> _dir() async => Directory('${(await _root()).path}/$accumPieceCacheDirName');

  static String _key(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}${two(t.hour)}${two(t.minute)}';
  }

  static DateTime _keyTime(String k) => DateTime.utc(int.parse(k.substring(0, 4)), int.parse(k.substring(4, 6)),
      int.parse(k.substring(6, 8)), int.parse(k.substring(8, 10)), int.parse(k.substring(10, 12)));

  /// Deletes every file that is not a grid (or its ETag) ending within
  /// [accumPieceRetention] before [now] (temp files included).
  Future<void> prune(DateTime now) async {
    final dir = await _dir();
    if (!await dir.exists()) return;
    final cutoff = now.toUtc().subtract(accumPieceRetention);
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File) continue;
      final match = _pieceFilePattern.firstMatch(entity.uri.pathSegments.last);
      if (match == null || _keyTime(match[1]!).isBefore(cutoff)) await entity.delete();
    }
  }

  /// Whether a cached grid ending at [end] is revalidated on read.
  bool young(DateTime end) => end.isAfter(_clock().toUtc().subtract(accumRevalidateAge));

  /// ETag of the cached [nativeHours] grid ending at [end]; '' when it has none
  /// (or is not cached).
  Future<String> etag(int nativeHours, DateTime end) async =>
      _readOrEmpty(File('${(await _dir()).path}/${_subdir(nativeHours)}/${_key(end)}.etag'));

  /// `rendered/<W>h/<key>.etag`: the offset-0 grid ETag a rendered frame of the
  /// [windowHours] window was made from.
  Future<File> _renderedFile(int windowHours, DateTime frame) async =>
      File('${(await _dir()).path}/rendered/${windowHours}h/${_key(frame)}.etag');

  /// The ETag [setRenderedEtag] stored for the frame; null when none is stored.
  Future<String?> renderedEtag(int windowHours, DateTime frame) async {
    final file = await _renderedFile(windowHours, frame);
    return await file.exists() ? file.readAsString() : null;
  }

  Future<void> setRenderedEtag(int windowHours, DateTime frame, String? etag) async {
    final file = await _renderedFile(windowHours, frame);
    await file.parent.create(recursive: true);
    await (await File('${file.path}.${_tmpSeq++}.tmp').writeAsString(etag ?? '', flush: true)).rename(file.path);
  }

  static Future<String> _readOrEmpty(File file) async => await file.exists() ? file.readAsString() : '';

  static String _subdir(int nativeHours) => '${nativeHours.toString().padLeft(2, '0')}h';

  /// Gzipped text of the [nativeHours] grid ending at [end]; null when QPEplus
  /// answers 404. Other failures throw [RadarDataException] naming the URL;
  /// the cancellation [DioException] is rethrown.
  Future<Uint8List?> get(int nativeHours, DateTime end, CancelToken? cancel) async {
    final url = accumPieceUrl(nativeHours, end);
    final dir = Directory('${(await _dir()).path}/${_subdir(nativeHours)}');
    final file = File('${dir.path}/${_key(end)}.dat.gz');
    final etagFile = File('${dir.path}/${_key(end)}.etag');
    final cached = await file.exists();
    String? etag;
    if (cached) {
      if (!young(end) || !await etagFile.exists()) return file.readAsBytes();
      etag = await etagFile.readAsString();
    }
    final Response<List<int>> response;
    try {
      response = await _dio.get<List<int>>(url,
          cancelToken: cancel,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {HttpHeaders.ifNoneMatchHeader: ?etag},
            validateStatus: (s) => s == HttpStatus.ok || s == HttpStatus.notModified || s == HttpStatus.notFound,
          ));
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw RadarDataException(url, expected: 'HTTP 200 with the QPEplus grid', actual: radarHttpFailure(e));
    }
    switch (response.statusCode) {
      case HttpStatus.notModified when cached:
        return file.readAsBytes();
      case HttpStatus.notFound:
        return null;
      case HttpStatus.ok:
        final body = response.data ??
            (throw RadarDataException(url, expected: 'QPEplus grid body', actual: 'HTTP 200 without body'));
        final gz = Uint8List.fromList(gzip.encode(body));
        await dir.create(recursive: true);
        final seq = _tmpSeq++;
        await (await File('${file.path}.$seq.tmp').writeAsBytes(gz, flush: true)).rename(file.path);
        final newEtag = response.headers.value(HttpHeaders.etagHeader);
        if (newEtag == null) {
          if (await etagFile.exists()) await etagFile.delete();
        } else {
          await (await File('${etagFile.path}.$seq.tmp').writeAsString(newEtag, flush: true)).rename(etagFile.path);
        }
        return gz;
      default:
        throw RadarDataException(url, expected: 'HTTP 200, or 304 for a cached grid', actual: 'HTTP ${response.statusCode}');
    }
  }
}
