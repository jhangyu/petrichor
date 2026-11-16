import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import 'radar_bounds.dart';
import 'radar_frame_list.dart';
import 'radar_frame_processor.dart';

/// Cache sub-directory of the radar loops (one sub-directory per source,
/// see [RadarSource.website]); the suffix changes
/// whenever processing output changes, so frames made by an older pipeline are
/// never shown.
const radarFrameCacheDirName = 'radar_webp_2048_v3';

/// Writes [bytes] to `<target><temporarySuffix>` (flushed), then renames it onto
/// [target], so [target] is never seen half-written. Leftover temp files fail
/// the cache file patterns, so cache pruning deletes them.
Future<void> writeAtomic(File target, List<int> bytes, {String temporarySuffix = '.tmp'}) async {
  final tmp = await File('${target.path}$temporarySuffix').writeAsBytes(bytes, flush: true);
  await tmp.rename(target.path);
}

/// Radar data could not be obtained or did not have the expected shape.
class RadarDataException implements Exception {
  final String url;
  final String expected;
  final Object? actual;

  const RadarDataException(this.url, {required this.expected, required this.actual});

  @override
  String toString() => 'RadarDataException($url): expected $expected, got $actual';
}

/// What a failed (not cancelled) request got, for [RadarDataException.actual].
String radarHttpFailure(DioException e) =>
    switch (e.response) { final r? => 'HTTP ${r.statusCode}', null => '${e.type.name}: ${e.message}' };

/// The frame list was fetched but has no frame within the window (the source
/// stopped updating); every other [RadarDataException] means the data could
/// not be obtained.
class RadarStaleListException extends RadarDataException {
  const RadarStaleListException(super.url, {required super.expected, required super.actual});
}

/// Frames of the [window] span ending at a source's newest frame, oldest
/// first. Throws [RadarDataException] when they cannot be obtained,
/// [RadarStaleListException] when the source has no frame that recent, and the
/// cancellation [DioException] as is once [cancelToken] fires.
typedef RadarFrameLister = Future<List<RadarFrameReference>> Function(
    {required DateTime now, required Duration window, CancelToken? cancelToken});

/// Runs [work] in one of the repository's processing slots (radar_frame_repository.dart);
/// throws the cancellation error instead once the frame is cancelled
/// (before or while [work] runs).
typedef RadarProcessSlot = Future<ProcessedRadarFrame> Function(Future<ProcessedRadarFrame> Function() work);

/// How a source obtains the processed bytes of one listed frame.
sealed class RadarFrameStep {
  const RadarFrameStep();
}

/// Download the frame PNG at its URL, then `processRadarFrame` it with
/// [geometry] (the repository's download and process).
final class RadarPngStep extends RadarFrameStep {
  final RadarImageGeometry geometry;

  const RadarPngStep(this.geometry);
}

/// The source makes the frame itself (e.g. from several downloads): [obtain]
/// runs its heavy work through `processSlot`, stops with the cancellation
/// error once `cancel` fires, and reports failures as [RadarDataException]
/// naming the URL (other exceptions are reported against the frame's URL).
final class RadarComposedStep extends RadarFrameStep {
  final Future<ProcessedRadarFrame> Function(RadarFrameReference frame, CancelToken cancel, RadarProcessSlot processSlot) obtain;

  const RadarComposedStep(this.obtain);
}

/// A frame source of the radar pipeline (frame list → [step] → cache →
/// stream, one screen). A source differs in its frame list, its frame step,
/// its cache directory and its longest look-back.
class RadarSource {
  /// Dataset id.
  final String id;

  /// Frame cache directory, relative to the cache root.
  final String cachePath;

  /// Longest look-back the source offers (what its frame list covers).
  final Duration maxWindow;

  final RadarFrameLister listFrames;
  final RadarFrameStep step;

  /// Whether the cached frame of `frame` was made from data that has changed
  /// since (it is then made again by [step]). Throws [RadarDataException] when
  /// that cannot be checked (the slot fails). Null: cached frames never change.
  final Future<bool> Function(RadarFrameReference frame, CancelToken cancel)? cachedFrameStale;

  const RadarSource(
      {required this.id,
      required this.cachePath,
      required this.maxWindow,
      required this.listFrames,
      required this.step,
      this.cachedFrameStale});

  /// A CWA website radar loop: frames (time + PNG URL) listed in the JS at
  /// [listUrl], each processed with [geometry]; cached under
  /// [radarFrameCacheDirName]/[id].
  factory RadarSource.website(Dio dio,
          {required String id,
          required String listUrl,
          required Duration maxWindow,
          required List<RadarFrameReference> Function(String scriptText) parse,
          required RadarImageGeometry geometry}) =>
      RadarSource(
        id: id,
        cachePath: '$radarFrameCacheDirName/$id',
        maxWindow: maxWindow,
        listFrames: ({required now, required window, cancelToken}) =>
            _listWebsiteFrames(dio, id, listUrl, parse, now: now, window: window, cancelToken: cancelToken),
        step: RadarPngStep(geometry),
      );

  /// Composite (全台合成): website `CV1_3600_` loop, 10-minute frames, 24 h.
  factory RadarSource.composite(Dio dio) => RadarSource.website(dio,
      id: AppConstants.radarTaiwan,
      listUrl: radarFrameListUrl,
      maxWindow: radarWebsiteMaxWindow,
      parse: parseRadarFrameList,
      geometry: websiteRadarGeometry);

  /// Station radar: website station list, ~108 s frames, 6 h.
  factory RadarSource.station(Dio dio, RadarStation station) => RadarSource.website(dio,
      id: station.datasetId,
      listUrl: radarStationListUrl,
      maxWindow: radarStationMaxWindow,
      parse: (scriptText) => parseRadarStationList(scriptText, code: station.code),
      geometry: stationRadarGeometry(stationRadarBounds(station.site, radiusKm: radarStationRangeKm)));
}

/// [RadarFrameLister] of a website loop: the JS list at [listUrl], parsed by [parse].
Future<List<RadarFrameReference>> _listWebsiteFrames(
    Dio dio, String id, String listUrl, List<RadarFrameReference> Function(String scriptText) parse,
    {required DateTime now, required Duration window, CancelToken? cancelToken}) async {
  final Response<String> response;
  try {
    response = await dio.get<String>(listUrl, options: Options(responseType: ResponseType.plain), cancelToken: cancelToken);
  } on DioException catch (e) {
    if (CancelToken.isCancel(e)) rethrow;
    throw RadarDataException(listUrl, expected: 'HTTP 200 with the frame list', actual: radarHttpFailure(e));
  }
  final scriptText = response.data ??
      (throw RadarDataException(listUrl, expected: 'JS body', actual: 'HTTP ${response.statusCode} without body'));
  final List<RadarFrameReference> all;
  try {
    all = parse(scriptText);
  } on FormatException catch (e) {
    throw RadarDataException(listUrl, expected: 'a frame list for $id', actual: e);
  }
  final frames = selectRadarFrameWindow(all, now: now, window: window);
  if (frames.isEmpty) {
    throw RadarStaleListException(listUrl, expected: 'frames newer than ${now.toUtc().subtract(window)} for $id', actual: 'none');
  }
  return frames;
}
