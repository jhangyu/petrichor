import 'package:freezed_annotation/freezed_annotation.dart';

part 'weather_models.freezed.dart';
part 'weather_models.g.dart';

// ============================================================================
// 天氣現象枚舉
// ============================================================================

/// 天氣現象描述（對應 CWA Wx code）
enum WeatherPhenomenon {
  sunny('晴天'),
  cloudy('多雲'),
  partlyCloudy('晴時多雲'),
  overcast('陰天'),
  shower('陣雨'),
  thunderstorm('雷陣雨'),
  rain('雨'),
  drizzle('毛毛雨'),
  fog('霧'),
  unknown('未知');

  final String displayName;
  const WeatherPhenomenon(this.displayName);

  /// 從 CWA 天氣現象碼建立
  static WeatherPhenomenon fromCode(String code) {
    return switch (code) {
      //晴
      '01' || '02' || '03' => WeatherPhenomenon.sunny,
      // 多雲
      '04' || '05' || '06' || '07' => WeatherPhenomenon.cloudy,
      // 陰
      '08' => WeatherPhenomenon.overcast,
      // 陣雨
      '09' || '10' || '11' || '12' => WeatherPhenomenon.shower,
      // 雷陣雨
      '13' || '14' || '15' || '16' || '17' || '18' || '19' => WeatherPhenomenon.thunderstorm,
      // 雨
      '20' || '21' || '22' || '23' || '24' || '25' || '26' || '27' || '28' => WeatherPhenomenon.rain,
      // 毛毛雨
      '29' || '30' || '31' || '32' || '33' || '34' || '35' => WeatherPhenomenon.drizzle,
      // 霧
      '36' || '37' || '38' || '39' => WeatherPhenomenon.fog,
      _ => WeatherPhenomenon.unknown,
    };
  }
}

// ============================================================================
// 目前天氣模型
// ============================================================================

/// 目前天氣資料（單一地點）
///
///包含溫度、體感溫度、濕度、風速、天氣現象等即時資訊
@freezed
sealed class CurrentWeather with _$CurrentWeather {
  const factory CurrentWeather({
    /// 地點名稱
    required String locationName,

    /// 溫度（°C）
    required double temperature,

    /// 體感溫度（°C）
    required double feelsLike,

    /// 相對濕度（%）
    required int humidity,

    /// 風速（m/s）
    required double windSpeed,

    /// 天氣現象描述
    required String weatherDescription,

    /// 天氣現象碼（CWA code）
    required String weatherCode,

    ///降雨機率（%）
    required int pop,

    /// 觀測時間（ISO 8601）
    required String observationTime,
  }) = _CurrentWeather;

  const CurrentWeather._();

