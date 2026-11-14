import '../../data/radar/radar_frame_list.dart';

/// Playback speeds offered in 播放設定 and the default.
const radarFpsOptions = [2, 4, 8];
const radarDefaultFps = 4;

/// Look-back choices in hours (default 4 h = [radarDefaultWindowFrames] frames).
const radarWindowHourOptions = [1, 2, 4, 6, 12, 24];

/// Fixed wait after the last frame before the loop restarts (repeat on).
const radarRepeatPause = Duration(seconds: 3);

/// Frames in one hour of the loop (10-minute cadence).
final radarFramesPerHour = Duration.minutesPerHour ~/ radarFrameStep.inMinutes;

/// What the playback clock does after showing frame [index].
class RadarTick {
  const RadarTick({required this.delay, required this.nextIndex});

  /// Time to wait before showing [nextIndex].
  final Duration delay;
  final int nextIndex;
}

/// Next step of the loop after showing frame [index] of [count], or null when
/// playback ends (last frame shown and repeat is off).
RadarTick? radarNextTick({
  required int index,
  required int count,
  required int fps,
  required bool repeat,
}) {
  if (index < 0 || index >= count) {
    throw RangeError.range(index, 0, count - 1, 'index');
  }
  if (index < count - 1) {
    return RadarTick(delay: Duration(microseconds: Duration.microsecondsPerSecond ~/ fps), nextIndex: index + 1);
  }
  return repeat ? const RadarTick(delay: radarRepeatPause, nextIndex: 0) : null;
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
