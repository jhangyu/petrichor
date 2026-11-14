import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/app_constants.dart';
import '../../data/radar/radar_bounds.dart';
import '../../data/radar/radar_frame_repository.dart';

/// Clock for the frame window; override in tests.
final radarClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final radarFrameRepositoryProvider = Provider<RadarFrameRepository>((ref) => RadarFrameRepository(
      ref.watch(fileApiDioProvider),
      cacheRoot: getApplicationCacheDirectory,
      clock: ref.watch(radarClockProvider),
    ));

/// Website radar loop (last 2 h, oldest first), extent `websiteRadarBounds`,
/// credit [radarSourceCredit]. Refreshes when first watched (screen open);
/// a user refresh is `ref.invalidate(radarFramesProvider)`. No timer/polling.
final radarFramesProvider =
    FutureProvider.autoDispose<List<RadarFrame>>((ref) => ref.watch(radarFrameRepositoryProvider).refresh());

/// Latest open-data radar image with its geographic bounds from the response.
final openDataRadarProvider = FutureProvider.autoDispose.family<OpenDataRadarImage, String>((ref, datasetId) async {
  if (!AppConstants.hasApiKey) {
    throw StateError('$datasetId: expected CWA_API_KEY via --dart-define, got none');
  }
  final response = await ref.watch(fileApiDioProvider).get<String>(
        AppConstants.radarApiUrl(datasetId, AppConstants.cwaApiKey),
        options: Options(responseType: ResponseType.plain),
      );
  final body = jsonDecode(response.data ?? 'null');
  if (body is! Map<String, dynamic>) {
    throw FormatException('$datasetId: expected JSON object, got ${body.runtimeType}');
  }
  return OpenDataRadarImage.fromJson(datasetId, body);
});
