import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cwb_flutter/core/theme/app_tokens.dart';
import 'package:cwb_flutter/data/rain_accum/accum_grid.dart';
import 'package:cwb_flutter/data/rain_accum/accum_pieces.dart';
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
  final g3h = load('g03_20261115_1050');

  test('3 x 1h equals native 3h', () {
    final sum = accumFrameSum([g1050, g0950, g0850]);
    expect(sum.any((v) => v > 0), isTrue);
    expect(sum, orderedEquals(g3h.raw));
  });

  test('partial hour: R1(S+m) - R1(S)(60-m)/60 per cell, rounded, clamped at 0, then whole grids', () {
    for (final m in [10, 20, 30, 40, 50]) {
      // Earlier hour 09:50 as R1(S), 10:50 as R1(S+m); 08:50 as a whole grid.
      final sum = accumFrameSum([g0850], partial: (end: g1050, start: g0950, minutes: m));
      var clamped = 0;
      for (var i = 0; i < sum.length; i++) {
        final estimate = g1050.raw[i] - (g0950.raw[i] * (60 - m) / 60).round();
        if (estimate < 0) clamped++;
        expect(sum[i], max(0, estimate) + g0850.raw[i], reason: 'm $m cell $i');
      }
      expect(clamped, greaterThan(0), reason: 'm $m: the fixtures have negative estimates');
    }
  });

  test('accumFrameSum rejects nothing to sum and a whole-hour partial', () {
    expect(() => accumFrameSum([]), throwsArgumentError);
    expect(() => accumFrameSum([], partial: (end: g1050, start: g0950, minutes: 60)), throwsArgumentError);
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

  test('scale edges match palette', () {
    expect(accumScaleEdgesMm.length + 1, AppPalette.rainfallMapScale.length);
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
