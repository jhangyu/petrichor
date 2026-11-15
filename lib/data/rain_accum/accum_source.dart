import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/time/taiwan_time.dart';
import '../radar/radar_echo_stats.dart';
import '../radar/radar_frame_list.dart';
import '../radar/radar_frame_processor.dart';
import '../radar/radar_source.dart';
import '../radar/radar_webp.dart';
import 'accum_grid.dart';
import 'accum_pieces.dart';

/// 累積雨量 frames as a [RadarSource]: frame k of a W-hour window shows the
/// rain from the window start S to S + k·step, summed from QPEplus gauge grids
/// (contract decisions 10–12), so playback grows from 0 to the W-hour total.

/// Downloaded grids (gzipped), shared by every window:
/// `<root>/rain_accum_pieces_v1/<WW>h/<yyyyMMddHHmm>.dat.gz` (+ `.etag`).
const accumPieceCacheDirName = 'rain_accum_pieces_v1';

/// Rendered frames: `<root>/rain_accum_frames_v3/<W>h` (the repository's cache).
const accumFrameCacheDirName = 'rain_accum_frames_v3';

/// QPEplus publishes every native grid every 10 min.
const accumGridInterval = Duration(minutes: 10);

/// The newest grid is the [accumGridInterval] slot at least this long ago
/// (QPEplus publishes a grid a few minutes after its end time).
const _accumPublishDelay = Duration(minutes: 6);

/// A cached grid this young (by its end time) is revalidated with its ETag:
/// QPEplus rewrites a grid once, 4–10 min after it first appears.
const accumRevalidateAge = Duration(minutes: 20);

/// Grids kept on disk: the longest window (168 h) plus one hour of slack for
/// the newest slot.
const accumPieceRetention = Duration(hours: 168 + 1);

/// Grid extent (lon 118–123.5, lat 20–27, linear in degrees).
final accumBounds = LatLngBounds(const LatLng(20, 118), const LatLng(27, 123.5));

/// Frame step of a window: 10 min for 4/6/12 h, 1 h for 24/48 h, 3 h for 168 h.
Duration accumFrameStep(int windowHours) => switch (windowHours) {
      4 || 6 || 12 => accumGridInterval,
      24 || 48 => const Duration(hours: 1),
      168 => const Duration(hours: 3),
      _ => throw ArgumentError.value(windowHours, 'windowHours', 'expected one of $accumWindowHours'),
    };

/// Native grid summed by a window: 3 h for 168 h, else 1 h.
int _gridHours(int windowHours) => accumFrameStep(windowHours) == const Duration(hours: 3) ? 3 : 1;

/// Start S of the [windowHours] window whose newest frame is [newest] (the UI
/// labels a frame "S – frame time"; [newest] is the loop's last slot time).
DateTime accumWindowStart(DateTime newest, int windowHours) => newest.subtract(Duration(hours: windowHours));

DateTime _floor(DateTime t, Duration step) {
  final us = t.toUtc().microsecondsSinceEpoch;
  return DateTime.fromMicrosecondsSinceEpoch(us - us % step.inMicroseconds, isUtc: true);
}

/// A listed accumulation frame: the rain from [start] to [time]. Frames at the
/// same time but another [start] differ, so [start] is part of what a cached
/// frame was made from.
class AccumFrameRef extends RadarFrameRef {
  AccumFrameRef({required super.time, required super.url, required DateTime start}) : start = start.toUtc();

  final DateTime start;
}

/// Grids of the frame at [time] of a window starting at [start] (decision 12):
/// the [nativeHours] grids ending at [ends], summed; for a 10-min frame between
/// whole hours, first the partial hour from S to [partialEnd]
/// ([AccumPartialHour], from the 1 h grids ending at [partialEnd] and at S).
typedef AccumFramePlan = ({int nativeHours, DateTime? partialEnd, List<DateTime> ends});

AccumFramePlan accumFramePlan({required DateTime start, required DateTime time, required int windowHours}) {
  final grid = Duration(hours: _gridHours(windowHours));
  final into = time.difference(start).inMicroseconds % grid.inMicroseconds;
  final partialEnd = into == 0 ? null : start.add(Duration(microseconds: into));
  return (
    nativeHours: grid.inHours,
    partialEnd: partialEnd,
    ends: [for (var e = (partialEnd ?? start).add(grid); !e.isAfter(time); e = e.add(grid)) e],
  );
}

