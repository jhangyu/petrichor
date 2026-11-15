import '../../data/radar/radar_frame_repository.dart' show RadarFrame;
import '../../data/radar/radar_loop.dart';

/// Playback speeds offered in 播放設定 and the default.
const radarFpsOptions = [2, 4, 8];
const radarDefaultFps = 4;

/// Look-back choices; a source offers those up to its `maxWindow`.
const radarWindowOptions = [
  Duration(hours: 1),
  Duration(hours: 2),
  Duration(hours: 4),
  Duration(hours: 6),
  Duration(hours: 12),
  Duration(hours: 24),
];

/// Look-back when the page opens.
const radarDefaultWindow = Duration(hours: 4);

/// Fixed wait after the last frame before the loop restarts (repeat on).
const radarRepeatPause = Duration(seconds: 3);

/// What playback does after the frame at its playhead.
sealed class RadarStep {
  const RadarStep(this.time);

  /// Slot to show next, or to wait on.
  final DateTime time;
}

/// Show the ready slot at [time] after [delay].
final class RadarShow extends RadarStep {
  const RadarShow(super.time, this.delay);

  final Duration delay;

  @override
  bool operator ==(Object other) => other is RadarShow && other.time == time && other.delay == delay;

  @override
  int get hashCode => Object.hash(time, delay);

  @override
  String toString() => 'RadarShow($time, $delay)';
}

/// The slot at [time] is still pending: stop (緩衝中) until a loop update makes
/// it ready or failed, then ask again.
final class RadarWait extends RadarStep {
  const RadarWait(super.time);

  @override
  bool operator ==(Object other) => other is RadarWait && other.time == time;

  @override
  int get hashCode => time.hashCode;

  @override
  String toString() => 'RadarWait($time)';
}

/// Next step after showing the slot at [after] ([slots] oldest first), or null
/// when playback ends (newest played and repeat off, or nothing playable).
/// [after] null = playback has not started: the oldest slot comes next, shown
/// at once. Playing goes oldest→newest, skips failed slots, stops at the first
/// pending one, and after the newest restarts at the oldest following
/// [radarRepeatPause].
RadarStep? radarNextStep({
  required List<RadarSlot> slots,
  required DateTime? after,
  required int fps,
  required bool repeat,
}) {
  final start = after == null ? 0 : slots.indexWhere((s) => s.time.isAfter(after));
  final frameDelay = Duration(microseconds: Duration.microsecondsPerSecond ~/ fps);
  var delay = after == null ? Duration.zero : frameDelay;
  var i = start < 0 ? slots.length : start;
  // At most one full lap: past it every slot was seen failed.
  for (var seen = 0; seen <= slots.length; seen++) {
    if (i == slots.length) {
      if (!repeat || slots.isEmpty) return null;
      i = 0;
      delay = radarRepeatPause;
    }
    final slot = slots[i];
    switch (slot.state) {
      case RadarSlotState.ready:
        return RadarShow(slot.time, delay);
      case RadarSlotState.pending:
        return RadarWait(slot.time);
      case RadarSlotState.failed:
        i++;
    }
  }
  return null;
}

/// Index of the slot on show: the ready slot at [playhead], or the newest ready
/// slot when [playhead] is null (page open, before play) or no longer a ready
/// listed time (the list was replaced). Null when no slot is ready.
int? radarShownIndex(List<RadarSlot> slots, DateTime? playhead) {
  if (playhead != null) {
    final i = slots.indexWhere((s) => s.time == playhead && s.state == RadarSlotState.ready);
    if (i >= 0) return i;
  }
  final newest = slots.lastIndexWhere((s) => s.state == RadarSlotState.ready);
  return newest < 0 ? null : newest;
}

/// Up to [count] ready frames that play after [after] (null = from the oldest),
/// in play order with the wrap to the oldest; for decoding ahead.
List<RadarFrame> radarUpcomingFrames(List<RadarSlot> slots, DateTime? after, {required int count}) {
  final start = after == null ? 0 : slots.indexWhere((s) => s.time.isAfter(after));
  final first = start < 0 ? 0 : start;
  return [
    for (var k = 0; k < slots.length; k++)
      if (slots[(first + k) % slots.length] case RadarSlot(state: RadarSlotState.ready, :final frame?, :final time)
          when time != after)
        frame,
  ].take(count).toList();
}

/// File names, the CWA site and the mockup use Taiwan time (UTC+8, no DST).
const _taiwanUtcOffset = Duration(hours: 8);

DateTime _taiwan(DateTime t) => t.toUtc().add(_taiwanUtcOffset);

String _two(int v) => v.toString().padLeft(2, '0');

/// `14:00`
String formatTaiwanClock(DateTime t) {
  final l = _taiwan(t);
  return '${_two(l.hour)}:${_two(l.minute)}';
}

/// `11/14 14:00`
String formatTaiwanMonthDayClock(DateTime t) {
  final l = _taiwan(t);
  return '${_two(l.month)}/${_two(l.day)} ${formatTaiwanClock(t)}';
}

/// `2026-11-14 14:00`
String formatTaiwanFull(DateTime t) {
  final l = _taiwan(t);
  return '${l.year}-${_two(l.month)}-${_two(l.day)} ${formatTaiwanClock(t)}';
}
