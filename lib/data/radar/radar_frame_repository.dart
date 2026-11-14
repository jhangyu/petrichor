import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

import 'radar_bounds.dart';
import 'radar_echo_stats.dart';
import 'radar_frame_list.dart';
import 'radar_frame_processor.dart';

/// Cache sub-directory; the suffix changes whenever processing output changes,
/// so frames made by an older pipeline are never shown.
const radarFrameCacheDirName = 'radar_cv1_3600_webp_v3';

/// Radar data could not be obtained or did not have the expected shape.
class RadarDataException implements Exception {
  final String source;
  final String expected;
  final Object? actual;

  const RadarDataException(this.source, {required this.expected, required this.actual});

  @override
  String toString() => 'RadarDataException($source): expected $expected, got $actual';
}

/// One horizontal band of a processed frame.
class RadarFrameBand {
  final File file;
  final LatLngBounds bounds;

  const RadarFrameBand({required this.file, required this.bounds});

  /// Decoded at [decodeWidth] px, not at full 3600 px: a full-size decoded
  /// frame is ~54 MB, so a loop must use a display-size width and only the
  /// paused, zoomed-in frame may use the full width.
  ImageProvider imageProvider({required int decodeWidth}) =>
      ResizeImage(FileImage(file), width: decodeWidth, policy: ResizeImagePolicy.fit);
}

/// One processed, cached frame: transparent lossless WebP bands, Web Mercator
/// rows, one `OverlayImage` per band.
class RadarFrame {
  final DateTime time;
  final List<RadarFrameBand> bands;
  final RadarEchoStats stats;

  const RadarFrame({required this.time, required this.bands, required this.stats});
}

/// Downloads the website frame window, processes new frames off the UI
/// isolate, and keeps exactly the current window on disk.
class RadarFrameRepository {
  final Dio _dio;
  final Future<Directory> Function() cacheRoot;
  final DateTime Function() clock;

  RadarFrameRepository(this._dio, {required this.cacheRoot, required this.clock});

  /// Returns the last [windowFrames] frames, oldest first. Already-cached
  /// frames are not downloaded again; entries outside the window are deleted.
  Future<List<RadarFrame>> refresh({required int windowFrames}) async {
    final listResponse = await _dio.get<String>(
      radarFrameListUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final js = listResponse.data ??
        (throw RadarDataException(radarFrameListUrl, expected: 'JS body', actual: 'HTTP ${listResponse.statusCode} without body'));
    final now = clock();
    final window = selectRadarFrameWindow(parseRadarFrameList(js), now: now, windowFrames: windowFrames);
    if (window.isEmpty) {
      throw RadarDataException(radarFrameListUrl,
          expected: 'frames newer than ${now.toUtc().subtract(radarFrameStep * windowFrames)}', actual: 'none');
    }

    final dir = Directory('${(await cacheRoot()).path}/$radarFrameCacheDirName');
    await dir.create(recursive: true);
    Directory frameDir(RadarFrameRef f) => Directory('${dir.path}/${f.stamp}');
    File bandFile(Directory d, int band) => File('${d.path}/$band.webp');
    File statsFile(Directory d) => File('${d.path}/$_statsFileName');

    final keep = {for (final f in window) frameDir(f).path};
    await for (final entity in dir.list()) {
      if (!keep.contains(entity.path)) await entity.delete(recursive: true);
    }

    // ponytail: one frame at a time; each frame's peak is one band encode
    // (~170 MB measured on macOS). Never parallelise without re-measuring on a phone.
    for (final f in window) {
      final target = frameDir(f);
      if (await target.exists()) continue;
      final png = await _dio.get<List<int>>(f.url, options: Options(responseType: ResponseType.bytes));
      final body = png.data ??
          (throw RadarDataException(f.url, expected: 'PNG body', actual: 'HTTP ${png.statusCode} without body'));
      final processed = await _processOffUiIsolate(Uint8List.fromList(body));
      final tmp = Directory('${target.path}.tmp');
      if (await tmp.exists()) await tmp.delete(recursive: true);
      await tmp.create();
      for (var i = 0; i < processed.bands.length; i++) {
        await bandFile(tmp, i).writeAsBytes(processed.bands[i], flush: true);
      }
      await statsFile(tmp).writeAsBytes(processed.stats.toBytes(), flush: true);
      await tmp.rename(target.path);
    }
    return [
      for (final f in window)
        RadarFrame(
          time: f.time,
          bands: [
            for (var i = 0; i < websiteRadarBandBounds.length; i++)
              RadarFrameBand(file: bandFile(frameDir(f), i), bounds: websiteRadarBandBounds[i]),
          ],
          stats: RadarEchoStats.fromBytes(await statsFile(frameDir(f)).readAsBytes(), source: statsFile(frameDir(f)).path),
        ),
    ];
  }
}

/// Per-frame echo statistics file (see [RadarEchoStats.toBytes]).
const _statsFileName = 'echo_stats.bin';

/// Top-level so the isolate closure captures only [png].
Future<({List<Uint8List> bands, RadarEchoStats stats})> _processOffUiIsolate(Uint8List png) =>
    Isolate.run(() => processRadarFrame(png));
