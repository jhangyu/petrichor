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

  /// 觀測時間（絕對時刻）
  final DateTime observedAt;

  /// 氣溫（°C）；挑站時已排除無氣溫的站，所以必有值
  final double temperature;

  /// 相對濕度（%）
  final int? humidity;

  /// 風速（m/s）
  final double? windSpeed;

  /// 風向（O-A0003-001 WindDirection）
  final ObservedWind? windDirection;

  /// 天氣現象文字（如「陰」）
  final String? weather;

  /// 今日最高／最低溫（°C）
  final double? dailyHigh;
  final double? dailyLow;

  const CurrentWeather({
    required this.stationName,
    required this.countyName,
    required this.townName,
    required this.observedAt,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.weather,
    required this.dailyHigh,
    required this.dailyLow,
  });
}

/// 觀測風向：靜風、風向不定、或風的來向方位角
sealed class ObservedWind {
  const ObservedWind();
  const factory ObservedWind.calm() = CalmWind;
  const factory ObservedWind.variable() = VariableWind;
  const factory ObservedWind.degrees(double degrees) = WindFrom;
}

final class CalmWind extends ObservedWind {
  const CalmWind();
}

final class VariableWind extends ObservedWind {
  const VariableWind();
}

/// 風的來向（度，1–360，360＝北）
final class WindFrom extends ObservedWind {
  final double degrees;
  const WindFrom(this.degrees);
}

/// 縣市單日日出日沒時刻（A-B0062-001）；時刻為絕對時刻（資料為臺灣時間 UTC+8）。
class SunDay {
  /// 臺灣曆日（yyyy-MM-dd）
  final String date;

  /// 民用曙光始／日出／日沒／民用暮光終
  final DateTime civilDawn;
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime civilDusk;

  /// 太陽過中天時刻，及當時仰角（度）（如 47S → 47°）
  final DateTime transit;
  final int transitAltitudeDegrees;

  const SunDay({
    required this.date,
    required this.civilDawn,
    required this.sunrise,
    required this.sunset,
    required this.civilDusk,
    required this.transit,
    required this.transitAltitudeDegrees,
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

  /// 天氣預報綜合描述（CWA 原文，如「短暫陣雨。降雨機率50%。…」）
  final String? description;

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
    required this.description,
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
}

