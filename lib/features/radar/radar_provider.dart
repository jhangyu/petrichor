import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/app_constants.dart';
import '../../data/radar/radar_bounds.dart';
import '../../data/radar/radar_frame_repository.dart';
import '../../data/radar/radar_source.dart';
import '../location/place_provider.dart' show sharedPreferencesProvider;
import 'radar_playback.dart';

/// Overlay opacity slider: 10–100 % in 10 % steps, default 60 %.
const radarOpacityMinPercent = 10;
const radarOpacityMaxPercent = 100;
const radarOpacityStepPercent = 10;
const radarOpacityDefaultPercent = 60;

bool _isOpacityPercent(int p) =>
    p >= radarOpacityMinPercent && p <= radarOpacityMaxPercent && (p - radarOpacityMinPercent) % radarOpacityStepPercent == 0;

const _opacityRange = '$radarOpacityMinPercent–$radarOpacityMaxPercent in steps of $radarOpacityStepPercent';

/// Stored overlay opacity is corrupt or could not be written ([key] = storage key).
class StoredRadarOpacityException implements Exception {
  final String key;
  final String message;
  const StoredRadarOpacityException(this.key, this.message);

  @override
  String toString() => 'StoredRadarOpacityException($key): $message';
}

/// Stored data is deterministic: a retry never repairs it.
Duration? _noRetry(int retryCount, Object error) => null;

/// Overlay opacity in percent, remembered across restarts. A corrupt stored
/// value is an [AsyncError]; [RadarOpacity.set] overwrites it and recovers.
final radarOpacityProvider = AsyncNotifierProvider<RadarOpacity, int>(RadarOpacity.new, retry: _noRetry);

class RadarOpacity extends AsyncNotifier<int> {
  static const key = 'radar.opacity';

  @override
  Future<int> build() async {
    final Object? raw = (await ref.watch(sharedPreferencesProvider.future)).get(key);
    return switch (raw) {
      null => radarOpacityDefaultPercent,
      final int p when _isOpacityPercent(p) => p,
      _ => throw StoredRadarOpacityException(key, '儲存資料損毀：期望 $_opacityRange 的整數，實際「$raw」'),
    };
  }

  /// Shows [percent] at once, then stores it; a failed write becomes the state.
  Future<void> set(int percent) async {
    if (!_isOpacityPercent(percent)) throw ArgumentError.value(percent, 'percent', 'expected $_opacityRange');
    state = AsyncData(percent);
    final written = await AsyncValue.guard(() async {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      if (!await prefs.setInt(key, percent)) {
        throw StoredRadarOpacityException(key, '寫入失敗：期望 true，實際 false');
      }
      return percent;
    });
    // A later set() may have replaced the state meanwhile; only a failure overrides it.
    if (written is AsyncError || state.value == percent) state = written;
  }
}

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

/// Slots of one source, updated on every slot change (newest first, then
/// oldest→newest). Loads when first watched (screen open) or when the window
/// changes; a user refresh is `ref.invalidate(radarLoopProvider(id))`. No
/// timer/polling.
final radarLoopProvider = StreamProvider.autoDispose.family<RadarLoop, String>((ref, id) {
  final source = ref.watch(radarSourceProvider(id));
  return ref
      .watch(radarFrameRepositoryProvider)
      .watch(source, window: radarEffectiveWindow(ref.watch(radarWindowProvider), source));
});
