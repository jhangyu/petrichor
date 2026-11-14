import 'dart:typed_data';

import 'package:cwb_flutter/data/models/place.dart';
import 'package:cwb_flutter/data/radar/radar_bounds.dart';
import 'package:cwb_flutter/data/radar/radar_echo_stats.dart';
import 'package:cwb_flutter/data/radar/radar_frame_processor.dart';
import 'package:cwb_flutter/features/radar/radar_summary.dart';
import 'package:cwb_flutter/features/radar/widgets/radar_legend.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const _columns = radarFrameSize ~/ radarStatsCellPixels;

/// Stats over [frame] with [strongest] dBZ reached by enough pixels and the
/// given cell band pixels keyed (col, row, band).
RadarEchoStats _frame({required int strongest, Map<(int, int, int), int> cells = const {}, LatLngBounds? frame}) {
  final grid = Uint16List(_columns * _columns * radarDbzBands);
  cells.forEach((k, px) => grid[(k.$2 * _columns + k.$1) * radarDbzBands + k.$3] = px);
  return RadarEchoStats(
    frame: frame ?? websiteRadarFrameBounds,
    imageWidth: radarFrameSize,
    imageHeight: radarFrameSize,
    pixelsPerDbz: [for (var d = 0; d < radarEchoPalette.length; d++) d == strongest ? 100000 : 0],
    cellBandPixels: grid,
    gridColumns: _columns,
    gridRows: _columns,
  );
}

const _taipei = Place(county: '臺北市', town: '中正區', latitude: 25.046058, longitude: 121.516565);
const _coverage = '臺灣本島及周邊海域';

void main() {
  test('colour names follow the CWA scale hue families', () {
    final names = {for (var d = 0; d <= 65; d++) d: radarDbzColourName(d)};
    expect([names[5], names[6], names[14], names[15], names[25], names[26], names[30], names[36]],
        ['淺藍', '藍', '藍', '綠', '綠', '黃綠', '黃', '橙']);
    expect([names[44], names[45], names[55], names[56], names[59], names[60], names[65]],
        ['橙', '紅', '紅', '紫紅', '紫紅', '紫', '紫']);
  });

  test('keying palette is the CWA scale sampled from the frame legend bar', () {
    expect(radarEchoPalette.length, 66);
    expect([radarEchoPalette[0], radarEchoPalette[15], radarEchoPalette[30], radarEchoPalette[45], radarEchoPalette[65]],
        [0x00ffff, 0x00ff00, 0xffff00, 0xff0000, 0x9600ff]);
  });

  test('below the significant level: 無明顯回波 with the coverage name', () {
    final s = radarEchoSummary(_frame(strongest: radarSignificantEchoDbz - 1), coverage: _coverage);
    expect(s, (title: '目前無明顯回波', meta: '資料正常更新；臺灣本島及周邊海域未偵測到降雨訊號'));
  });

  test('strong regions are named in fixed order; band near the place', () {
    final s = radarEchoSummary(
      _frame(strongest: 45, cells: {(92, 115, 4): 200, (113, 73, 3): 200}),
      coverage: _coverage,
      place: _taipei,
    );
    expect(s.title, '南部有強回波');
    expect(s.meta, '最強約 45 dBZ（紅） · 臺北市 中正區附近30–40 dBZ');
  });

  test('no strong region: regions with rain echo in order; weak echo near the place', () {
    final s = radarEchoSummary(
      _frame(strongest: 39, cells: {(139, 126, 3): 200, (113, 73, 3): 200, (113, 75, 1): 500}),
      coverage: _coverage,
      place: _taipei,
    );
    expect(s.title, '北部、外海有降雨回波');
    expect(s.meta, '最強約 39 dBZ（橙） · 臺北市 中正區附近30–40 dBZ');
    final weak = radarEchoSummary(_frame(strongest: 39, cells: {(113, 73, 1): 500}), coverage: _coverage, place: _taipei);
    expect(weak.title, '目前有零星回波');
    expect(weak.meta, '最強約 39 dBZ（橙） · 臺北市 中正區附近無明顯回波');
  });

  test('station geometry: cells map through the station bounds; top band label', () {
    // 樹林 radar (O-A0084-001): centre 25.00 N 121.40 E, ±150 km; image centre
    // cell (100, 100) is the station, in 北部. Station pixels are ~0.007 km²,
    // so the area rule needs ~1,700 px: 2 x 1,000 px.
    final bounds = stationRadarBounds(const LatLng(25.0, 121.4), radiusKm: 150);
    final s = radarEchoSummary(
      _frame(strongest: 62, frame: bounds, cells: {(100, 100, 6): 1000, (101, 100, 6): 1000}),
      coverage: '樹林雷達站涵蓋範圍內',
      place: const Place(county: '新北市', town: '樹林區', latitude: 25.0, longitude: 121.4),
    );
    expect(s.title, '北部有強回波');
    expect(s.meta, '最強約 62 dBZ（紫） · 新北市 樹林區附近60+ dBZ');
  });
}