/// The accumulated-rainfall source of a [windowHours] window (one of
/// [accumWindowHours]); playback span = window. The newest frame is the newest
/// published grid slot, S = newest − window and frames are S + step·k for
/// k = 1..window/step (a shorter `window` lists the newest of them).
/// [cacheRoot] holds the piece cache; [clock] decides which cached grids are
/// young enough to revalidate.
RadarSource accumRadarSource(
  Dio dio, {
  required int windowHours,
  Future<Directory> Function() cacheRoot = getApplicationCacheDirectory,
  DateTime Function() clock = DateTime.now,
}) {
  final step = accumFrameStep(windowHours);
  final native = _gridHours(windowHours);
  final cache = _PieceCache(dio, cacheRoot, clock);
  return RadarSource(
    id: 'rain_accum_${windowHours}h',
    cachePath: '$accumFrameCacheDirName/${windowHours}h',
    maxWindow: Duration(hours: windowHours),
    listFrames: ({required now, required window, cancelToken}) async {
      await cache.prune(now);
      var newest = _floor(now.toUtc().subtract(_accumPublishDelay), accumGridInterval);
      // Not published yet: one slot back, once (a second miss is a failed slot).
      if (await cache.get(native, newest, cancelToken) == null) {
        newest = newest.subtract(accumGridInterval);
      }
      final start = accumWindowStart(newest, windowHours);
      final count = Duration(hours: windowHours).inMicroseconds ~/ step.inMicroseconds;
      final listed = window.inMicroseconds ~/ step.inMicroseconds;
      return [
        for (var k = count - listed + 1; k <= count; k++)
          AccumFrameRef(time: start.add(step * k), url: accumPieceUrl(native, start.add(step * k)), start: start),
      ];
    },
    // Of a frame's grids only the one ending at the frame time can change once
    // the frame exists: the others ended 10 min or more before it and were
    // past [accumRevalidateAge] at render time (a frame is made at least
    // [_accumPublishDelay] after its time). Stale when that grid's ETag
    // (revalidated if young; another window may have done it) or S is not what
    // the frame was made from.
    cachedFrameStale: (frame, cancel) async {
      final start = (frame as AccumFrameRef).start;
      if (cache.young(frame.time)) await cache.get(native, frame.time, cancel);
      return await cache.signature(native, start, frame.time) != await cache.renderedSignature(windowHours, frame.time);
    },
    step: RadarComposedStep((frame, cancel, processSlot) async {
      final start = (frame as AccumFrameRef).start;
      final plan = accumFramePlan(start: start, time: frame.time, windowHours: windowHours);
      Future<AccumPieceInput> input(int nativeHours, DateTime end) async {
        final url = accumPieceUrl(nativeHours, end);
        final gz = await cache.get(nativeHours, end, cancel) ??
            (throw RadarDataException(url, expected: 'HTTP 200 with the QPEplus grid', actual: 'HTTP 404'));
        return (url: url, gz: gz);
      }

      final partialEnd = plan.partialEnd;
      final [partial, whole] = await Future.wait([
        Future.wait([if (partialEnd != null) ...[input(1, partialEnd), input(1, start)]]),
        Future.wait([for (final end in plan.ends) input(plan.nativeHours, end)]),
      ]);
      final signature = await cache.signature(native, start, frame.time);
      final processed = await processSlot(() => _renderOffUiIsolate(
          whole,
          partialEnd == null
              ? null
              : (end: partial[0], start: partial[1], minutes: partialEnd.difference(start).inMinutes)));
      await cache.setRenderedSignature(windowHours, frame.time, signature);
      return processed;
    }),
  );
}

/// One downloaded grid: its URL (named in errors) and its gzipped text.
typedef AccumPieceInput = ({String url, Uint8List gz});

/// The 1 h grids of a frame's first partial hour ([AccumPartialHour]).
typedef AccumPartialInput = ({AccumPieceInput end, AccumPieceInput start, int minutes});

/// Top-level so the isolate closure captures only its arguments.
Future<ProcessedRadarFrame> _renderOffUiIsolate(List<AccumPieceInput> whole, AccumPartialInput? partial) =>
    Isolate.run(() => renderAccumFrame(whole, partial: partial));

/// RGBA words (bytes R, G, B, A in memory) of `AppPalette.rainfallMapScale`, opaque.
final _rgba = Uint32List.fromList([
  for (final c in AppPalette.rainfallMapScale) rgbToRgbaWord(c.toARGB32()),
]);

final _rowMap = mercatorRowMap(srcHeight: accumGridHeight, south: accumBounds.south, north: accumBounds.north);

