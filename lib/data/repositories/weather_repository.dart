import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/dio_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/location/location_service.dart';
import '../models/weather_models.dart';

// ============================================================================
// Result 型別（Error handling）
// ============================================================================

/// API 操作結果封裝
sealed class Result<T> {
  const Result();

  /// 成功結果
  factory Result.success(T data) = Success<T>;

  /// 失敗結果
  factory Result.failure(
    String message, {
    int? statusCode,
    String? dataset,
    String? location,
  }) = Failure<T>;

  /// 匹配結果
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(String message, int? statusCode) onFailure,
  }) {
    return switch (this) {
      Success<T>(:final data) => onSuccess(data),
      Failure<T>(:final message, :final statusCode) =>
        onFailure(message, statusCode),
    };
  }

  /// 是否成功
  bool get isSuccess => this is Success<T>;

  /// 是否失敗
  bool get isFailure => this is Failure<T>;

  ///取得資料（失敗時拋例外）
  T get data {
    return switch (this) {
      Success<T>(:final data) => data,
      Failure<T>(:final message) => throw StateError(message),
    };
  }
}

/// 成功結果
final class Success<T> extends Result<T> {
  @override
  final T data;
  const Success(this.data);
}

/// 失敗結果。[dataset]、[location] 為受影響的資料集代號與地點（可得時必填）。
final class Failure<T> extends Result<T> {
  final String message;
  final int? statusCode;
  final String? dataset;
  final String? location;
  const Failure(this.message, {this.statusCode, this.dataset, this.location});
}

// ============================================================================
// Repository Provider
// ============================================================================

/// WeatherRepository 單例 Provider
final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepository(ref.watch(dioProvider), ref.watch(fileApiDioProvider));
});

// ============================================================================
// WeatherRepository
// ============================================================================

/// 天氣資料倉儲
///
/// 負責與 CWA Open Data API 互動，解析天氣資料。
/// 所有 API 呼叫皆回傳 [Result] 型別，確保錯誤可被 caller 處理。
class WeatherRepository {
  final Dio _dio;
  final Dio _fileApiDio;

  WeatherRepository(this._dio, this._fileApiDio);

  // ==========================================================================
  // 即時觀測
  // ==========================================================================

  /// 取得離 [location] 最近、且有氣溫讀數的觀測站即時觀測（O-A0003-001）。
  Future<Result<CurrentWeather>> getCurrentWeather(LocationData location) {
    return _query(
      dataset: AppConstants.observationDataset,
      location: '${location.city}${location.district}',
      query: {'limit': AppConstants.observationStationLimit},
      parse: (body) => _parseObservation(body, location.latitude, location.longitude),
    );
  }

  // ==========================================================================
  // 預報
  // ==========================================================================

  /// 取得鄉鎮逐 3 小時預報（未來 3 天）。
  Future<Result<List<HourlyForecast>>> getHourlyForecast(String city, String district) {
    return _townshipForecast(
      city,
      district,
      datasetOf: (d) => d.threeDay,
      parse: _parseHourly,
    );
  }

  /// 取得鄉鎮一週預報，每日含最高／最低溫（最多 [_weeklyDayCount] 天）。
  Future<Result<List<DailyForecast>>> getWeeklyForecast(String city, String district) {
    return _townshipForecast(
      city,
      district,
      datasetOf: (d) => d.oneWeek,
      parse: _parseWeekly,
    );
  }

  Future<Result<T>> _townshipForecast<T>(
    String city,
    String district, {
    required String Function(({String threeDay, String oneWeek})) datasetOf,
    required T Function(Map<String, dynamic> body, String township) parse,
  }) async {
    final county = _normalizeName(city);
    final township = _normalizeName(district);
    final ids = AppConstants.townshipForecastDatasets[county];
    if (ids == null) {
      return Failure(
        '不支援的縣市：期望 ${AppConstants.townshipForecastDatasets.keys.join('、')} 其一，實際「$city」',
        location: '$city$district',
      );
    }
    return _query(
      dataset: datasetOf(ids),
      location: '$county$township',
      query: {'LocationName': township},
      parse: (body) => parse(body, township),
    );
  }

  // ==========================================================================
  // 雷達圖
  // ==========================================================================

