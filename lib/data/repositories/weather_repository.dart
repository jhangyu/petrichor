import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/dio_client.dart';
import '../../core/api/result.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/cwa_names.dart';
import '../../core/time/taiwan_time.dart';
import '../models/place.dart';
import '../models/weather_models.dart';

part 'weather_parsers.dart';

// ============================================================================
// Repository Provider
// ============================================================================

/// WeatherRepository 單例 Provider
final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepository(ref.watch(dioProvider));
});

// ============================================================================
// WeatherRepository
// ============================================================================

/// 縣市交界判定的寬容距離（公里）：另一縣市測站距離 ≤ 本縣市最近鄉鎮距離＋此值，即同時比較該縣市。
// ponytail: 鄉鎮以中心點代表，交界處仍可能挑到鄰鄉鎮；要精確改用鄉鎮界多邊形。
const double _countyBorderSlackKm = 1.0;

/// [actual] = the county name as the caller passed it.
Failure<T> _unsupportedCounty<T>(String actual, {required String location}) => Failure(
      '不支援的縣市：期望 ${AppConstants.townshipForecastDatasets.keys.join('、')} 其一，實際「$actual」',
      location: location,
    );

/// 日出日沒查詢範圍：今天前 1 日（夜間弧線）與後 1 日（暮光後切換明天）
const int _sunDaysBefore = 1;
const int _sunDaysAfter = 1;

/// 鄉鎮清單查詢只帶的預報要素（任一既有要素皆可，取其一縮小回應）
const String _townListElement = '天氣現象';

/// 縣市判定查詢只帶的觀測要素（任一皆可，取其一縮小回應）
const String _countyLookupElement = 'Weather';

/// 發布時間只讀 file API 回應的前幾個位元組（DatasetInfo 在 Locations 之前）
const int _issueTimeHeadBytes = 4096;

/// 天氣資料倉儲
///
/// 負責與 CWA Open Data API 互動，解析天氣資料。
/// 所有 API 呼叫皆回傳 [Result] 型別，確保錯誤可被 caller 處理。
class WeatherRepository {
  final Dio _dio;

  WeatherRepository(this._dio);

  // ==========================================================================
  // 即時觀測
  // ==========================================================================

