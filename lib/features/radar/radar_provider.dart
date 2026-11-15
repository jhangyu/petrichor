import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/app_constants.dart';
import '../../data/radar/radar_bounds.dart';
import '../../data/radar/radar_frame_repository.dart';
import '../../data/radar/radar_source.dart';
import 'radar_playback.dart';

/// Clock for the frame window and cache retention; override in tests.
final radarClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final radarFrameRepositoryProvider = Provider<RadarFrameRepository>((ref) => RadarFrameRepository(
      ref.watch(fileApiDioProvider),
      cacheRoot: getApplicationCacheDirectory,
      clock: ref.watch(radarClockProvider),
    ));

/// Selected look-back, one of [radarWindowOptions]; each source applies it
/// capped at its own `maxWindow` ([radarEffectiveWindow]).
class RadarWindow extends Notifier<Duration> {
  @override
  Duration build() => radarDefaultWindow;

  void set(Duration window) {
    if (!radarWindowOptions.contains(window)) {
      throw ArgumentError.value(window, 'window', 'expected one of $radarWindowOptions');
    }
    state = window;
  }
}

final radarWindowProvider = NotifierProvider<RadarWindow, Duration>(RadarWindow.new);

/// The look-back [source] shows for the [selected] one.
Duration radarEffectiveWindow(Duration selected, RadarSource source) =>
    selected > source.maxWindow ? source.maxWindow : selected;

/// Source by dataset id: the composite loop for [AppConstants.radarTaiwan],
/// a station loop for each [radarStations] id.
final radarSourceProvider = Provider.family<RadarSource, String>((ref, id) {
  final dio = ref.watch(fileApiDioProvider);
  if (id == AppConstants.radarTaiwan) return RadarSource.composite(dio);
  final station = radarStations.where((s) => s.datasetId == id).firstOrNull ??
      (throw ArgumentError.value(id, 'id', 'expected ${AppConstants.radarTaiwan} or a radarStations dataset id'));
  return RadarSource.station(dio, station);
});

/// Frames of one source, updated as each frame is ready (newest first). Loads
/// when first watched (screen open) or when the window changes; a user refresh
/// is `ref.invalidate(radarLoopProvider(id))`. No timer/polling.
final radarLoopProvider = StreamProvider.autoDispose.family<RadarLoop, String>((ref, id) {
  final source = ref.watch(radarSourceProvider(id));
  return ref
      .watch(radarFrameRepositoryProvider)
      .watch(source, window: radarEffectiveWindow(ref.watch(radarWindowProvider), source));
});
