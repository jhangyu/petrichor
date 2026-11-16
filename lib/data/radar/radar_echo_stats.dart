import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_tokens.dart';

// Echo statistics of one radar image (website frame or station image),
// computed from the source pixels by `processRadarFrame`.
//
// Colour → dBZ: [radarEchoPalette] index = dBZ. Evidence: the legend bar of
// the real frame CV1_3600_202611142230 (column 3453, rows 2507–3571) is 66
// equal 16-row steps whose colours are palette indices 65 (top) down to 0
// (bottom), i.e. one colour per 1 dBZ over the legend's 0–65 dBZ scale. The
// website station images carry the same 66-colour bar.

/// dBZ legend colours (0xRRGGBB, index = dBZ), from the CWA scale in
/// [AppPalette.dbzScale] (sampled from the frames' legend bar).
final radarEchoPalette = [for (final c in AppPalette.dbzScale) c.toARGB32() & _rgbMask];

const _rgbMask = 0xFFFFFF;

/// Echo weaker than this is not "明顯回波". Marshall–Palmer (Z = 200 R^1.6):
/// 20 dBZ ≈ 0.65 mm/h, just above the 0.5 mm resolution of CWA rain gauges;
/// weaker echo is mostly drizzle, clear-air or clutter return.
const radarSignificantEchoDbz = 20;

/// A dBZ level counts only if pixels covering at least this many km² reach
/// it. Measured on the real frame CV1_3600_202611142250: a 4 x 10 px block of
/// 65 dBZ inside a 13–18 dBZ field (an isolated bad bin, ≈ 4.6 km²) must not
/// count; the same frame's real ≥ 50 dBZ echo covers ≈ 170 km². ponytail: an
/// area rule, not a connected-blob one; upgrade if artifacts larger than this
/// show up.
const radarEchoMinAreaKm2 = 12.0;

const _earthKmPerDegree = AppConstants.earthRadiusKm * pi / 180;

/// Header words (uint32): image width, image height.
const _headerWords = 2;

/// Header doubles after the words: frame south, west, north, east.
const _frameDoubles = 4;

class RadarEchoStats {
  /// Extent of the source image (linear in latitude and longitude).
  final LatLngBounds frame;
  final int imageWidth;
  final int imageHeight;

  /// Echo pixel count per dBZ over the whole image (index = dBZ, 0..65).
  final List<int> pixelsPerDbz;

  /// Highest accumulated rain (mm) over an accumulated-rainfall grid; null for
  /// radar images.
  final double? peakMm;

  RadarEchoStats({
    required this.frame,
    required this.imageWidth,
    required this.imageHeight,
    required this.pixelsPerDbz,
    this.peakMm,
  }) {
    if (pixelsPerDbz.length != radarEchoPalette.length) {
      throw ArgumentError(
        'RadarEchoStats: expected ${radarEchoPalette.length} dBZ counts, got ${pixelsPerDbz.length}',
      );
    }
  }

  /// Pixels needed for [radarEchoMinAreaKm2] at this image's scale.
  int get minPixels {
    final midLat = (frame.north + frame.south) / 2;
    final pxKm2 = (frame.north - frame.south) / imageHeight * _earthKmPerDegree *
        (frame.east - frame.west) / imageWidth * _earthKmPerDegree * cos(midLat * pi / 180);
    return (radarEchoMinAreaKm2 / pxKm2).ceil();
  }

  /// Highest dBZ reached over [radarEchoMinAreaKm2]; null when no level is.
  int? get strongestDbz {
    final need = minPixels;
    var atOrAbove = 0;
    for (var d = pixelsPerDbz.length - 1; d >= 0; d--) {
      atOrAbove += pixelsPerDbz[d];
      if (atOrAbove >= need) return d;
    }
    return null;
  }

  /// No level of [radarSignificantEchoDbz] or more: the 「無明顯回波」 image.
  bool get hasSignificantEcho => (strongestDbz ?? -1) >= radarSignificantEchoDbz;

  Uint8List toBytes() {
    final words = Uint32List.fromList([imageWidth, imageHeight]);
    final doubles = Float64List.fromList([frame.south, frame.west, frame.north, frame.east]);
    return (BytesBuilder(copy: false)
          ..add(words.buffer.asUint8List())
          ..add(doubles.buffer.asUint8List())
          ..add(Uint32List.fromList(pixelsPerDbz).buffer.asUint8List())
          // NaN = no peak (radar).
          ..add(Float64List.fromList([peakMm ?? double.nan]).buffer.asUint8List()))
        .takeBytes();
  }

  /// Inverse of [toBytes]; [source] names the file in errors.
  factory RadarEchoStats.fromBytes(Uint8List bytes, {required String source}) {
    const wordBytes = Uint32List.bytesPerElement, doubleBytes = Float64List.bytesPerElement;
    const countsAt = _headerWords * wordBytes + _frameDoubles * doubleBytes;
    final peakAt = countsAt + radarEchoPalette.length * wordBytes;
    final expected = peakAt + doubleBytes;
    if (bytes.length != expected) {
      throw FormatException('$source: expected $expected bytes of echo stats, got ${bytes.length}');
    }
    final data = ByteData.sublistView(bytes);
    int word(int offset) => data.getUint32(offset, Endian.host);
    double float(int i) => data.getFloat64(_headerWords * wordBytes + i * doubleBytes, Endian.host);
    return RadarEchoStats(
      frame: LatLngBounds(LatLng(float(0), float(1)), LatLng(float(2), float(3))),
      imageWidth: word(0),
      imageHeight: word(wordBytes),
      pixelsPerDbz: [for (var d = 0; d < radarEchoPalette.length; d++) word(countsAt + d * wordBytes)],
      peakMm: switch (data.getFloat64(peakAt, Endian.host)) { final p when p.isNaN => null, final p => p },
    );
  }
}