  /// 解析 CWA 目前天氣 API 回應
  factory CurrentWeather.fromCwaJson(Map<String, dynamic> json) {
    final obs = json['cwbopendata'] ?? json;
    return CurrentWeather(
      locationName: obs['locationName']?.toString() ?? '未知',
      temperature: _parseDouble(obs['temperature']),
      feelsLike: _parseDouble(obs['feelsLike']),
      humidity: _parseInt(obs['humidity']),
      windSpeed: _parseDouble(obs['windSpeed']),
      weatherDescription: obs['weather']?.toString() ?? '未知',
      weatherCode: obs['weatherCode']?.toString() ?? '',
      pop: _parseInt(obs['pop']),
      observationTime: obs['observationTime']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  ///從 JSON（通用格式）解析
  factory CurrentWeather.fromJson(Map<String, dynamic> json) =>
      _$CurrentWeatherFromJson(json);

  /// 天氣現象枚舉
  WeatherPhenomenon get phenomenon => WeatherPhenomenon.fromCode(weatherCode);
}

// ============================================================================
// 一週預報模型
// ============================================================================

/// 一週預報（單一地點）
///
///包含未來 7 天的每日天氣預報
@freezed
sealed class WeeklyForecast with _$WeeklyForecast {
  const factory WeeklyForecast({
    /// 地點名稱
    required String locationName,

    /// 每日預報列表
    required List<DailyForecast> days,
  }) = _WeeklyForecast;

  const WeeklyForecast._();

  /// 解析 CWA 鄉鎮天氣預報（F-D0047-089）API 回應
  ///
  /// [targetLocation] 要過濾的地點名稱（如「臺北市」），為 null 時取第一個
  factory WeeklyForecast.fromCwaJson(Map<String, dynamic> json, {String? targetLocation}) {
    final records = json['records'] ?? json;
    final locations = (records['Locations'] ?? records['locations']) as List?;

    if (locations == null || locations.isEmpty) {
      return const WeeklyForecast(locationName: '', days: []);
    }

    // records.Locations[0] 是「台灣」，其 Location[]才是各縣市
    final firstLocation = locations.first as Map<String, dynamic>;
    final locationList = (firstLocation['Location'] ?? firstLocation['location']) as List? ?? [];

    if (locationList.isEmpty) {
      return const WeeklyForecast(locationName: '', days: []);
    }

    // 找到目標地點（精確匹配）
    Map<String, dynamic> selectedCounty;
    if (targetLocation != null) {
      Map<String, dynamic>? matched;
      for (final loc in locationList) {
        final l = loc as Map<String, dynamic>;
        if (l['LocationName']?.toString() == targetLocation ||
            l['locationName']?.toString() == targetLocation) {
          matched = l;
          break;
        }
      }
      if (matched == null) {
        return const WeeklyForecast(locationName: '', days: []);
      }
      selectedCounty = matched;
    } else {
      selectedCounty = locationList.first as Map<String, dynamic>;
    }

    final locationName = (selectedCounty['LocationName'] ?? selectedCounty['locationName'])?.toString() ?? '未知';
    final weatherElements = (selectedCounty['weatherElement'] ?? selectedCounty['WeatherElement']) as List? ?? [];

    // 解析各天氣要素（使用中文元素名稱）
    final Map<String, List<Map<String, dynamic>>> elementMap = {};
    for (final element in weatherElements) {
      final em = element as Map<String, dynamic>;
      final elementName = (em['ElementName'] ?? em['elementName'])?.toString() ?? '';
      final times = (em['Time'] ?? em['time'] ?? []) as List;
      elementMap[elementName] = times.map((t) => Map<String, dynamic>.from(t as Map)).toList();
    }

    // CWA API 使用中文元素名稱：
    // 天氣現象=Wx,3小時降雨機率=PoP, 溫度=MaxT/MinT
    final wxTimes = elementMap['天氣現象'] ?? [];
    final popTimes = elementMap['3小時降雨機率'] ?? [];
    final maxTTimes = elementMap['溫度'] ?? [];

    // 建立每日預報（每8筆為一天，3小時一筆）
    final days = <DailyForecast>[];
    final maxDays = (wxTimes.length / 8).floor().clamp(0, 7);

    for (var i = 0; i < maxDays; i++) {
      final dayStartIdx = i * 8;
      final wxTime = wxTimes[dayStartIdx];
      final wxData = (wxTime['ElementValue'] as List?)?.first as Map<String, dynamic>? ?? {};
      final popTime = dayStartIdx < popTimes.length ? popTimes[dayStartIdx] : null;
      final popData = (popTime?['ElementValue'] as List?)?.first as Map<String, dynamic>? ?? {};
      final maxTTime = dayStartIdx < maxTTimes.length ? maxTTimes[dayStartIdx] : null;
      final maxTData = (maxTTime?['ElementValue'] as List?)?.first as Map<String, dynamic>? ?? {};

      final startTime = (wxTime['StartTime'] ?? wxTime['startTime'])?.toString() ?? '';
      final date = startTime.split('T').first;

      // 找當天最低溫（取8筆中的最小值）
      double minTemp = _parseDouble(maxTData['Temperature']);
      for (var j = 1; j < 8 && (dayStartIdx + j) < maxTTimes.length; j++) {
        final t = maxTTimes[dayStartIdx + j];
        final tData = (t['ElementValue'] as List?)?.first as Map<String, dynamic>? ?? {};
        final temp = _parseDouble(tData['Temperature']);
        if (temp < minTemp) minTemp = temp;
      }

      days.add(DailyForecast(
        date: date,
        weatherDescription: wxData['Weather']?.toString() ?? '未知',
        weatherCode: wxData['WeatherCode']?.toString() ?? '',
        pop: _parseInt(popData['ProbabilityOfPrecipitation']),
        maxTemperature: _parseDouble(maxTData['Temperature']),
        minTemperature: minTemp,
      ));
    }

    return WeeklyForecast(locationName: locationName, days: days);
  }

  ///從 JSON 解析
  factory WeeklyForecast.fromJson(Map<String, dynamic> json) =>
      _$WeeklyForecastFromJson(json);
}

/// 單日天氣預報
@freezed
sealed class DailyForecast with _$DailyForecast {
  const factory DailyForecast({
    /// 日期（YYYY-MM-DD）
    required String date,

    /// 天氣現象描述
    required String weatherDescription,

    /// 天氣現象碼（CWA code）
    required String weatherCode,

    /// 降雨機率（%）
    required int pop,

    /// 最高溫度（°C）
    required double maxTemperature,

    /// 最低溫度（°C）
    required double minTemperature,
  }) = _DailyForecast;

  const DailyForecast._();

  /// 從 JSON 解析
  factory DailyForecast.fromJson(Map<String, dynamic> json) =>
      _$DailyForecastFromJson(json);

  /// 天氣現象枚舉
  WeatherPhenomenon get phenomenon => WeatherPhenomenon.fromCode(weatherCode);

  ///星期幾（0=週日）
  int get weekday {
    final parts = date.split('-');
    if (parts.length != 3) return 0;
    final dt = DateTime.parse(date);
    return dt.weekday;
  }

  ///星期名稱
  String get weekdayName {
    const names = ['週日', '週一', '週二', '週三', '週四', '週五', '週六'];
    return names[weekday % 7];
  }
}

// ============================================================================
// 向後相容：既有模型
// ============================================================================

/// 天氣狀況（向後相容）
@freezed
sealed class WeatherCondition with _$WeatherCondition {
  const factory WeatherCondition({
    required String wx, // Weather description
    required int pop,   // Probability of precipitation (%)
    required int t,     // Temperature
    required String startTime,
    required String endTime,
  }) = _WeatherCondition;

  factory WeatherCondition.fromJson(Map<String, dynamic> json) =>
      _$WeatherConditionFromJson(json);
}

/// 雷達圖 URL（向後相容）
@freezed
sealed class RadarImage with _$RadarImage {
  const factory RadarImage({
    required String url,
    required String time,
  }) = _RadarImage;

  factory RadarImage.fromJson(Map<String, dynamic> json) =>
      _$RadarImageFromJson(json);
}

// ============================================================================
// 工具函式
// ============================================================================

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}
