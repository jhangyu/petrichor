import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Post-processing of a website `CV1_3600_` frame: background → transparent,
/// rows reprojected to Web Mercator, lossless WebP.
///
/// Background key (evidence: docs/logs/2026-11-14/radar-impl-notes.md): echo
/// pixels are drawn only in the 66 colours of the dBZ legend (one per dBZ,
/// 0–65); everything else (land/sea fill, coast/county lines, grid, text,
/// logo) is background. The legend bar and the station-status dots also use
/// legend-like colours, so their rectangles are always background.

const radarFrameSize = 3600;

/// dBZ legend colours (0xRRGGBB), read from the legend bar of CV1_3600_202611142050.
const radarEchoPalette = <int>[
  0x00ffff, 0x00ecff, 0x00daff, 0x00c8ff, 0x00b6ff, 0x00a3ff, 0x0091ff, 0x007fff, //
  0x006dff, 0x005bff, 0x0048ff, 0x0036ff, 0x0024ff, 0x0012ff, 0x0000ff, 0x00ff00,
  0x00f400, 0x00e900, 0x00de00, 0x00d300, 0x00c800, 0x00be00, 0x00b400, 0x00aa00,
  0x00a000, 0x009600, 0x33ab00, 0x66c000, 0x99d500, 0xccea00, 0xffff00, 0xfff400,
  0xffe900, 0xffde00, 0xffd300, 0xffc800, 0xffb800, 0xffa800, 0xff9800, 0xff8800,
  0xff7800, 0xff6000, 0xff4800, 0xff3000, 0xff1800, 0xff0000, 0xf40000, 0xe90000,
  0xde0000, 0xd30000, 0xc80000, 0xbe0000, 0xb40000, 0xaa0000, 0xa00000, 0x960000,
  0xab0033, 0xc00066, 0xd50099, 0xea00cc, 0xff00ff, 0xea00ff, 0xd500ff, 0xc000ff,
  0xab00ff, 0x9600ff,
];

/// Pixel rectangle, [left, right) x [top, bottom).
typedef PixelRect = ({int left, int top, int right, int bottom});

/// Decorations of the 3600 frame drawn in legend colours (measured on real frames).
const websiteFrameDecorations = <PixelRect>[
  (left: 3419, top: 2507, right: 3488, bottom: 3572), // dBZ colour bar
  (left: 97, top: 223, right: 146, bottom: 718), // radar station status dots
];

/// Latitude extent of the 3600 frame (see radar_bounds.dart).
const radarFrameSouth = 17.75;
const radarFrameNorth = 29.25;

/// The processed frame is stored as this many horizontal bands, each its own
/// lossless WebP: the `image` VP8L encoder allocates ~28 bytes per pixel, so
/// one 3600x3748 encode peaks near 375 MB; bands bound that by the band size.
const radarFrameBands = 8;

/// Mercator row map of the 3600 frame (3748 output rows).
final radarFrameRowMap = mercatorRowMap(srcHeight: radarFrameSize, south: radarFrameSouth, north: radarFrameNorth);

/// Output-row ranges [start, end) of each band, top band first.
List<(int, int)> radarBandRows({int bands = radarFrameBands}) {
  final height = radarFrameRowMap.length;
  final step = (height / bands).ceil();
  return [for (var top = 0; top < height; top += step) (top, min(top + step, height))];
}

/// Full pipeline for one downloaded frame: one lossless WebP per band (see
/// [radarBandRows]). Pure and synchronous: run it in a background isolate.
List<Uint8List> processRadarFrame(Uint8List png, {int bands = radarFrameBands}) {
  final src = img.decodePng(png) ?? (throw const FormatException('radar frame: expected PNG bytes, decode failed'));
  if (src.width != radarFrameSize || src.height != radarFrameSize) {
    throw FormatException('radar frame: expected ${radarFrameSize}x$radarFrameSize, got ${src.width}x${src.height}');
  }
  return [
    for (final (top, end) in radarBandRows(bands: bands))
      img.encodeWebP(
        keyRadarEcho(src, rowMap: radarFrameRowMap.sublist(top, end), decorations: websiteFrameDecorations),
        lossless: true,
      ),
  ];
}

/// Builds an RGBA image whose row `j` is source row `rowMap[j]` with every
/// non-echo pixel (colour not in [radarEchoPalette], or inside a [decorations]
/// rectangle given in source coordinates) set to transparent black. Echo pixels
/// keep their RGB exactly, alpha 255.
img.Image keyRadarEcho(img.Image src, {required List<int> rowMap, List<PixelRect> decorations = const []}) {
  if (src.numChannels != 3 || src.format != img.Format.uint8 || src.hasPalette) {
    throw FormatException(
      'radar frame: expected 8-bit RGB without palette, got ${src.numChannels} channels, '
      '${src.format}, palette=${src.hasPalette}',
    );
  }
  final echoBits = Uint32List(1 << 19); // one bit per 24-bit colour
  for (final c in radarEchoPalette) {
    echoBits[c >> 5] |= 1 << (c & 31);
  }
  final width = src.width;
  final out = img.Image(width: width, height: rowMap.length, numChannels: 4);
  final s = src.toUint8List();
  final d = out.toUint8List();
  final sStride = src.rowStride;
  final dStride = out.rowStride;
  var previousSrcRow = -1;
  for (var j = 0; j < rowMap.length; j++) {
    final y = rowMap[j];
    final dRow = j * dStride;
    if (y == previousSrcRow) {
      d.setRange(dRow, dRow + dStride, d, dRow - dStride);
      continue;
    }
    previousSrcRow = y;
    final sRow = y * sStride;
    for (var x = 0; x < width; x++) {
      final si = sRow + x * 3;
      final r = s[si], g = s[si + 1], b = s[si + 2];
      final c = (r << 16) | (g << 8) | b;
      if (echoBits[c >> 5] & (1 << (c & 31)) != 0) {
        final di = dRow + x * 4;
        d[di] = r;
        d[di + 1] = g;
        d[di + 2] = b;
        d[di + 3] = 255;
      }
    }
    for (final rect in decorations) {
      if (y >= rect.top && y < rect.bottom) {
        d.fillRange(dRow + rect.left * 4, dRow + min(rect.right, width) * 4, 0);
      }
    }
  }
  return out;
}

/// Row map from an image linear in latitude ([south]..[north], [srcHeight]
/// rows) to Web Mercator rows, top row first. The output height is chosen so
/// that no source row is dropped (stretch ≥ 1 row at the southern edge, where
/// Mercator stretches least); northern rows are duplicated.
List<int> mercatorRowMap({required int srcHeight, required double south, required double north}) {
  final yS = _mercY(south), yN = _mercY(north);
  final outHeight = (srcHeight * (yN - yS) * cos(_rad(south)) / _rad(north - south)).ceil();
  return List<int>.generate(outHeight, (j) {
    final lat = _latOf(yN - (j + 0.5) * (yN - yS) / outHeight);
    return ((north - lat) / (north - south) * srcHeight).floor().clamp(0, srcHeight - 1);
  });
}

/// Latitude of the edge above output row [row] (0..[height]) of a Mercator
/// image spanning [south]..[north].
double mercatorRowEdgeLat(int row, {required int height, required double south, required double north}) {
  final yS = _mercY(south), yN = _mercY(north);
  return _latOf(yN - row * (yN - yS) / height);
}

double _rad(double deg) => deg * pi / 180;
double _mercY(double lat) => log(tan(pi / 4 + _rad(lat) / 2));
double _latOf(double y) => (2 * atan(exp(y)) - pi / 2) * 180 / pi;
