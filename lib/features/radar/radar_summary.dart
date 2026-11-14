import 'package:latlong2/latlong.dart';

import '../../data/models/place.dart';
import '../../data/radar/radar_echo_stats.dart';
import '../../data/radar/radar_frame_processor.dart';
import 'widgets/radar_legend.dart';

/// Region names in summary order (matches the [radarRegions] groups).
const _regionOrder = ['北部', '中部', '南部', '東部', '離島', radarOpenSeaRegion];

/// Hero one-liner and meta line for one image's echo statistics; [coverage]
/// names the area in the no-echo text.
({String title, String meta}) radarEchoSummary(RadarEchoStats stats, {required String coverage, Place? place}) {
  final strongest = stats.strongestDbz;
  if (strongest == null || !stats.hasSignificantEcho) {
    return (title: '目前無明顯回波', meta: '資料正常更新；$coverage未偵測到降雨訊號');
  }
  final regions = stats.regionBands();
  List<String> reaching(int dbz) => [
        for (final r in _regionOrder)
          if ((regions[r] ?? -1) >= dbz) r,
      ];
  final strong = reaching(radarStrongEchoDbz);
  final rain = reaching(radarSignificantEchoDbz);
  final title = strong.isNotEmpty
      ? '${strong.join('、')}有強回波'
      : rain.isNotEmpty
          ? '${rain.join('、')}有降雨回波'
          : '目前有零星回波';
  final overall = '最強約 $strongest dBZ（${radarDbzColourName(strongest)}）';
  if (place == null) return (title: title, meta: overall);
  final band = stats.bandNear(LatLng(place.latitude, place.longitude));
  final local = band != null && band >= radarSignificantEchoDbz ? radarDbzBandLabel(band) : '無明顯回波';
  return (title: title, meta: '$overall · ${place.county} ${place.town}附近$local');
}

/// `30–40 dBZ`; the top band is open-ended (`60+ dBZ`).
String radarDbzBandLabel(int bandStart) => bandStart + radarDbzBandWidth > radarEchoPalette.length - 1
    ? '$bandStart+ dBZ'
    : '$bandStart–${bandStart + radarDbzBandWidth} dBZ';
