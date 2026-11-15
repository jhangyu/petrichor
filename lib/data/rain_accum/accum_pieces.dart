/// QPEplus native gauge rolling windows (hours), largest first.
const accumNativeHours = [24, 12, 6, 3, 1];

/// One native grid of a composed window: [nativeHours] long, ending
/// [offsetHours] before the frame end time.
typedef AccumPiece = ({int nativeHours, int offsetHours});

/// Windows the rainfall page offers.
const accumWindowHours = [4, 6, 12, 24, 48, 168];

/// Greedy largest-first decomposition of [windowHours] into native grids.
List<AccumPiece> accumPieces(int windowHours) {
  if (windowHours < 1) {
    throw ArgumentError.value(windowHours, 'windowHours', 'expected >= 1');
  }
  final pieces = <AccumPiece>[];
  var offset = 0;
  for (final native in accumNativeHours) {
    while (windowHours - offset >= native) {
      pieces.add((nativeHours: native, offsetHours: offset));
      offset += native;
    }
  }
  return pieces;
}

/// URL of the native [nativeHours] grid ending at [endUtc] (UTC, minute a multiple of 10).
String accumPieceUrl(int nativeHours, DateTime endUtc) {
  if (!accumNativeHours.contains(nativeHours)) {
    throw ArgumentError.value(
      nativeHours,
      'nativeHours',
      'expected one of $accumNativeHours',
    );
  }
  if (!endUtc.isUtc || endUtc.minute % 10 != 0) {
    throw ArgumentError.value(
      endUtc,
      'endUtc',
      'expected UTC with minute a multiple of 10',
    );
  }
  String two(int v) => v.toString().padLeft(2, '0');
  final ymd = '${endUtc.year}${two(endUtc.month)}${two(endUtc.day)}';
  return 'https://qpeplus.cwa.gov.tw/static/data/grid/raingage/rain${two(nativeHours)}h_gage/'
      '${endUtc.year}/${two(endUtc.month)}/${two(endUtc.day)}/${two(endUtc.hour)}/'
      'GAGE_PCP_${nativeHours}H.$ymd.${two(endUtc.hour)}${two(endUtc.minute)}.dat';
}
