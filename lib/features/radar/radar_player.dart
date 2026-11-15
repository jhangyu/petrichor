import 'dart:async';

import '../../data/radar/radar_loop.dart';
import 'radar_playback.dart';

/// Playback state of one loop on screen: the playhead, the frame-rate / repeat
/// pause clock and the buffering stop (緩衝中). Every state change calls
/// [onChanged] (the owner's setState). [slots], [fps] and [repeat] are read
/// when a step is taken.
class RadarPlayer {
  RadarPlayer({required this.slots, required this.fps, required this.repeat, required this.onChanged});

  final List<RadarSlot>? Function() slots;
  final int Function() fps;
  final bool Function() repeat;
  final void Function() onChanged;

  bool playing = false;

  /// Time of the shown slot; null = the newest ready one (page open, reload,
  /// and before play starts from the oldest).
  DateTime? playhead;

  /// Time of the pending slot playback stopped at (緩衝中); null when not
  /// buffering. Resumed by [onLoopUpdate], never by a timer. The map keeps the
  /// last shown frame meanwhile.
  DateTime? waitingOn;

  Timer? _timer;

  void dispose() => _timer?.cancel();

  void _halt() {
    _timer?.cancel();
    _timer = null;
    playing = false;
    waitingOn = null;
  }

  /// Stops playing and goes back to the newest frame (reload, window or source change).
  void reset() {
    _halt();
    playhead = null;
    onChanged();
  }

  /// Takes the next step after the playhead: shows the next ready slot after
  /// 1/fps (at once when [immediate]: play start, or resuming from 緩衝中), or
  /// stops at a pending one, or ends.
  void _advance({required bool immediate}) {
    _timer?.cancel();
    final all = slots();
    final step = all == null ? null : radarNextStep(slots: all, after: playhead, fps: fps(), repeat: repeat());
    switch (step) {
      case null:
        _halt();
        onChanged();
      case RadarWait(:final time):
        waitingOn = time;
        onChanged();
      case RadarShow(:final time, :final delay):
        void show() {
          playhead = time;
          waitingOn = null;
          onChanged();
          _advance(immediate: false);
        }
        if (immediate) {
          show();
        } else {
          _timer = Timer(delay, show);
        }
    }
  }

  void togglePlay() {
    if (playing) {
      _halt();
      onChanged();
      return;
    }
    final head = playhead;
    // At (or before reaching) the newest ready frame: play from the oldest.
    final fromStart = head == null || !slots()!.any((s) => s.state == RadarSlotState.ready && s.time.isAfter(head));
    playing = true;
    if (fromStart) playhead = null;
    onChanged();
    _advance(immediate: fromStart);
  }

  void seek(DateTime time) {
    playhead = time;
    waitingOn = null;
    onChanged();
    if (playing) _advance(immediate: false);
  }

  /// The speed changed: the pending frame delay restarts at the new one.
  void onFpsChanged() {
    if (playing && waitingOn == null) _advance(immediate: false);
  }

  /// A loop update may have made the slot playback waits on ready (or failed).
  void onLoopUpdate() {
    if (playing && waitingOn != null) _advance(immediate: true);
  }
}
