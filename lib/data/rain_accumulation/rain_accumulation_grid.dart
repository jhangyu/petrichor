import 'dart:typed_data';

const accumulationGridWidth = 441;
const accumulationGridHeight = 561;

/// Raw unit = 0.25 mm.
const accumulationRawUnitsPerMillimeter = 4;

const _headerLine = '441,561,c,118.00,20.00,123.50,27.00,int16,0,0,EPSG:4326';
const _transformLine = 'linearTransform(0.2500,0.0000)';

/// Lower edges (mm) of colours 1.. of `AppPalette.rainfallMapScale`; colour 0 is below the first edge.
const accumulationScaleEdgesMillimeters = [
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
class AccumulationGrid {
  AccumulationGrid(this.raw);
  final Int16List raw;
}

class AccumulationFormatException extends FormatException {
  AccumulationFormatException(String url, String field, Object expected, Object actual)
    : super('QPEplus grid $url: $field expected $expected but was $actual');
}

List<int> _ints(String url, String line, String prefix) {
  if (!line.startsWith(prefix)) {
    throw AccumulationFormatException(
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

/// Parses a QPEplus CSR grid ([text] from [url]); throws [AccumulationFormatException] on any mismatch.
AccumulationGrid parseAccumulationGrid(String text, {required String url}) {
  final lines = text.split('\n');
  if (lines.length < 7) {
    throw AccumulationFormatException(url, 'line count', '>= 7', lines.length);
  }
  if (lines[0].trim() != _headerLine) {
    throw AccumulationFormatException(url, 'header', _headerLine, lines[0].trim());
  }
  if (lines[1].trim() != _transformLine) {
    throw AccumulationFormatException(
      url,
      'transform',
      _transformLine,
      lines[1].trim(),
    );
  }
  // lines[2] is the per-file colour scale, unused.
  final nonZeroCount = _ints(url, lines[3].trim(), 'ndv:').single;
  final columnIndices = _ints(url, lines[4].trim(), 'colIdx:');
  final rowPointers = _ints(url, lines[5].trim(), 'rowPtr:');
  final values = _ints(url, lines[6].trim(), 'vals:');
  if (columnIndices.length != nonZeroCount) {
    throw AccumulationFormatException(url, 'colIdx length', nonZeroCount, columnIndices.length);
  }
  if (values.length != nonZeroCount) {
    throw AccumulationFormatException(url, 'vals length', nonZeroCount, values.length);
  }
  if (rowPointers.length != accumulationGridHeight + 1) {
    throw AccumulationFormatException(
      url,
      'rowPtr length',
      accumulationGridHeight + 1,
      rowPointers.length,
    );
  }
  if (rowPointers.first != 0 || rowPointers.last != nonZeroCount) {
    throw AccumulationFormatException(
      url,
      'rowPtr first/last',
      '0/$nonZeroCount',
      '${rowPointers.first}/${rowPointers.last}',
    );
  }
  final raw = Int16List(accumulationGridWidth * accumulationGridHeight);
  for (var row = 0; row < accumulationGridHeight; row++) {
    if (rowPointers[row + 1] < rowPointers[row]) {
      throw AccumulationFormatException(
        url,
        'rowPtr[${row + 1}]',
        '>= ${rowPointers[row]}',
        rowPointers[row + 1],
      );
    }
    for (var i = rowPointers[row]; i < rowPointers[row + 1]; i++) {
      final col = columnIndices[i];
      if (col < 0 || col >= accumulationGridWidth) {
        throw AccumulationFormatException(
          url,
          'colIdx[$i]',
          '0..${accumulationGridWidth - 1}',
          col,
        );
      }
      raw[row * accumulationGridWidth + col] = values[i];
    }
  }
  return AccumulationGrid(raw);
}

/// First partial hour of a 10-min frame (contract decision 12): the rain from
/// S to S + [minutes], estimated per cell as [end] − [start]·(60 − [minutes])/60,
/// where [end] and [start] are the 1 h grids ending at S + [minutes] and at S.
typedef AccumulationPartialHour = ({AccumulationGrid end, AccumulationGrid start, int minutes});

/// Cell-wise frame total in raw units: [partial] (the scaled subtraction
/// rounded to the nearest raw unit, halves up; a negative estimate is 0) plus
/// every [whole] grid.
Int32List accumulationFrameSum(List<AccumulationGrid> whole, {AccumulationPartialHour? partial}) {
  if (whole.isEmpty && partial == null) {
    throw ArgumentError.value(whole, 'whole', 'expected at least one grid or a partial hour');
  }
  final sum = Int32List(accumulationGridWidth * accumulationGridHeight);
  if (partial case (:final end, :final start, :final minutes)) {
    if (minutes <= 0 || minutes >= 60) {
      throw ArgumentError.value(minutes, 'minutes', 'expected 1..59');
    }
    final keep = 60 - minutes;
    for (var i = 0; i < sum.length; i++) {
      final c = end.raw[i] - (start.raw[i] * keep + 30) ~/ 60;
      if (c > 0) sum[i] = c;
    }
  }
  for (final g in whole) {
    for (var i = 0; i < sum.length; i++) {
      sum[i] += g.raw[i];
    }
  }
  return sum;
}

/// Index into `AppPalette.rainfallMapScale` for [rawSum]; -1 = transparent
/// (below 1 mm, not drawn, as on the forecast map).
int accumulationColorIndex(int rawSum) {
  if (rawSum < accumulationScaleEdgesMillimeters.first * accumulationRawUnitsPerMillimeter) return -1;
  var index = 0;
  while (index < accumulationScaleEdgesMillimeters.length &&
      rawSum >= accumulationScaleEdgesMillimeters[index] * accumulationRawUnitsPerMillimeter) {
    index++;
  }
  return index;
}
