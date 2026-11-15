import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import 'radar_bounds.dart';
import 'radar_frame_list.dart';

/// Radar data could not be obtained or did not have the expected shape.
class RadarDataException implements Exception {
  final String source;
  final String expected;
  final Object? actual;

  const RadarDataException(this.source, {required this.expected, required this.actual});

  @override
  String toString() => 'RadarDataException($source): expected $expected, got $actual';
}

/// What a failed (not cancelled) request got, for [RadarDataException.actual].
String radarHttpFailure(DioException e) =>
    switch (e.response) { final r? => 'HTTP ${r.statusCode}', null => '${e.type.name}: ${e.message}' };

/// The frame list was fetched but has no frame within the window (the source
/// stopped updating); every other [RadarDataException] means the data could
/// not be obtained.
class RadarStaleListException extends RadarDataException {
  const RadarStaleListException(super.source, {required super.expected, required super.actual});
}

/// A CWA website radar loop. Every source's frames go through the same
/// pipeline (download → `processRadarFrame` → cache → stream) and the same
/// screen; a source only differs in its frame list (native cadence, regular
/// or not) and its longest look-back.
class RadarSource {
  /// Dataset id; also the source's cache sub-directory.
  final String id;
  final String listUrl;

  /// Longest look-back the source offers (what its frame list covers).
  final Duration maxWindow;

  /// Frames (time + URL + processing) listed in the JS at [listUrl].
  final List<RadarFrameRef> Function(String js) parse;
  final Dio _dio;

  RadarSource(this._dio, {required this.id, required this.listUrl, required this.maxWindow, required this.parse});

  /// Composite (全台合成): website `CV1_3600_` loop, 10-minute frames, 24 h.
  factory RadarSource.composite(Dio dio) => RadarSource(dio,
      id: AppConstants.radarTaiwan, listUrl: radarFrameListUrl, maxWindow: radarWebsiteMaxWindow, parse: parseRadarFrameList);

  /// Station radar: website station list, ~108 s frames, 6 h.
  factory RadarSource.station(Dio dio, RadarStation station) {
    final geometry = stationRadarGeometry(stationRadarBounds(station.site, radiusKm: radarStationRangeKm));
    return RadarSource(dio,
        id: station.datasetId,
        listUrl: radarStationListUrl,
        maxWindow: radarStationMaxWindow,
        parse: (js) => parseRadarStationList(js, code: station.code, geometry: geometry));
  }

  /// Frames of the [window] ending at the newest listed frame, oldest first.
  /// Throws [RadarDataException] when the list cannot be obtained,
  /// [RadarStaleListException] when it has no frame that recent, and the
  /// cancellation [DioException] as is once [cancelToken] fires.
  Future<List<RadarFrameRef>> listFrames({required DateTime now, required Duration window, CancelToken? cancelToken}) async {
    final Response<String> response;
    try {
      response =
          await _dio.get<String>(listUrl, options: Options(responseType: ResponseType.plain), cancelToken: cancelToken);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw RadarDataException(listUrl, expected: 'HTTP 200 with the frame list', actual: radarHttpFailure(e));
    }
    final js = response.data ??
        (throw RadarDataException(listUrl, expected: 'JS body', actual: 'HTTP ${response.statusCode} without body'));
    final List<RadarFrameRef> all;
    try {
      all = parse(js);
    } on FormatException catch (e) {
      throw RadarDataException(listUrl, expected: 'a frame list for $id', actual: e);
    }
    final frames = selectRadarFrameWindow(all, now: now, window: window);
    if (frames.isEmpty) {
      throw RadarStaleListException(listUrl, expected: 'frames newer than ${now.toUtc().subtract(window)} for $id', actual: 'none');
    }
    return frames;
  }
}
