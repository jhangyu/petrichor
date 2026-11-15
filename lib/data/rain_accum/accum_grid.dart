import 'dart:typed_data';

const accumGridWidth = 441;
const accumGridHeight = 561;

/// Raw unit = 0.25 mm.
const accumRawPerMm = 4;

const _headerLine = '441,561,c,118.00,20.00,123.50,27.00,int16,0,0,EPSG:4326';
const _transformLine = 'linearTransform(0.2500,0.0000)';

/// Lower edges (mm) of colours 1.. of `AppPalette.rainfallMapScale`; colour 0 is below the first edge.
/// Same boundaries as `rainfallMapScaleLabels`.
const accumScaleEdgesMm = [
  1,
  2,
  6,
  10,
  15,
  20,
  30,
  40,
  50,
  70,
  90,
  110,
  130,
  150,
  200,
  300,
];

/// Dense raw grid, row 0 = south, column 0 = west.
class AccumGrid {
  AccumGrid(this.raw);
  final Int16List raw;
}

class AccumFormatException extends FormatException {
  AccumFormatException(String url, String field, Object expected, Object actual)
    : super('QPEplus grid $url: $field expected $expected but was $actual');
}

List<int> _ints(String url, String line, String prefix) {
  if (!line.startsWith(prefix)) {
    throw AccumFormatException(
      url,
      'line prefix',
      prefix,
      line.split(':').first,
    );
  }
  final body = line.substring(prefix.length);
  if (body.isEmpty) return const [];
  return [for (final s in body.split(',')) int.parse(s)];
}

/// Parses a QPEplus CSR grid ([text] from [url]); throws [AccumFormatException] on any mismatch.
AccumGrid parseAccumGrid(String text, {required String url}) {
  final lines = text.split('\n');
  if (lines.length < 7) {
    throw AccumFormatException(url, 'line count', '>= 7', lines.length);
  }
  if (lines[0].trim() != _headerLine) {
    throw AccumFormatException(url, 'header', _headerLine, lines[0].trim());
  }
  if (lines[1].trim() != _transformLine) {
    throw AccumFormatException(
      url,
      'transform',
      _transformLine,
      lines[1].trim(),
    );
  }
  // lines[2] is the per-file colour scale, unused.
  final ndv = _ints(url, lines[3].trim(), 'ndv:').single;
  final colIdx = _ints(url, lines[4].trim(), 'colIdx:');
  final rowPtr = _ints(url, lines[5].trim(), 'rowPtr:');
  final vals = _ints(url, lines[6].trim(), 'vals:');
  if (colIdx.length != ndv) {
    throw AccumFormatException(url, 'colIdx length', ndv, colIdx.length);
  }
  if (vals.length != ndv) {
    throw AccumFormatException(url, 'vals length', ndv, vals.length);
  }
  if (rowPtr.length != accumGridHeight + 1) {
    throw AccumFormatException(
      url,
      'rowPtr length',
      accumGridHeight + 1,
      rowPtr.length,
    );
  }
  if (rowPtr.first != 0 || rowPtr.last != ndv) {
    throw AccumFormatException(
      url,
      'rowPtr first/last',
      '0/$ndv',
      '${rowPtr.first}/${rowPtr.last}',
    );
  }
  final raw = Int16List(accumGridWidth * accumGridHeight);
  for (var row = 0; row < accumGridHeight; row++) {
    if (rowPtr[row + 1] < rowPtr[row]) {
      throw AccumFormatException(
        url,
        'rowPtr[${row + 1}]',
        '>= ${rowPtr[row]}',
        rowPtr[row + 1],
      );
    }
    for (var i = rowPtr[row]; i < rowPtr[row + 1]; i++) {
      final col = colIdx[i];
      if (col < 0 || col >= accumGridWidth) {
        throw AccumFormatException(
          url,
          'colIdx[$i]',
          '0..${accumGridWidth - 1}',
          col,
        );
      }
      raw[row * accumGridWidth + col] = vals[i];
    }
  }
  return AccumGrid(raw);
}

/// Cell-wise sum in raw units.
Int32List sumAccumGrids(List<AccumGrid> grids) {
  if (grids.isEmpty) {
    throw ArgumentError.value(grids, 'grids', 'expected at least one grid');
  }
  final sum = Int32List(accumGridWidth * accumGridHeight);
  for (final g in grids) {
    for (var i = 0; i < sum.length; i++) {
      sum[i] += g.raw[i];
    }
  }
  return sum;
}

/// Index into `AppPalette.rainfallMapScale` for [rawSum]; -1 = transparent
/// (below 1 mm, not drawn, as on the forecast map).
int accumColorIndex(int rawSum) {
  if (rawSum < accumScaleEdgesMm.first * accumRawPerMm) return -1;
  var index = 0;
  while (index < accumScaleEdgesMm.length &&
      rawSum >= accumScaleEdgesMm[index] * accumRawPerMm) {
    index++;
  }
  return index;
}
