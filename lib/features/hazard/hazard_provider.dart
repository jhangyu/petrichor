import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/hazard_models.dart';
import '../../data/repositories/hazard_repository.dart';
import '../../data/repositories/weather_repository.dart' show Result;

/// 使用者位置：縣市名（CWA 寫法，用「臺」）與經緯度
typedef HazardLocation = ({String county, double latitude, double longitude});

/// 目前生效的縣市特報（含公告）；無特報為 Success 且 counties 為空
final activeWarningsProvider = FutureProvider<Result<ActiveWarnings>>((ref) {
  return ref.watch(hazardRepositoryProvider).getActiveWarnings();
});

/// 使用者縣市的雨量觀測與最近測站
final rainfallProvider = FutureProvider.family<Result<CountyRainfall>, HazardLocation>((ref, loc) {
  return ref.watch(hazardRepositoryProvider).getRainfall(
        county: loc.county,
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
});

/// 日累積雨量圖
final rainfallMapProvider = FutureProvider<Result<RainfallMap>>((ref) {
  return ref.watch(hazardRepositoryProvider).getRainfallMap();
});

/// 使用者位置的 1 小時雨量預測（含繪圖用格點）
final rainForecastProvider = FutureProvider.family<Result<RainForecast>, ({double latitude, double longitude})>((ref, loc) {
  return ref.watch(hazardRepositoryProvider).getRainForecast(latitude: loc.latitude, longitude: loc.longitude);
});
