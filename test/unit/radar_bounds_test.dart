import 'dart:convert';
import 'dart:io';

import 'package:cwb_flutter/data/radar/radar_bounds.dart';
import 'package:flutter_test/flutter_test.dart';

OpenDataRadarImage _load(String id) => OpenDataRadarImage.fromJson(
    id, jsonDecode(File('test/fixtures/cwa/$id.json').readAsStringSync()) as Map<String, dynamic>);

void main() {
  test('composite bounds come from LongitudeRange/LatitudeRange', () {
    final wide = _load('O-A0058-001');
    expect([wide.bounds.south, wide.bounds.west, wide.bounds.north, wide.bounds.east], [17.75, 115.0, 29.25, 126.5]);
    expect(wide.imageUrl, 'https://cwaopendata.s3.ap-northeast-1.amazonaws.com/Observation/O-A0058-001.png');
    expect(wide.time, DateTime.utc(2026, 11, 14, 12, 30));
    final near = _load('O-A0058-003');
    expect([near.bounds.south, near.bounds.west, near.bounds.north, near.bounds.east], [20.5, 118.0, 26.5, 124.0]);
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