  /// 取得雷達圖 URL
  ///
  /// 使用 fileapi/v1/opendataapi 端點，解析 JSON 中的 ProductURL。
  /// [datasetId] 雷達資料集 ID，預設為台灣雷達站（O-A0058-001）
  Future<Result<String>> getRadarImageUrl({String? datasetId}) async {
    if (!AppConstants.hasApiKey) {
      return const Failure('API Key 未設定，請使用 --dart-define=CWA_API_KEY=your_key');
    }

    final dataset = datasetId ?? AppConstants.radarTaiwan;
    final url = AppConstants.radarApiUrl(dataset, AppConstants.cwaApiKey);

    try {
      final response = await _fileApiDio.get(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      // 處理 response.data 可能為 String 或 Map 的情況
      Map<String, dynamic> data;
      if (response.data is String) {
        // 如果是字串，手動解析 JSON
        data = Map<String, dynamic>.from(
          const JsonDecoder().convert(response.data as String) as Map,
        );
      } else {
        data = response.data as Map<String, dynamic>;
      }

      final productUrl = data['cwaopendata']?['dataset']?['resource']?['ProductURL'] as String?;

      if (productUrl == null || productUrl.isEmpty) {
        return const Failure('無法解析雷達圖 URL，API 回應缺少 ProductURL 欄位');
      }

      return Success(productUrl);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return Failure('取得雷達圖失敗：$e');
    }
  }

  // ==========================================================================
  // 私有輔助方法
  // ==========================================================================

  /// 送出請求並在邊界一次解析成強型別；任何失敗都帶資料集與地點。
  Future<Result<T>> _query<T>({
    required String dataset,
    required String location,
    required Map<String, dynamic> query,
    required T Function(Map<String, dynamic> body) parse,
  }) async {
    try {
      final response = await _dio.get(dataset, queryParameters: query);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return Failure(
          '回應格式錯誤：期望 JSON 物件，實際 ${data.runtimeType}',
          dataset: dataset,
          location: location,
        );
      }
      return Success(parse(data));
    } on DioException catch (e) {
      return _handleDioError(e, dataset: dataset, location: location);
    } on FormatException catch (e) {
      return Failure(
        '解析 $dataset 失敗（地點 $location）：${e.message}',
        dataset: dataset,
        location: location,
      );
    }
  }

  /// 處理 Dio 例外
  Result<T> _handleDioError<T>(DioException e, {String? dataset, String? location}) {
    final message = isApiError(e) ? 'API 授權失敗，請確認 API Key 正確' : _formatDioError(e);
    return Failure(
      dataset == null ? message : '$message（資料集 $dataset，地點 $location）',
      statusCode: e.response?.statusCode,
      dataset: dataset,
      location: location,
    );
  }

  /// 格式化 Dio 例外為可讀訊息
  String _formatDioError(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout => '連線逾時，請檢查網路',
      DioExceptionType.sendTimeout => '傳送逾時，請稍後再試',
      DioExceptionType.receiveTimeout => '接收逾時，請稍後再試',
      DioExceptionType.badResponse => '伺服器回應錯誤：${e.response?.statusCode}',
      DioExceptionType.cancel => '請求已取消',
      DioExceptionType.connectionError => '連線失敗，請檢查網路',
      _ => '網路錯誤：${e.message}',
    };
  }
}

// ============================================================================
// 邊界解析（CWA 回應 → 強型別；結構不符一律丟 FormatException，由 _query 轉成 Failure）
// ============================================================================

/// CWA 缺值標記（所有值皆為字串）
const double _missingValue = -99;
const double _earthRadiusKm = 6371.0;
const Duration _taiwanOffset = Duration(hours: 8);

/// 一週預報顯示天數
const int _weeklyDayCount = 7;

/// 12 小時預報中「白天時段」的起始時（臺灣時間）
const int _daySlotStartHour = 6;
const String _wgs84 = 'WGS84';

/// CWA 縣市／鄉鎮名一律用「臺」，用「台」會回 200 但資料為空。
String _normalizeName(String name) => name.replaceAll('台', '臺');

Map<String, dynamic> _obj(Object? v, String path) {
  if (v is Map<String, dynamic>) return v;
  throw FormatException('$path：期望物件，實際 ${v.runtimeType}');
}

List<Object?> _list(Object? v, String path) {
  if (v is List<Object?>) return v;
  throw FormatException('$path：期望陣列，實際 ${v.runtimeType}');
}

/// 沿路徑取值；中途缺少即回 null（欄位可選）。
Object? _dig(Map<String, dynamic> m, List<String> path) {
  Object? cur = m;
  for (final key in path) {
    if (cur is! Map<String, dynamic>) return null;
    cur = cur[key];
  }
  return cur;
}

/// 數值字串 → double；缺值（null、-99）→ null；非數字 → FormatException。
double? _num(Object? raw, String path) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  final value = double.tryParse(text);
  if (value == null) throw FormatException('$path：期望數字，實際「$text」');
  return value == _missingValue ? null : value;
}

int? _int(Object? raw, String path) => _num(raw, path)?.round();

/// 文字欄位；缺值（null、-99、空字串）→ null。
String? _text(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  return (text.isEmpty || text == '-99') ? null : text;
}

