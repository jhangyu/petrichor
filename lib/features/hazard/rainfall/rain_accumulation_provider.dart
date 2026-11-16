import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_providers.dart';
import '../../../core/storage/stored_setting.dart';
import '../../../data/radar/radar_loop.dart';
import '../../../data/rain_accumulation/rain_accumulation_pieces.dart';
import '../../../data/rain_accumulation/rain_accumulation_source.dart';
import '../../radar/radar_provider.dart';

/// Accumulation window of the 累積雨量 card in hours, one of [accumulationWindowHours].
class RainAccumulationWindowSetting extends IntSetting<int> {
  @override
  String get storageKey => 'rainfall.accumWindowHours';
  @override
  int get defaultValue => accumulationDefaultWindowHours;
  @override
  String get expectedDescription => 'one of $accumulationWindowHours';
  @override
  int? fromStored(int stored) => accumulationWindowHours.contains(stored) ? stored : null;
  @override
  int toStored(int value) => value;
}

/// Window of a fresh install.
const accumulationDefaultWindowHours = 24;

final rainAccumulationWindowProvider = AsyncNotifierProvider<RainAccumulationWindowSetting, int>(RainAccumulationWindowSetting.new, retry: noRetry);

/// Frames of the accumulation over the last [windowHours] hours, through the
/// radar frame repository (the playback span equals the window). Loads when
/// first watched or when the window changes; a user refresh is
/// `ref.invalidate(accumulationLoopProvider(hours))`.
final accumulationLoopProvider = StreamProvider.autoDispose.family<RadarLoop, int>((ref, windowHours) {
  final source = accumulationRadarSource(ref.watch(cwaWebsiteDioProvider), windowHours: windowHours);
  return ref.watch(radarFrameRepositoryProvider).watch(source, window: Duration(hours: windowHours));
});
