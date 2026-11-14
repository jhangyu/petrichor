import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';

import 'radar_frame_list.dart';
import 'radar_frame_processor.dart';

/// Credit required by the CWA licence (「註明出處」).
const radarSourceCredit = '資料來源：中央氣象署';

/// Cache sub-directory; the suffix changes whenever processing output changes,
/// so frames made by an older pipeline are never shown.
const radarFrameCacheDirName = 'radar_cv1_3600_webp_v1';

/// One processed, cached frame (transparent lossless WebP, Web Mercator rows,
/// extent `websiteRadarBounds`).
class RadarFrame {
  final DateTime time;
  final File file;

  const RadarFrame({required this.time, required this.file});

  /// Decoded at [decodeWidth] px, not at full 3600 px: one full-size decoded
  /// frame is ~54 MB, so the loop must use a display-size width and only the
  /// paused, zoomed-in frame may use the full width.
  ImageProvider imageProvider({required int decodeWidth}) =>
      ResizeImage(FileImage(file), width: decodeWidth, policy: ResizeImagePolicy.fit);
}

/// Downloads the website frame window, processes new frames off the UI
/// isolate, and keeps exactly the current window on disk.
class RadarFrameRepository {
  final Dio _dio;
  final Future<Directory> Function() cacheRoot;
  final DateTime Function() clock;

  RadarFrameRepository(this._dio, {required this.cacheRoot, required this.clock});

  /// Returns the last [windowFrames] frames, oldest first. Already-cached
  /// frames are not downloaded again; files outside the window are deleted.
  Future<List<RadarFrame>> refresh({required int windowFrames}) async {
    final listResponse = await _dio.get<String>(
      radarFrameListUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final now = clock();
    final window =
        selectRadarFrameWindow(parseRadarFrameList(listResponse.data ?? ''), now: now, windowFrames: windowFrames);
    if (window.isEmpty) {
      throw StateError('radar frames: expected frames newer than ${now.toUtc().subtract(radarFrameStep * windowFrames)} '
          'in $radarFrameListUrl, found none');
    }

    final dir = Directory('${(await cacheRoot()).path}/$radarFrameCacheDirName');
    await dir.create(recursive: true);
    File fileOf(RadarFrameRef f) => File('${dir.path}/${f.stamp}.webp');

    final keep = {for (final f in window) fileOf(f).path};
    await for (final entity in dir.list()) {
      if (!keep.contains(entity.path)) await entity.delete(recursive: true);
    }

    // ponytail: one frame at a time keeps peak memory at one decode+encode
    // (~500 MB measured on macOS, mostly the lossless WebP encoder); never
    // parallelise without re-measuring memory on a phone.
    for (final f in window) {
      final file = fileOf(f);
      if (await file.exists()) continue;
      final png = await _dio.get<List<int>>(f.url, options: Options(responseType: ResponseType.bytes));
      final body = png.data ?? (throw StateError('radar frame ${f.url}: expected PNG body, got none'));
      final webp = await _processOffUiIsolate(Uint8List.fromList(body));
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(webp, flush: true);
      await tmp.rename(file.path);
    }
    return [for (final f in window) RadarFrame(time: f.time, file: fileOf(f))];
  }
}

/// Top-level so the isolate closure captures only [png].
Future<Uint8List> _processOffUiIsolate(Uint8List png) => Isolate.run(() => processRadarFrame(png));
