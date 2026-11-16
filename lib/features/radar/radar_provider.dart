import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/storage/stored_setting.dart';
import '../../data/radar/radar_bounds.dart';
import '../../data/radar/radar_frame_repository.dart';
import '../../data/radar/radar_source.dart';
import 'radar_playback.dart';

/// Overlay opacity slider: 10–100 % in 10 % steps, default 60 %.
const radarOpacityMinPercent = 10;
const radarOpacityMaxPercent = 100;
const radarOpacityStepPercent = 10;
const radarOpacityDefaultPercent = 60;

bool _isOpacityPercent(int p) =>
    p >= radarOpacityMinPercent && p <= radarOpacityMaxPercent && (p - radarOpacityMinPercent) % radarOpacityStepPercent == 0;

/// One playback setting of one [RadarGroup], remembered across restarts as an
/// int under `radar.<group>.<name>`.
abstract class RadarSetting<T> extends IntSetting<T> {
  RadarSetting(this.group);

  final RadarGroup group;

  /// Last key segment, e.g. `opacity`.
  String get name;

  @override
  String get key => 'radar.${group.name}.$name';
}

/// Overlay opacity in percent.
class RadarOpacitySetting extends RadarSetting<int> {
  RadarOpacitySetting(super.group);

  @override
  String get name => 'opacity';
  @override
  int get defaultValue => radarOpacityDefaultPercent;
  @override
  String get expected => '$radarOpacityMinPercent–$radarOpacityMaxPercent in steps of $radarOpacityStepPercent';
  @override
  int? fromStored(int stored) => _isOpacityPercent(stored) ? stored : null;
  @override
  int toStored(int value) => value;
}

/// Playback speed in frames per second, one of [radarFpsOptions].
class RadarFps extends RadarSetting<int> {
  RadarFps(super.group);

  @override
  String get name => 'fps';
  @override
  int get defaultValue => group.defaultFps;
  @override
  String get expected => 'one of $radarFpsOptions';
  @override
  int? fromStored(int stored) => radarFpsOptions.contains(stored) ? stored : null;
  @override
  int toStored(int value) => value;
}

/// Whether playback restarts after the newest frame (stored as 1 / 0).
class RadarRepeatSetting extends RadarSetting<bool> {
  RadarRepeatSetting(super.group);

  @override
  String get name => 'repeat';
  @override
  bool get defaultValue => true;
  @override
  String get expected => '0 or 1';
  @override
  bool? fromStored(int stored) => switch (stored) { 1 => true, 0 => false, _ => null };
  @override
  int toStored(bool value) => value ? 1 : 0;
}

/// Selected look-back, one of [radarWindowOptions] (stored in minutes); each
/// source applies it capped at its own `maxWindow` ([radarEffectiveWindow]).
class RadarWindowSetting extends RadarSetting<Duration> {
  RadarWindowSetting(super.group);

  @override
  String get name => 'windowMinutes';
  @override
  Duration get defaultValue => group.defaultWindow;
  @override
  String get expected => 'one of ${[for (final w in radarWindowOptions) w.inMinutes]} minutes';
  @override
  Duration? fromStored(int stored) =>
      radarWindowOptions.where((w) => w.inMinutes == stored).firstOrNull;
  @override
  int toStored(Duration value) => value.inMinutes;
}

final radarOpacityProvider = AsyncNotifierProvider.family<RadarOpacitySetting, int, RadarGroup>(RadarOpacitySetting.new, retry: noRetry);
final radarFpsProvider = AsyncNotifierProvider.family<RadarFps, int, RadarGroup>(RadarFps.new, retry: noRetry);
final radarRepeatProvider = AsyncNotifierProvider.family<RadarRepeatSetting, bool, RadarGroup>(RadarRepeatSetting.new, retry: noRetry);
final radarWindowProvider = AsyncNotifierProvider.family<RadarWindowSetting, Duration, RadarGroup>(RadarWindowSetting.new, retry: noRetry);

/// Settings group of the source with dataset [id].
RadarGroup radarGroupOf(String id) => id == AppConstants.radarTaiwan ? RadarGroup.taiwan : RadarGroup.regional;

/// Clock for the frame window and cache retention; override in tests.
final radarClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final radarFrameRepositoryProvider = Provider<RadarFrameRepository>((ref) => RadarFrameRepository(
      ref.watch(webDioProvider),
      cacheRoot: getApplicationCacheDirectory,
      clock: ref.watch(radarClockProvider),
    ));

/// The look-back [source] shows for the [selected] one.
Duration radarEffectiveWindow(Duration selected, RadarSource source) =>
    selected > source.maxWindow ? source.maxWindow : selected;

/// Source by dataset id: the composite loop for [AppConstants.radarTaiwan],
/// a station loop for each [radarStations] id.
final radarSourceProvider = Provider.family<RadarSource, String>((ref, id) {
  final dio = ref.watch(webDioProvider);
  if (id == AppConstants.radarTaiwan) return RadarSource.composite(dio);
  final station = radarStationById(id) ??
      (throw ArgumentError.value(id, 'id', 'expected ${AppConstants.radarTaiwan} or a radarStations dataset id'));
  return RadarSource.station(dio, station);
});

/// Slots of one source, updated on every slot change (newest first, then
/// oldest→newest). Loads when first watched (screen open) or when the window
/// changes; a user refresh is `ref.invalidate(radarLoopProvider(id))`. No
/// timer/polling.
final radarLoopProvider = StreamProvider.autoDispose.family<RadarLoop, String>((ref, id) {
  final source = ref.watch(radarSourceProvider(id));
  final selected = ref.watch(radarWindowProvider(radarGroupOf(id))).value;
  // Look-back not loaded (or corrupt, which the screen reports): stay loading.
  if (selected == null) return const Stream.empty();
  return ref.watch(radarFrameRepositoryProvider).watch(source, window: radarEffectiveWindow(selected, source));
});
