import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cwb_flutter/core/theme/app_tokens.dart';
import 'package:cwb_flutter/data/rain_accum/accum_grid.dart';
import 'package:cwb_flutter/data/rain_accum/accum_pieces.dart';
import 'package:cwb_flutter/features/hazard/rainfall/rainfall_logic.dart';
import 'package:flutter_test/flutter_test.dart';

AccumGrid load(String name) {
  final text = utf8.decode(
    gzip.decode(
      File('test/fixtures/rain_accum/$name.dat.gz').readAsBytesSync(),
    ),
  );
  return parseAccumGrid(text, url: name);
}

void main() {
  final g1050 = load('g01_20261115_1050');
  final g0950 = load('g01_20261115_0950');
  final g0850 = load('g01_20261115_0850');
  final g0750 = load('g01_20261115_0750');
  final g3h = load('g03_20261115_1050');

  test('3 x 1h equals native 3h', () {
    final sum = sumAccumGrids([g1050, g0950, g0850]);
    expect(sum.any((v) => v > 0), isTrue);
    expect(sum, orderedEquals(g3h.raw));
  });

  test('3h + 1h composition equals 4 x 1h', () {
    final pieces = accumPieces(4);
    final byKey = {(3, 0): g3h, (1, 3): g0750};
    final composed = sumAccumGrids([
      for (final p in pieces) byKey[(p.nativeHours, p.offsetHours)]!,
    ]);
    expect(
      composed,
      orderedEquals(sumAccumGrids([g1050, g0950, g0850, g0750])),
    );
  });

  test('accumPieces for every window', () {
    expect(accumWindowHours, [4, 6, 12, 24, 48, 168]);
    String show(int w) => accumPieces(
      w,
    ).map((p) => '${p.nativeHours}@${p.offsetHours}').join(' ');
    expect(show(4), '3@0 1@3');
    expect(show(6), '6@0');
    expect(show(12), '12@0');
    expect(show(24), '24@0');
    expect(show(48), '24@0 24@24');
    expect(show(168), List.generate(7, (i) => '24@${i * 24}').join(' '));
  });

  test('accumPieceUrl matches a real URL', () {
    expect(
      accumPieceUrl(3, DateTime.utc(2026, 11, 15, 10, 50)),
      'https://qpeplus.cwa.gov.tw/static/data/grid/raingage/rain03h_gage/2026/11/15/10/GAGE_PCP_3H.20261115.1050.dat',
    );
    expect(
      () => accumPieceUrl(2, DateTime.utc(2026, 11, 15, 10, 50)),
      throwsArgumentError,
    );
    expect(
      () => accumPieceUrl(1, DateTime.utc(2026, 11, 15, 10, 55)),
      throwsArgumentError,
    );
  });

  test('parse rejects a wrong header naming expected, actual and url', () {
    expect(
      () => parseAccumGrid(
        '440,561,c\nx\n\nndv:0\ncolIdx:\nrowPtr:\nvals:\n',
        url: 'u://bad',
      ),
      throwsA(
        isA<AccumFormatException>().having(
          (e) => e.message,
          'message',
          allOf(contains('u://bad'), contains('441,561'), contains('440,561')),
        ),
      ),
    );
  });

  test('scale edges match palette and legend', () {
    expect(accumScaleEdgesMm.length + 1, AppPalette.rainfallMapScale.length);
    expect(accumScaleEdgesMm.length + 1, rainfallMapScaleLabels.length);
  });

  test('accumColorIndex maps raw units to scale index', () {
    expect(accumColorIndex(0), -1);
    expect(accumColorIndex(1), -1); // 0.25 mm
    expect(accumColorIndex(3), -1); // 0.75 mm
    expect(accumColorIndex(4), 1); // 1 mm
    expect(accumColorIndex(1199), 15); // 299.75 mm
    expect(accumColorIndex(1200), 16); // 300 mm
    expect(accumColorIndex(Int32List.fromList([1000000])[0]), 16);
  });
}
