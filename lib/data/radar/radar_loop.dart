import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

import 'radar_source.dart';
import 'radar_webp_image.dart';

/// One processed, cached frame: transparent lossless WebP with rows linear in
/// Web Mercator, shown as one `OverlayImage` over [bounds]. Of the echo
/// statistics only the strongest echo is kept.
class RadarFrame {
  final DateTime time;
  final File file;
  final LatLngBounds bounds;

  /// [RadarEchoStats.strongestDbz] when the frame has significant echo, else null.
  final int? significantDbz;

  /// [RadarEchoStats.peakMm]: highest accumulated rain (mm) of an
  /// accumulated-rainfall frame; null for radar frames.
  final double? peakMm;

  /// Pixel size of [file] (website frames: 2048 x 2132 Mercator rows).
  final int width;
  final int height;

  const RadarFrame({
    required this.time,
    required this.file,
    required this.bounds,
    required this.significantDbz,
    this.peakMm,
    required this.width,
    required this.height,
  });

  /// Height / width of the decoded image.
  double get aspect => height / width;

  /// Decoded at the stored size (~17 MB for a website frame); the map and its
  /// pre-decode share this provider's cache entry.
  ImageProvider get imageProvider => RadarWebpImage(file);
}

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

  /// The frame list could not be fetched, or is stale
  /// ([RadarStaleListException]); [slots] then come from the cache.
  final RadarDataException? listError;

  /// Slots are still being fetched or processed.
  final bool loading;

  const RadarLoop({required this.slots, required this.loading, this.listError});
}
