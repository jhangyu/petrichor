import 'dart:convert';

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

/// A radar image source. Every source's frames go through the same pipeline
/// (download → `processRadarFrame` → cache → stream) and the same screen; a
/// source only says which frames exist and how to process them.
abstract interface class RadarSource {
  /// Dataset id; also the source's cache sub-directory.
  String get id;

  /// Frames of the [windowFrames] x [radarFrameStep] window ending at the
  /// newest frame, any order. Throws when the list cannot be obtained.
  Future<List<RadarFrameRef>> listFrames({required DateTime now, required int windowFrames});
}

/// Website `CV1_3600_` loop (全台合成): ~24 h of 10-minute frames.
class WebsiteRadarSource implements RadarSource {
  final Dio _dio;

  WebsiteRadarSource(this._dio);

  @override
  String get id => AppConstants.radarTaiwan;

  @override
  Future<List<RadarFrameRef>> listFrames({required DateTime now, required int windowFrames}) async {
    final response = await _dio.get<String>(radarFrameListUrl, options: Options(responseType: ResponseType.plain));
    final js = response.data ??
        (throw RadarDataException(radarFrameListUrl, expected: 'JS body', actual: 'HTTP ${response.statusCode} without body'));
    final window = selectRadarFrameWindow(parseRadarFrameList(js), now: now, windowFrames: windowFrames);
    if (window.isEmpty) {
      throw RadarDataException(radarFrameListUrl,
          expected: 'frames newer than ${now.toUtc().subtract(radarFrameStep * windowFrames)}', actual: 'none');
    }
    return window;
  }
}

/// Open-data station radar (O-A0084-00x): the file API publishes only the
/// latest image, so the list is that one frame.
class StationRadarSource implements RadarSource {
  final Dio _dio;

  @override
  final String id;

  StationRadarSource(this._dio, this.id);

  @override
  Future<List<RadarFrameRef>> listFrames({required DateTime now, required int windowFrames}) async {
    if (!AppConstants.hasApiKey) {
      throw RadarDataException(id, expected: 'CWA_API_KEY via --dart-define', actual: 'none');
    }
    final response = await _dio.get<String>(
      AppConstants.radarApiUrl(id, AppConstants.cwaApiKey),
      options: Options(responseType: ResponseType.plain),
    );
    final text = response.data ??
        (throw RadarDataException(id, expected: 'JSON body', actual: 'HTTP ${response.statusCode} without body'));
    final body = jsonDecode(text);
    if (body is! Map<String, dynamic>) {
      throw RadarDataException(id, expected: 'JSON object', actual: body.runtimeType);
    }
    final image = OpenDataRadarImage.fromJson(id, body);
    return [RadarFrameRef(time: image.time, url: image.imageUrl, geometry: stationRadarGeometry(image.bounds))];
  }
}
