import '../../core/time/taiwan_time.dart';

/// QPEplus native gauge rolling windows (hours), largest first.
const _accumNativeHours = [24, 12, 6, 3, 1];

/// Windows the rainfall page offers, shortest first (the retention of downloaded grids is sized by the last one).
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
  final ymd = '${endUtc.year}${twoDigits(endUtc.month)}${twoDigits(endUtc.day)}';
  return 'https://qpeplus.cwa.gov.tw/static/data/grid/raingage/rain${twoDigits(nativeHours)}h_gage/'
      '${endUtc.year}/${twoDigits(endUtc.month)}/${twoDigits(endUtc.day)}/${twoDigits(endUtc.hour)}/'
      'GAGE_PCP_${nativeHours}H.$ymd.${twoDigits(endUtc.hour)}${twoDigits(endUtc.minute)}.dat';
}
