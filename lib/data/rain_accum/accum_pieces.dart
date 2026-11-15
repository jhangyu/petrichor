/// QPEplus native gauge rolling windows (hours), largest first.
const _accumNativeHours = [24, 12, 6, 3, 1];

/// Windows the rainfall page offers.
const accumWindowHours = [4, 6, 12, 24, 48, 168];

/// URL of the native [nativeHours] grid ending at [endUtc] (UTC, minute a multiple of 10).
String accumPieceUrl(int nativeHours, DateTime endUtc) {
  if (!_accumNativeHours.contains(nativeHours)) {
    throw ArgumentError.value(
      nativeHours,
      'nativeHours',
      'expected one of $_accumNativeHours',
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
