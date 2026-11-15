import 'radar_echo_stats.dart';
import 'radar_frame_repository.dart' show RadarFrame;
import 'radar_source.dart';

enum RadarSlotState { pending, ready, failed }

/// One listed time of a loop: [frame] is set when [state] is
/// [RadarSlotState.ready], [error] when it is [RadarSlotState.failed].
class RadarSlot {
  final DateTime time;
  final RadarSlotState state;
  final RadarFrame? frame;
  final RadarDataException? error;

  const RadarSlot.pending(this.time)
      : state = RadarSlotState.pending,
        frame = null,
        error = null;

  RadarSlot.ready(RadarFrame this.frame)
      : time = frame.time,
        state = RadarSlotState.ready,
        error = null;

  const RadarSlot.failed(this.time, RadarDataException this.error)
      : state = RadarSlotState.failed,
        frame = null;

  @override
  String toString() => 'RadarSlot($time, ${state.name}${error == null ? '' : ', $error'})';
}

/// What one source currently has to show.
class RadarLoop {
  /// Oldest first: every time the frame list lists within the window. Before
  /// the list is known, or when it could not be fetched ([listError]), the
  /// cached frames of the window, all ready.
  final List<RadarSlot> slots;

  /// Echo statistics of the newest ready slot; null when no slot is ready.
  final RadarEchoStats? newestStats;

  /// The frame list could not be fetched, or is stale
  /// ([RadarStaleListException]); [slots] then come from the cache.
  final RadarDataException? listError;

  /// Slots are still being fetched or processed.
  final bool loading;

  const RadarLoop({required this.slots, required this.newestStats, required this.loading, this.listError});
}
