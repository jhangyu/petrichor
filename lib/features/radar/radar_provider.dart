import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/app_constants.dart';
import '../../data/radar/radar_bounds.dart';
import '../../data/radar/radar_frame_list.dart';
import '../../data/radar/radar_frame_repository.dart';

/// Clock for the frame window; override in tests.
final radarClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final radarFrameRepositoryProvider = Provider<RadarFrameRepository>((ref) => RadarFrameRepository(
      ref.watch(fileApiDioProvider),
      cacheRoot: getApplicationCacheDirectory,
      clock: ref.watch(radarClockProvider),
    ));

/// Look-back window in frames (10 min each); the UI sets it, 1..[radarMaxWindowFrames].
class RadarWindowFrames extends Notifier<int> {
  @override
  int build() => radarDefaultWindowFrames;

  void set(int frames) {
    if (frames < 1 || frames > radarMaxWindowFrames) {
      throw RangeError.range(frames, 1, radarMaxWindowFrames, 'frames');
    }
    state = frames;
  }
}

final radarWindowFramesProvider = NotifierProvider<RadarWindowFrames, int>(RadarWindowFrames.new);

/// Website radar loop (oldest first; each frame = bands with bounds), credit
/// [radarSourceCredit]. Refreshes when first watched (screen open) or when the
/// window changes; a user refresh is `ref.invalidate(radarFramesProvider)`.
/// No timer/polling.
final radarFramesProvider = FutureProvider.autoDispose<List<RadarFrame>>((ref) =>
    ref.watch(radarFrameRepositoryProvider).refresh(windowFrames: ref.watch(radarWindowFramesProvider)));

/// Latest open-data station radar image (O-A0084-00x) with bounds from the response.
final openDataRadarProvider = FutureProvider.autoDispose.family<OpenDataRadarImage, String>((ref, datasetId) async {
  if (!AppConstants.hasApiKey) {
    throw RadarDataException(datasetId, expected: 'CWA_API_KEY via --dart-define', actual: 'none');
  }
  final response = await ref.watch(fileApiDioProvider).get<String>(
        AppConstants.radarApiUrl(datasetId, AppConstants.cwaApiKey),
        options: Options(responseType: ResponseType.plain),
      );
  final text = response.data ??
      (throw RadarDataException(datasetId, expected: 'JSON body', actual: 'HTTP ${response.statusCode} without body'));
  final body = jsonDecode(text);
  if (body is! Map<String, dynamic>) {
    throw RadarDataException(datasetId, expected: 'JSON object', actual: body.runtimeType);
  }
  return OpenDataRadarImage.fromJson(datasetId, body);
});
