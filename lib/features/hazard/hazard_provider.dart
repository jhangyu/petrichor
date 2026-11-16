import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/hazard_models.dart';
import '../../data/repositories/hazard_repository.dart';
import '../../core/api/result.dart' show Result;
import '../../data/models/place.dart' show Place;

/// 使用者位置：縣市名（CWA 寫法，用「臺」）與經緯度
typedef HazardLocation = ({String county, double latitude, double longitude});

extension PlaceHazardLocation on Place {
  /// 雨量／警特報頁用的位置
  HazardLocation get hazardLocation =>
      (county: county, latitude: latitude, longitude: longitude);
}

/// 目前生效的縣市特報（含公告）；無特報為 Success 且 counties 為空
final activeWarningsProvider = FutureProvider<Result<ActiveWarnings>>((ref) {
  return ref.watch(hazardRepositoryProvider).getActiveWarnings();
});

/// 使用者縣市的雨量觀測與最近測站
final countyRainfallProvider = FutureProvider.family<Result<CountyRainfall>, HazardLocation>((ref, hazardLocation) {
  return ref.watch(hazardRepositoryProvider).getRainfall(
        county: hazardLocation.county,
        latitude: hazardLocation.latitude,
        longitude: hazardLocation.longitude,
      );
});

/// 使用者位置的 1 小時雨量預測（含繪圖用格點）
final rainForecastProvider = FutureProvider.family<Result<RainForecast>, ({double latitude, double longitude})>((ref, point) {
  return ref.watch(hazardRepositoryProvider).getRainForecast(latitude: point.latitude, longitude: point.longitude);
});

/// 全部雨量測站（無目前地點時的測站列表）
final rainStationsProvider = FutureProvider<Result<List<RainStation>>>((ref) {
  return ref.watch(hazardRepositoryProvider).getRainStations();
});

/// 1 小時雨量預測格點（無目前地點時的預測圖）
final rainForecastGridProvider = FutureProvider<Result<RainForecastGrid>>((ref) {
  return ref.watch(hazardRepositoryProvider).getRainForecastGrid();
});
