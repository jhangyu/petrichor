import 'dart:typed_data';

import 'package:cwb_flutter/data/models/place.dart';
import 'package:cwb_flutter/data/radar/radar_echo_stats.dart';
import 'package:cwb_flutter/data/radar/radar_frame_processor.dart';
import 'package:cwb_flutter/features/radar/radar_summary.dart';
import 'package:flutter_test/flutter_test.dart';

const _columns = radarFrameSize ~/ radarStatsCellPixels;

/// Full-frame stats with [strongest] dBZ somewhere and [nearTaipei] in the
/// Taipei cell (113, 73).
RadarEchoStats _frame({required int strongest, int? nearTaipei}) {
  final cells = Uint8List(_columns * _columns)..fillRange(0, _columns * _columns, radarNoEcho);
  if (nearTaipei != null) cells[73 * _columns + 113] = nearTaipei;
  return RadarEchoStats(
    pixelsPerDbz: [for (var d = 0; d < radarEchoPalette.length; d++) d == strongest ? radarEchoMinPixels : 0],
    cellMaxDbz: cells,
    gridColumns: _columns,
    gridRows: _columns,
  );
}

const _taipei = Place(county: '臺北市', town: '中正區', latitude: 25.046058, longitude: 121.516565);

void main() {
  test('below the significant level: 無明顯回波', () {
    expect(radarEchoSummary(_frame(strongest: radarSignificantEchoDbz - 1)).title, '目前無明顯回波');
  });

  test('strong echo with echo near the place', () {
    final s = radarEchoSummary(_frame(strongest: 45, nearTaipei: 32), place: _taipei);
    expect(s.title, '目前有強回波');
    expect(s.meta, '最強約 45 dBZ（橙） · 臺北市 中正區附近最強約 32 dBZ');
  });

  test('moderate echo, only weak echo near the place', () {
    final s = radarEchoSummary(_frame(strongest: radarStrongEchoDbz - 1, nearTaipei: 12), place: _taipei);
    expect(s.title, '目前有降雨回波');
    expect(s.meta, '最強約 39 dBZ（黃） · 臺北市 中正區附近無明顯回波');
  });
}
