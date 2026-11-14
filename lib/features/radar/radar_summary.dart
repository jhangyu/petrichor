import 'package:latlong2/latlong.dart';

import '../../data/models/place.dart';
import '../../data/radar/radar_echo_stats.dart';
import 'widgets/radar_legend.dart';

/// Hero one-liner and meta line for a composite frame's echo statistics.
({String title, String meta}) radarEchoSummary(RadarEchoStats stats, {Place? place}) {
  final strongest = stats.strongestDbz;
  if (strongest == null || !stats.hasSignificantEcho) {
    return (title: '目前無明顯回波', meta: '資料正常更新；臺灣本島及周邊海域未偵測到降雨訊號');
  }
  final title = strongest >= radarStrongEchoDbz ? '目前有強回波' : '目前有降雨回波';
  final overall = '最強約 $strongest dBZ（${radarDbzColourName(strongest)}）';
  if (place == null) return (title: title, meta: overall);
  final near = stats.maxDbzNear(LatLng(place.latitude, place.longitude));
  final local = near != null && near >= radarSignificantEchoDbz ? '最強約 $near dBZ' : '無明顯回波';
  return (title: title, meta: '$overall · ${place.county} ${place.town}附近$local');
}
