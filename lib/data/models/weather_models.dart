import 'package:freezed_annotation/freezed_annotation.dart';

part 'weather_models.freezed.dart';
part 'weather_models.g.dart';

// ============================================================================
// 觀測 / 預報模型（缺值一律為 null，不用假數字）
// ============================================================================

/// 最近觀測站的即時觀測（O-A0003-001）
class CurrentWeather {
  /// 觀測站名稱（如「淡水」）
  final String stationName;

  /// 觀測站所在縣市／鄉鎮區
  final String countyName;
  final String townName;

  /// 使用者位置到觀測站的距離（公里）
  final double distanceKm;

  /// 觀測時間（絕對時刻）
  final DateTime observedAt;

  /// 氣溫（°C）；挑站時已排除無氣溫的站，所以必有值
  final double temperature;

  /// 相對濕度（%）
  final int? humidity;

  /// 風速（m/s）
  final double? windSpeed;

  /// 天氣現象文字（如「陰」）
  final String? weather;

  /// 今日最高／最低溫（°C）
  final double? dailyHigh;
  final double? dailyLow;

  const CurrentWeather({
    required this.stationName,
    required this.countyName,
    required this.townName,
    required this.distanceKm,
    required this.observedAt,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.weather,
    required this.dailyHigh,
    required this.dailyLow,
  });
}

/// 逐 3 小時預報的一筆（鄉鎮級）
class HourlyForecast {
  /// 時段起點（絕對時刻）
  final DateTime startTime;
  final double? temperature;
  final double? apparentTemperature;

  /// 相對濕度（%）
  final int? humidity;

  /// 風速（m/s）與風向（中文，如「偏北風」）
  final double? windSpeed;
  final String? windDirection;

  /// 3 小時降雨機率（%）
  final int? pop;
  final String? weather;
  final String? weatherCode;

  const HourlyForecast({
    required this.startTime,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.pop,
    required this.weather,
    required this.weatherCode,
  });
}

/// 單日預報（日期為臺灣曆日）
class DailyForecast {
  /// YYYY-MM-DD（臺灣時間）
  final String date;
  final double? maxTemperature;
  final double? minTemperature;
  final double? maxApparentTemperature;
  final double? minApparentTemperature;
  final int? humidity;
  final double? windSpeed;

  /// 12 小時降雨機率（%）
  final int? pop;
  final String? weather;
  final String? weatherCode;

  const DailyForecast({
    required this.date,
    required this.maxTemperature,
    required this.minTemperature,
    required this.maxApparentTemperature,
    required this.minApparentTemperature,
    required this.humidity,
    required this.windSpeed,
    required this.pop,
    required this.weather,
    required this.weatherCode,
  });

  /// 星期名稱
  String get weekdayName {
    const names = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
    return names[DateTime.parse(date).weekday - 1];
  }
}

// ============================================================================
// 既有 freezed 模型（UI 仍在使用，隨 UI 改版移除）
// ============================================================================

/// 天氣狀況
@freezed
sealed class WeatherCondition with _$WeatherCondition {
  const factory WeatherCondition({
    required String wx, // Weather description
    required int pop, // Probability of precipitation (%)
    required int t, // Temperature
    required String startTime,
    required String endTime,
  }) = _WeatherCondition;

  factory WeatherCondition.fromJson(Map<String, dynamic> json) =>
      _$WeatherConditionFromJson(json);
}

