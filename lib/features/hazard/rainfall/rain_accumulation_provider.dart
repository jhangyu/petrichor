import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import '../../../core/storage/stored_setting.dart';
import '../../../data/radar/radar_loop.dart';
import '../../../data/rain_accum/accum_pieces.dart';
import '../../../data/rain_accum/accum_source.dart';
import '../../radar/radar_provider.dart';

/// Accumulation window of the 累積雨量 card in hours, one of [accumWindowHours].
class RainAccumWindow extends IntSetting<int> {
  @override
  String get key => 'rainfall.accumWindowHours';
  @override
  int get defaultValue => accumDefaultWindowHours;
  @override
  String get expected => 'one of $accumWindowHours';
  @override
  int? fromStored(int stored) => accumWindowHours.contains(stored) ? stored : null;
  @override
  int toStored(int value) => value;
}

/// Window of a fresh install.
const accumDefaultWindowHours = 24;

final rainAccumWindowProvider = AsyncNotifierProvider<RainAccumWindow, int>(RainAccumWindow.new, retry: noRetry);

/// Frames of the accumulation over the last [windowHours] hours, through the
/// radar frame repository (the playback span equals the window). Loads when
/// first watched or when the window changes; a user refresh is
/// `ref.invalidate(accumLoopProvider(hours))`.
final accumLoopProvider = StreamProvider.autoDispose.family<RadarLoop, int>((ref, windowHours) {
  final source = accumRadarSource(ref.watch(webDioProvider), windowHours: windowHours);
  return ref.watch(radarFrameRepositoryProvider).watch(source, window: Duration(hours: windowHours));
});