  /// 取得離 [place] 最近、且有氣溫讀數的觀測站即時觀測（O-A0003-001）。
  Future<Result<CurrentWeather>> getCurrentWeather(Place place) {
    return _query(
      dataset: AppConstants.observationDataset,
      location: place.name,
      query: {'limit': AppConstants.observationStationLimit},
      parse: (body) => _parseObservation(body, place.latitude, place.longitude),
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

  // ==========================================================================
  // 日出日沒
  // ==========================================================================

  /// 取得 [city] 縣市「[now] 所在臺灣曆日」前一日、當日與隔日的日出日沒時刻（[昨天, 今天, 明天]）。
  Future<Result<List<SunDay>>> getSunTimes(String city, DateTime now) {
    final county = normalizeCwaName(city);
    final today = taiwanWall(now);
    final days = [
      for (var i = -_sunDaysBefore; i < _sunDaysAfter + 1; i++) isoDate(today.add(Duration(days: i))),
    ];
    return _query(
      dataset: AppConstants.sunTimesDataset,
      location: county,
      // timeTo 為不含端點，故取 days.last 的次日
      query: {
        'CountyName': county,
        'timeFrom': days.first,
        'timeTo': isoDate(today.add(const Duration(days: _sunDaysAfter + 1))),
      },
      parse: (body) => _parseSunTimes(body, county, days),
    );
  }

  // ==========================================================================
  // 鄉鎮清單
  // ==========================================================================

  /// 取得 [county] 全部鄉鎮與經緯度（取自該縣市 3 天鄉鎮預報資料集的地點清單）。
  Future<Result<List<Place>>> getTowns(String county) {
    final name = normalizeCwaName(county);
    final ids = AppConstants.townshipForecastDatasets[name];
    if (ids == null) return Future.value(_unsupportedCounty(county, location: county));
    return _query(
      dataset: ids.threeDay,
      location: name,
      // 只取單一要素，縮小回應；地點清單與經緯度不受影響
      query: {'ElementName': _townListElement},
      parse: (body) => _parseTowns(body, name),
    );
  }

  /// 取得離 ([latitude], [longitude]) 最近的鄉鎮。
  /// 先以最近的自動氣象站（[AppConstants.countyLookupDataset]）判定縣市，只抓該縣市鄉鎮清單；
  /// 若另一縣市最近的測站不比「本縣市最近鄉鎮距離＋[_countyBorderSlackKm]」遠（疑似縣市交界），
  /// 再抓該縣市清單一併比較。最多 3 次請求（測站＋2 縣市）。任一請求失敗即失敗。
  Future<Result<Place>> nearestTown(double latitude, double longitude) async {
    final where = '($latitude, $longitude)';
    final stations = await _query(
      dataset: AppConstants.countyLookupDataset,
      location: where,
      // 只取一個要素與縣市／座標，縮小回應
      query: {'WeatherElement': _countyLookupElement, 'GeoInfo': 'Coordinates,CountyName'},
      parse: (body) => _parseStationCounties(body, latitude, longitude),
    );
    if (stations is Failure<List<_StationCounty>>) return stations.retype<Place>();
    final nearest = stations.data.first;
    final other = stations.data.where((s) => s.county != nearest.county).firstOrNull;

    final home = await getTowns(nearest.county);
    if (home is Failure<List<Place>>) return home.retype<Place>();
    var best = _nearestPlace(home.data, latitude, longitude);
    if (other != null &&
        other.km <= _distanceKm(latitude, longitude, best.latitude, best.longitude) + _countyBorderSlackKm) {
      final neighbour = await getTowns(other.county);
      if (neighbour is Failure<List<Place>>) return neighbour.retype<Place>();
      best = _nearestPlace([best, ...neighbour.data], latitude, longitude);
    }
    return Success(best);
  }

  /// 取得 [city] 的 3 天鄉鎮預報（[getHourlyForecast] 同一資料集）發布時間。
  /// datastore 回應不含發布時間，故讀 file API 回應開頭的 `cwaopendata.Dataset.DatasetInfo.IssueTime`。
  Future<Result<DateTime>> getForecastIssueTime(String city) async {
    final county = normalizeCwaName(city);
    final ids = AppConstants.townshipForecastDatasets[county];
    if (ids == null) return _unsupportedCounty(city, location: city);
    final dataset = ids.threeDay;
    try {
      // ponytail: 整份 file API 約 1 MB；IssueTime 位於開頭 DatasetInfo（實測位移約 1.7 KB），只取前 [_issueTimeHeadBytes]。
      final response = await _dio.get<String>(
        '${AppConstants.cwaFileApiBaseUrl}$dataset',
        options: Options(
          headers: {'Range': 'bytes=0-${_issueTimeHeadBytes - 1}'},
          responseType: ResponseType.plain,
        ),
      );
      return Success(_parseIssueTime(response.data ?? '', dataset));
    } on DioException catch (e) {
      return failureFromDio(e, dataset: dataset, location: county);
    } on FormatException catch (e) {
      return Failure('解析 $dataset 發布時間失敗（地點 $county）：${e.message}', dataset: dataset, location: county);
    }
  }

  Future<Result<T>> _townshipForecast<T>(
    String city,
    String district, {
    required String Function(({String threeDay, String oneWeek})) datasetOf,
    required T Function(Map<String, dynamic> body, String township) parse,
  }) async {
    final county = normalizeCwaName(city);
    final township = normalizeCwaName(district);
    final ids = AppConstants.townshipForecastDatasets[county];
    if (ids == null) return _unsupportedCounty(city, location: '$city$district');
    return _query(
      dataset: datasetOf(ids),
      location: '$county$township',
      query: {'LocationName': township},
      parse: (body) => parse(body, township),
    );
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
      return failureFromDio(e, dataset: dataset, location: location);
    } on FormatException catch (e) {
      return Failure(
        '解析 $dataset 失敗（地點 $location）：${e.message}',
        dataset: dataset,
        location: location,
      );
    }
  }
}
