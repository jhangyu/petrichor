import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Streams the rows of an 8-bit, non-interlaced RGB PNG to [onRow] (row [y],
/// `width * 3` bytes R,G,B; the buffer is reused, copy what you keep) without
/// ever holding the decoded image: the IDAT data is inflated in chunks and
/// each row is un-filtered against the previous one. Peak memory is the PNG
/// bytes plus a few row buffers, where decoding the whole image takes ~66 MB
/// for a 3600x3600 frame. The image must be [size] x [size].
void readPngRgbRows(Uint8List png, int size, void Function(int y, Uint8List rgb) onRow) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  const chunkHeader = 8; // length + type
  const chunkCrc = 4;
  const ihdrLength = 13;
  if (png.length < signature.length || !_startsWith(png, signature)) {
    throw FormatException('radar image: expected PNG bytes, got ${png.length} bytes not starting with the PNG signature');
  }
  final data = ByteData.sublistView(png);
  final idat = BytesBuilder(copy: false);
  var position = signature.length;
  var sawHeader = false;
  while (position + chunkHeader <= png.length) {
    final length = data.getUint32(position);
    final type = String.fromCharCodes(png, position + 4, position + 8);
    final body = position + chunkHeader;
    if (body + length > png.length) {
      throw FormatException('radar image: expected $type chunk of $length bytes at $body, only ${png.length - body} left');
    }
    if (type == 'IEND') break;
    if (!sawHeader && type != 'IHDR') throw FormatException('radar image: expected IHDR first, got $type');
    if (type == 'IHDR') {
      if (length != ihdrLength) throw FormatException('radar image: expected IHDR of $ihdrLength bytes, got $length');
      final width = data.getUint32(body), height = data.getUint32(body + 4);
      final bitDepth = png[body + 8], colourType = png[body + 9], interlace = png[body + 12];
      if (width != size || height != size) throw FormatException('radar image: expected ${size}x$size, got ${width}x$height');
      if (bitDepth != 8 || colourType != 2 || interlace != 0) {
        throw FormatException('radar image: expected 8-bit RGB without palette or interlacing, got bit depth $bitDepth, '
            'colour type $colourType (2 = RGB), interlace $interlace');
      }
      sawHeader = true;
    } else if (type == 'IDAT') {
      idat.add(Uint8List.sublistView(png, body, body + length));
    }
    position = body + length + chunkCrc;
  }
  if (!sawHeader) throw const FormatException('radar image: expected an IHDR chunk, found none');
  final rows = _RowSink(size, onRow);
  final inflater = ZLibDecoder().startChunkedConversion(rows);
  inflater.add(idat.takeBytes());
  inflater.close();
  rows.finish();
}

bool _startsWith(Uint8List bytes, List<int> prefix) {
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

/// Receives the inflated IDAT stream (per row: a filter byte, then `size * 3`
/// filtered bytes) in arbitrary pieces.
class _RowSink implements Sink<List<int>> {
  _RowSink(this.size, this.onRow)
      : rowBytes = size * _bytesPerPixel,
        currentRow = Uint8List(size * _bytesPerPixel),
        previousRow = Uint8List(size * _bytesPerPixel);

  static const _bytesPerPixel = 3;
  static const _filterNone = 0, _filterSub = 1, _filterUp = 2, _filterAverage = 3, _filterPaeth = 4;

  final int size;
  final int rowBytes;
  final void Function(int y, Uint8List rgb) onRow;
  Uint8List currentRow, previousRow;
  int y = 0;
  int filled = 0;
  int? filter;

  @override
  void add(List<int> chunk) {
    var i = 0;
    while (i < chunk.length) {
      if (y >= size) throw FormatException('radar image: expected $size rows, got inflated data beyond the last row');
      final f = filter;
      if (f == null) {
        final value = chunk[i++];
        if (value > _filterPaeth) throw FormatException('radar image: expected PNG filter 0..4, got $value at row $y');
        filter = value;
        continue;
      }
      final n = min(rowBytes - filled, chunk.length - i);
      currentRow.setRange(filled, filled + n, chunk, i);
      filled += n;
      i += n;
      if (filled == rowBytes) {
        _unfilter(f);
        onRow(y, currentRow);
        final done = currentRow;
        currentRow = previousRow;
        previousRow = done;
        y++;
        filled = 0;
        filter = null;
      }
    }
  }

  @override
  void close() {}

  /// Called after the inflater closed: the stream must have ended on a row boundary.
  void finish() {
    if (y != size) throw FormatException('radar image: expected $size rows, got $y');
  }

  void _unfilter(int f) {
    const bpp = _bytesPerPixel;
    switch (f) {
      case _filterNone:
        break;
      case _filterSub:
        for (var i = bpp; i < rowBytes; i++) {
          currentRow[i] = (currentRow[i] + currentRow[i - bpp]) & 0xFF;
        }
      case _filterUp:
        for (var i = 0; i < rowBytes; i++) {
          currentRow[i] = (currentRow[i] + previousRow[i]) & 0xFF;
        }
      case _filterAverage:
        for (var i = 0; i < rowBytes; i++) {
          final left = i >= bpp ? currentRow[i - bpp] : 0;
          currentRow[i] = (currentRow[i] + ((left + previousRow[i]) >> 1)) & 0xFF;
        }
      case _filterPaeth:
        for (var i = 0; i < rowBytes; i++) {
          final a = i >= bpp ? currentRow[i - bpp] : 0, b = previousRow[i], c = i >= bpp ? previousRow[i - bpp] : 0;
          final p = a + b - c;
          final pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
          currentRow[i] = (currentRow[i] + (pa <= pb && pa <= pc ? a : (pb <= pc ? b : c))) & 0xFF;
        }
    }
  }
}
