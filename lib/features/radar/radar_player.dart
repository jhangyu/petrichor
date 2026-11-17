import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/radar/radar_loop.dart';
import 'radar_playback.dart';

/// Playback state of one loop on screen: the playhead, the frame-rate / repeat
/// pause clock and the buffering stop (緩衝中). Every state change notifies the
/// listeners. [slots], [framesPerSecond] and [repeat] are read when a step is taken.
class RadarPlayer extends ChangeNotifier {
  RadarPlayer({required this.slots, required this.framesPerSecond, required this.repeat});

  final List<RadarSlot>? Function() slots;
  final int Function() framesPerSecond;
  final bool Function() repeat;

  bool playing = false;

  /// Time of the shown slot; null = the newest ready one (page open, reload,
  /// and before play starts from the oldest).
  DateTime? playhead;

  /// Time of the pending slot playback stopped at (緩衝中); null when not
  /// buffering. Resumed by [onLoopUpdate], never by a timer. The map keeps the
  /// last shown frame meanwhile.
  DateTime? waitingOn;

  Timer? _timer;

  /// Playing, but held while its tab is hidden ([suspend]); no step is taken.
  bool _suspended = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _halt() {
    _timer?.cancel();
    _timer = null;
    playing = false;
    waitingOn = null;
    _suspended = false;
  }

  /// Its tab was left: a playing loop holds at the playhead, still marked playing.
  void suspend() {
    if (!playing) return;
    _timer?.cancel();
    _suspended = true;
  }

  /// Its tab is shown again: a held loop continues from the playhead.
  void resume() {
    if (!_suspended) return;
    _suspended = false;
    _advance(immediate: waitingOn != null);
  }

  /// Stops playing and goes back to the newest frame (reload, window or source change).
  void reset() {
    _halt();
    playhead = null;
    notifyListeners();
  }

  /// Takes the next step after the playhead: shows the next ready slot after
  /// 1/framesPerSecond (at once when [immediate]: play start, or resuming from 緩衝中), or
  /// stops at a pending one, or ends.
  void _advance({required bool immediate}) {
    _timer?.cancel();
    if (_suspended) return;
    final all = slots();
    final step = all == null ? null : radarNextStep(slots: all, after: playhead, framesPerSecond: framesPerSecond(), repeat: repeat());
    switch (step) {
      case null:
        _halt();
        notifyListeners();
      case RadarWait(:final time):
        waitingOn = time;
        notifyListeners();
      case RadarShow(:final time, :final delay):
        void show() {
          playhead = time;
          waitingOn = null;
          notifyListeners();
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
      notifyListeners();
      return;
    }
    final head = playhead;
    // At (or before reaching) the newest ready frame: play from the oldest.
    final fromStart = head == null || !slots()!.any((s) => s.state == RadarSlotState.ready && s.time.isAfter(head));
    playing = true;
    if (fromStart) playhead = null;
    notifyListeners();
    _advance(immediate: fromStart);
  }

  void seek(DateTime time) {
    playhead = time;
    waitingOn = null;
    notifyListeners();
    if (playing) _advance(immediate: false);
  }

  /// The speed changed: the pending frame delay restarts at the new one.
  void onFramesPerSecondChanged() {
    if (playing && waitingOn == null) _advance(immediate: false);
  }

  /// A loop update may have made the slot playback waits on ready (or failed).
  void onLoopUpdate() {
    if (playing && waitingOn != null) _advance(immediate: true);
  }
}
