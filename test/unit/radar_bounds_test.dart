import 'dart:convert';
import 'dart:io';

import 'package:cwb_flutter/data/radar/radar_bounds.dart';
import 'package:cwb_flutter/data/radar/radar_frame_processor.dart';
import 'package:flutter_test/flutter_test.dart';

OpenDataRadarImage _load(String id) => OpenDataRadarImage.fromJson(
    id, jsonDecode(File('test/fixtures/cwa/$id.json').readAsStringSync()) as Map<String, dynamic>);

void main() {
  test('website frame bands tile 17.75..29.25 N, 115..126.5 E without gaps', () {
    final b = websiteRadarBandBounds;
    expect(b, hasLength(radarFrameBands));
    expect(b.first.north, closeTo(29.25, 1e-9));
    expect(b.last.south, closeTo(17.75, 1e-9));
    for (var i = 0; i < b.length; i++) {
      expect((b[i].west, b[i].east), (115.0, 126.5));
      if (i > 0) expect(b[i].north, b[i - 1].south, reason: 'band $i');
    }
    final rows = radarBandRows();
    expect((rows.first.$1, rows.last.$2), (0, radarFrameRowMap.length));
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i].$1, rows[i - 1].$2);
    }
  });

  test('station image response: url and time parsed', () {
    final s = _load('O-A0084-001');
    expect(s.imageUrl, 'https://cwaopendata.s3.ap-northeast-1.amazonaws.com/Observation/O-A0084-001.png');
    expect(s.time.toUtc(), DateTime.utc(2026, 11, 14, 12, 40));
  });

  test('station bounds are centre ± 150 km from the response', () {
    final b = _load('O-A0084-001').bounds; // 樹林 121.40E 25.00N, 距雷達150公里
    const dLat = 150 / 6371.0088 * 57.29577951308232;
    expect(b.south, closeTo(25.0 - dLat, 1e-9));
    expect(b.north, closeTo(25.0 + dLat, 1e-9));
    expect(b.east - b.west, closeTo(2 * dLat / 0.9063077870366499, 1e-9)); // cos 25°
    expect((b.east + b.west) / 2, closeTo(121.40, 1e-9));
  });

  test('missing bounds fields fail loudly', () {
    final json = jsonDecode(File('test/fixtures/cwa/O-A0084-002.json').readAsStringSync()) as Map<String, dynamic>;
    (json['cwaopendata']['dataset']['datasetInfo']['parameterSet'] as Map).remove('StationLatitude');
    expect(() => OpenDataRadarImage.fromJson('O-A0084-002', json), throwsFormatException);
  });
}
