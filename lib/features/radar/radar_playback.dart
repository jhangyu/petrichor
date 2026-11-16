import '../../data/radar/radar_loop.dart';

/// Playback speeds offered in 播放設定 and the default.
const radarFpsOptions = [2, 4, 8, 12, 24];

/// Look-back choices; a source offers those up to its `maxWindow`.
const radarWindowOptions = [
  Duration(hours: 1),
  Duration(hours: 2),
  Duration(hours: 4),
  Duration(hours: 6),
  Duration(hours: 12),
  Duration(hours: 24),
];

/// Sources that share playback settings (look-back, fps, opacity), each group
/// with its own defaults.
enum RadarGroup {
  taiwan(defaultWindow: Duration(hours: 6), defaultFps: 8),
  regional(defaultWindow: Duration(hours: 4), defaultFps: 12),

  /// 雨量 page 累積雨量: only fps and repeat are used (the span is the accumulation window).
  rainfall(defaultWindow: Duration(hours: 24), defaultFps: 8);

  const RadarGroup({required this.defaultWindow, required this.defaultFps});

  final Duration defaultWindow;
  final int defaultFps;
}

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

/// Timeline cell to highlight: the slot at [waitingOn] while buffering, so the
/// time row and highlight match where playback stopped; else the [shown] one.
/// A [waitingOn] no longer listed (the list was just replaced; the next loop
/// update sets a new one) keeps [shown].
int radarCurrentCell(List<RadarSlot> slots, {required int shown, required DateTime? waitingOn}) {
  if (waitingOn == null) return shown;
  final i = slots.indexWhere((s) => s.time == waitingOn);
  return i < 0 ? shown : i;
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

/// Slots that could not be loaded, oldest first.
List<RadarSlot> radarFailedSlots(List<RadarSlot> slots) => [
  for (final s in slots)
    if (s.state == RadarSlotState.failed) s,
];

/// Number of slots ready to show.
int radarReadyCount(List<RadarSlot> slots) => slots.where((s) => s.state == RadarSlotState.ready).length;

/// Nearest ready slot before [index]; null when none.
int? radarPreviousReady(List<RadarSlot> slots, int index) {
  for (var i = index - 1; i >= 0; i--) {
    if (slots[i].state == RadarSlotState.ready) return i;
  }
  return null;
}

/// Nearest ready slot after [index]; null when none.
int? radarNextReady(List<RadarSlot> slots, int index) {
  for (var i = index + 1; i < slots.length; i++) {
    if (slots[i].state == RadarSlotState.ready) return i;
  }
  return null;
}

/// Why no slot can be shown: the list error, else every failed slot's error joined by 「；」.
Object radarNoFrameError(RadarLoop loop, List<RadarSlot> failed) =>
    loop.listError ?? failed.map((s) => s.error).join('；');

/// Playback card meta line: buffering, playing, loading, else [idle].
String radarPlaybackMeta({
  required bool buffering,
  required bool playing,
  required bool loading,
  required int ready,
  required int total,
  required int fps,
  required bool repeat,
  required String idle,
}) => buffering
    ? '緩衝中 · 已就緒 $ready / $total 張'
    : playing
    ? '播放中 · $fps fps${repeat ? ' · 重複' : ''}'
    : loading
    ? '載入中 $ready / $total 張'
    : idle;
