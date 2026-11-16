import 'package:flutter/foundation.dart';

import '../../data/radar/radar_loop.dart';

/// What the playback card shows once the loop's times are known.
class PlaybackFrames {
  const PlaybackFrames({
    required this.slots,
    required this.index,
    required this.current,
    required this.buffering,
    required this.playing,
    required this.framesPerSecond,
    required this.repeat,
    required this.window,
    this.windowOptions = const [],
    required this.onTogglePlay,
    required this.onSeek,
    required this.onFramesPerSecondChanged,
    required this.onRepeat,
    this.onWindow,
    this.timeText,
  });

  /// Time-row text of the current slot's time; null = the time itself. An
  /// accumulation frame has no single moment, so its card words the span.
  final String Function(DateTime)? timeText;

  /// Every listed time of the window, oldest first, one timeline cell each
  /// (the source's native cadence, regular or not).
  final List<RadarSlot> slots;

  /// Slot on show (always a ready one).
  final int index;

  /// Highlighted slot and time-row time: the slot playback waits on while
  /// [buffering], else [index].
  final int current;

  /// Playing but stopped at a pending slot (緩衝中).
  final bool buffering;
  final bool playing;
  final int framesPerSecond;
  final bool repeat;
  final Duration window;

  /// Look-back choices this source offers; empty = the span is fixed elsewhere
  /// and 播放設定 has no 回看範圍.
  final List<Duration> windowOptions;

  /// Null = play disabled (no ready slot).
  final VoidCallback? onTogglePlay;

  /// Called with a ready slot's time only (a time, not an index: the slot list
  /// may be replaced before the screen handles the tap).
  final ValueChanged<DateTime> onSeek;
  final ValueChanged<int> onFramesPerSecondChanged;
  final ValueChanged<bool> onRepeat;
  final ValueChanged<Duration>? onWindow;

  bool isSlotReady(int index) => slots[index].state == RadarSlotState.ready;

}