/// Parses the grids and totals them ([accumFrameSum]), colours the total
/// ([accumColorIndex]), reprojects rows to Web Mercator and encodes one
/// lossless WebP (441 px wide); peakMm is the highest total. Pure and
/// synchronous: run it in a background isolate. A grid that does not parse
/// throws [RadarDataException] naming its URL.
ProcessedRadarFrame renderAccumFrame(List<AccumPieceInput> whole, {AccumPartialInput? partial}) {
  final sum = accumFrameSum([for (final p in whole) _parse(p)],
      partial: partial == null
          ? null
          : (end: _parse(partial.end), start: _parse(partial.start), minutes: partial.minutes));
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

final _pieceFilePattern = RegExp(r'^(\d{12})\.(dat\.gz|etag|sig)$');

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

  /// Deletes every file that is not a grid (or its ETag) ending within
  /// [accumPieceRetention] before [now] (temp files included).
  Future<void> prune(DateTime now) async {
    final dir = await _dir();
    if (!await dir.exists()) return;
    final cutoff = now.toUtc().subtract(accumPieceRetention);
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File) continue;
      final match = _pieceFilePattern.firstMatch(entity.uri.pathSegments.last);
      if (match == null || parseUtcStamp(match[1]!).isBefore(cutoff)) await entity.delete();
    }
  }

  /// Whether a cached grid ending at [end] is revalidated on read.
  bool young(DateTime end) => end.isAfter(_clock().toUtc().subtract(accumRevalidateAge));

  /// ETag of the cached [nativeHours] grid ending at [end]; '' when it has none
  /// (or is not cached).
  Future<String> etag(int nativeHours, DateTime end) async =>
      _readOrEmpty(File('${(await _dir()).path}/${_subdir(nativeHours)}/${formatUtcStamp(end, seconds: false)}.etag'));

  /// What a frame from [start] to [end] is made from: S and the ETag of the
  /// [nativeHours] grid ending at [end].
  Future<String> signature(int nativeHours, DateTime start, DateTime end) async =>
      '${formatUtcStamp(start, seconds: false)} ${await etag(nativeHours, end)}';

  /// `rendered/<W>h/<key>.sig`: the [signature] a rendered frame of the
  /// [windowHours] window was made from.
  Future<File> _renderedFile(int windowHours, DateTime frame) async =>
      File('${(await _dir()).path}/rendered/${windowHours}h/${formatUtcStamp(frame, seconds: false)}.sig');

  /// The signature [setRenderedSignature] stored for the frame; null when none is stored.
  Future<String?> renderedSignature(int windowHours, DateTime frame) async {
    final file = await _renderedFile(windowHours, frame);
    return await file.exists() ? file.readAsString() : null;
  }

  Future<void> setRenderedSignature(int windowHours, DateTime frame, String signature) async {
    final file = await _renderedFile(windowHours, frame);
    await file.parent.create(recursive: true);
    await writeAtomic(file, utf8.encode(signature), tmpSuffix: '.${_tmpSeq++}.tmp');
  }

  static Future<String> _readOrEmpty(File file) async => await file.exists() ? file.readAsString() : '';

  static String _subdir(int nativeHours) => '${twoDigits(nativeHours)}h';

  /// Gzipped text of the [nativeHours] grid ending at [end]; null when QPEplus
  /// answers 404. Other failures throw [RadarDataException] naming the URL;
  /// the cancellation [DioException] is rethrown.
  Future<Uint8List?> get(int nativeHours, DateTime end, CancelToken? cancel) async {
    final url = accumPieceUrl(nativeHours, end);
    final dir = Directory('${(await _dir()).path}/${_subdir(nativeHours)}');
    final file = File('${dir.path}/${formatUtcStamp(end, seconds: false)}.dat.gz');
    final etagFile = File('${dir.path}/${formatUtcStamp(end, seconds: false)}.etag');
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
        await writeAtomic(file, gz, tmpSuffix: '.$seq.tmp');
        final newEtag = response.headers.value(HttpHeaders.etagHeader);
        if (newEtag == null) {
          if (await etagFile.exists()) await etagFile.delete();
        } else {
          await writeAtomic(etagFile, utf8.encode(newEtag), tmpSuffix: '.$seq.tmp');
        }
        return gz;
      default:
        throw RadarDataException(url, expected: 'HTTP 200, or 304 for a cached grid', actual: 'HTTP ${response.statusCode}');
    }
  }
}