DateTime _time(Object? raw, String path) {
  if (raw is! String) throw FormatException('$path：期望時間字串，實際 ${raw.runtimeType}');
  return DateTime.parse(raw);
}

double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadiusKm * math.asin(math.sqrt(a));
}

CurrentWeather _parseObservation(Map<String, dynamic> body, double lat, double lon) {
  final stations = _list(_dig(body, ['records', 'Station']), 'records.Station');
  if (stations.isEmpty) throw const FormatException('records.Station：期望至少 1 站，實際 0 站');

  Map<String, dynamic>? best;
  double bestKm = double.infinity;
  for (var i = 0; i < stations.length; i++) {
    final path = 'records.Station[$i]';
    final station = _obj(stations[i], path);
    final temp = _num(_dig(station, ['WeatherElement', 'AirTemperature']), '$path.AirTemperature');
    if (temp == null) continue;
    final coords = _list(_dig(station, ['GeoInfo', 'Coordinates']), '$path.GeoInfo.Coordinates')
        .map((c) => _obj(c, '$path.GeoInfo.Coordinates[]'))
        .firstWhere(
          (c) => c['CoordinateName'] == _wgs84,
          orElse: () => throw FormatException('$path：缺少 $_wgs84 座標'),
        );
    final km = _distanceKm(
      lat,
      lon,
      _num(coords['StationLatitude'], '$path.StationLatitude')!,
      _num(coords['StationLongitude'], '$path.StationLongitude')!,
    );
    if (km < bestKm) {
      bestKm = km;
      best = station;
    }
  }
  if (best == null) {
    throw FormatException('期望至少 1 站有氣溫讀數，實際 ${stations.length} 站皆缺氣溫');
  }

  final we = _obj(best['WeatherElement'], 'WeatherElement');
  return CurrentWeather(
    stationName: _text(best['StationName']) ?? '',
    countyName: _text(_dig(best, ['GeoInfo', 'CountyName'])) ?? '',
    townName: _text(_dig(best, ['GeoInfo', 'TownName'])) ?? '',
    distanceKm: bestKm,
    observedAt: _time(_dig(best, ['ObsTime', 'DateTime']), 'ObsTime.DateTime'),
    temperature: _num(we['AirTemperature'], 'AirTemperature')!,
    humidity: _int(we['RelativeHumidity'], 'RelativeHumidity'),
    windSpeed: _num(we['WindSpeed'], 'WindSpeed'),
    weather: _text(we['Weather']),
    dailyHigh: _num(
      _dig(we, ['DailyExtreme', 'DailyHigh', 'TemperatureInfo', 'AirTemperature']),
      'DailyHigh',
    ),
    dailyLow: _num(
      _dig(we, ['DailyExtreme', 'DailyLow', 'TemperatureInfo', 'AirTemperature']),
      'DailyLow',
    ),
  );
}

/// 一個時間槽：起點（key）、終點（僅區間型要素有）、第一個 ElementValue。
class _Slot {
  final DateTime? end;
  final Map<String, dynamic> value;
  const _Slot(this.end, this.value);
}

/// 要素名稱 → 依起點排序的時間槽
typedef _Elements = Map<String, Map<DateTime, _Slot>>;

_Elements _parseElements(Map<String, dynamic> body, String township) {
  final locations = _list(_dig(body, ['records', 'Locations']), 'records.Locations');
  if (locations.isEmpty) throw const FormatException('records.Locations：期望 1 組，實際 0 組');
  final list = _list(_obj(locations.first, 'records.Locations[0]')['Location'], 'Location');
  final names = <String>[];
  for (final item in list) {
    final loc = _obj(item, 'Location[]');
    final name = _text(loc['LocationName']) ?? '';
    names.add(name);
    if (name != township) continue;
    final elements = <String, Map<DateTime, _Slot>>{};
    for (final e in _list(loc['WeatherElement'], '$name.WeatherElement')) {
      final em = _obj(e, '$name.WeatherElement[]');
      final elementName = _text(em['ElementName']) ?? '';
      final slots = <DateTime, _Slot>{};
      for (final t in _list(em['Time'], '$elementName.Time')) {
        final tm = _obj(t, '$elementName.Time[]');
        final rawStart = tm['StartTime'] ?? tm['DataTime'];
        final rawEnd = tm['EndTime'];
        final values = _list(tm['ElementValue'], '$elementName.ElementValue');
        if (values.isEmpty) throw FormatException('$elementName：ElementValue 為空');
        slots[_time(rawStart, '$elementName.StartTime')] = _Slot(
          rawEnd == null ? null : _time(rawEnd, '$elementName.EndTime'),
          _obj(values.first, '$elementName.ElementValue[0]'),
        );
      }
      elements[elementName] = Map.fromEntries(
        slots.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );
    }
    return elements;
  }
  throw FormatException(
    '期望地點「$township」，實際 ${names.isEmpty ? '無任何地點（若地名含「台」請改「臺」）' : names.join('、')}',
  );
}

