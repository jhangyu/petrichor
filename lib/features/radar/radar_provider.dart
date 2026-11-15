import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/app_constants.dart';
import '../../data/radar/radar_frame_list.dart';
import '../../data/radar/radar_frame_repository.dart';
import '../../data/radar/radar_source.dart';

/// Clock for the frame window and cache retention; override in tests.
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

/// Source by dataset id: the website loop for [AppConstants.radarTaiwan],
/// open-data station images for the O-A0084-00x ids.
final radarSourceProvider = Provider.family<RadarSource, String>((ref, id) => id == AppConstants.radarTaiwan
    ? WebsiteRadarSource(ref.watch(fileApiDioProvider))
    : StationRadarSource(ref.watch(fileApiDioProvider), id));

/// Frames of one source, updated as each frame is ready (newest first). Loads
/// when first watched (screen open) or when the window changes; a user refresh
/// is `ref.invalidate(radarLoopProvider(id))`. No timer/polling.
final radarLoopProvider = StreamProvider.autoDispose.family<RadarLoop, String>((ref, id) => ref
    .watch(radarFrameRepositoryProvider)
    .watch(ref.watch(radarSourceProvider(id)), windowFrames: ref.watch(radarWindowFramesProvider)));