Map<DateTime, _Slot> _element(_Elements elements, String name) =>
    elements[name] ?? (throw FormatException('缺少要素「$name」，實際要素：${elements.keys.join('、')}'));

List<HourlyForecast> _parseHourly(Map<String, dynamic> body, String township) {
  final els = _parseElements(body, township);
  final weather = _element(els, '天氣現象');
  final temperature = _element(els, '溫度');
  final apparent = _element(els, '體感溫度');
  final humidity = _element(els, '相對濕度');
  final windSpeed = _element(els, '風速');
  final windDirection = _element(els, '風向');
  final pop = _element(els, '3小時降雨機率');
  return [
    for (final start in weather.keys)
      HourlyForecast(
        startTime: start,
        temperature: _num(temperature[start]?.value['Temperature'], '溫度@$start'),
        apparentTemperature: _num(apparent[start]?.value['ApparentTemperature'], '體感溫度@$start'),
        humidity: _int(humidity[start]?.value['RelativeHumidity'], '相對濕度@$start'),
        windSpeed: _num(windSpeed[start]?.value['WindSpeed'], '風速@$start'),
        windDirection: _text(windDirection[start]?.value['WindDirection']),
        pop: _int(pop[start]?.value['ProbabilityOfPrecipitation'], '3小時降雨機率@$start'),
        weather: _text(weather[start]!.value['Weather']),
        weatherCode: _text(weather[start]!.value['WeatherCode']),
      ),
  ];
}

String _dateKey(DateTime wall) =>
    '${wall.year.toString().padLeft(4, '0')}-${wall.month.toString().padLeft(2, '0')}-${wall.day.toString().padLeft(2, '0')}';

/// 一週預報為 12 小時時段（白天 06–18、夜間 18–06）。
/// 單日最高／最低溫 = 該臺灣曆日所涉時段的最高／最低；其餘欄位取該日白天時段（今天只剩夜間時只取夜間）。
List<DailyForecast> _parseWeekly(Map<String, dynamic> body, String township) {
  final els = _parseElements(body, township);
  final maxT = _element(els, '最高溫度');
  final minT = _element(els, '最低溫度');
  final maxA = _element(els, '最高體感溫度');
  final minA = _element(els, '最低體感溫度');
  final humidity = _element(els, '平均相對濕度');
  final windSpeed = _element(els, '風速');
  final pop = _element(els, '12小時降雨機率');
  final weather = _element(els, '天氣現象');

  final slotsByDate = <String, List<DateTime>>{};
  for (final entry in maxT.entries) {
    final end = entry.value.end;
    if (end == null) throw FormatException('最高溫度@${entry.key}：缺少 EndTime');
    final startWall = entry.key.add(_taiwanOffset);
    final lastWall = end.add(_taiwanOffset).subtract(const Duration(microseconds: 1));
    for (var day = DateTime.utc(startWall.year, startWall.month, startWall.day);
        !day.isAfter(lastWall);
        day = day.add(const Duration(days: 1))) {
      slotsByDate.putIfAbsent(_dateKey(day), () => []).add(entry.key);
    }
  }

  double? extreme(Map<DateTime, _Slot> element, String key, List<DateTime> starts, bool max) {
    final values = [
      for (final s in starts) _num(element[s]?.value[key], '$key@$s'),
    ].whereType<double>();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => max ? math.max(a, b) : math.min(a, b));
  }

  final days = <DailyForecast>[];
  for (final entry in slotsByDate.entries.take(_weeklyDayCount)) {
    final starts = entry.value;
    final rep = starts.firstWhere(
      (s) => s.add(_taiwanOffset).hour == _daySlotStartHour && _dateKey(s.add(_taiwanOffset)) == entry.key,
      orElse: () => starts.first,
    );
    days.add(DailyForecast(
      date: entry.key,
      maxTemperature: extreme(maxT, 'MaxTemperature', starts, true),
      minTemperature: extreme(minT, 'MinTemperature', starts, false),
      maxApparentTemperature: extreme(maxA, 'MaxApparentTemperature', starts, true),
      minApparentTemperature: extreme(minA, 'MinApparentTemperature', starts, false),
      humidity: _int(humidity[rep]?.value['RelativeHumidity'], '平均相對濕度@$rep'),
      windSpeed: _num(windSpeed[rep]?.value['WindSpeed'], '風速@$rep'),
      pop: _int(pop[rep]?.value['ProbabilityOfPrecipitation'], '12小時降雨機率@$rep'),
      weather: _text(weather[rep]?.value['Weather']),
      weatherCode: _text(weather[rep]?.value['WeatherCode']),
    ));
  }
  return days;
}
