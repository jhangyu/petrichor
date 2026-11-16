import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/app_constants.dart';
import '../models/hazard_models.dart';
import '../../core/api/result.dart' show Failure, Result, Success, guardRequest;

final hazardRepositoryProvider = Provider<HazardRepository>((ref) {
  return HazardRepository(ref.watch(dioProvider));
});

/// 警特報與雨量資料倉儲。所有方法回傳 [Result]，失敗訊息含資料集 ID。
class HazardRepository {
  final Dio _dio;

  /// 取得 [ActiveWarnings.fetchedAt] 的時鐘（測試注入）
  final DateTime Function() clock;

  HazardRepository(this._dio, {this.clock = DateTime.now});

  /// 目前生效的縣市層級特報（-001）併公告（-002）。
  ///
  /// 「無生效特報」＝ -001 的 `records.location` 存在且每縣市 hazards 皆空，
  /// -002 的 `records.record` 缺漏／空；回 [Success] 且 `counties` 為空。
  /// 區分失敗：HTTP 錯誤、`success != "true"`、-001 缺 `records.location`
  /// 或 `records` 非物件、欄位型別不符，一律 [Failure]。
  /// -001 有特報但 -002 無任何公告 → [Failure]（兩資料集不一致，不默默丟掉內文）。
  Future<Result<ActiveWarnings>> getActiveWarnings() => guardRequest<ActiveWarnings>(
        () async {
          final responses = await Future.wait([
            _dio.get<Object?>(AppConstants.warningsByCountyDataset),
            _dio.get<Object?>(AppConstants.warningBulletinsDataset),
          ]);
          final w1 = _datastoreRecords(responses[0].data, AppConstants.warningsByCountyDataset);
          final w2 = _datastoreRecords(responses[1].data, AppConstants.warningBulletinsDataset);
          final bulletins = _bulletins(w2);
          final warnings = ActiveWarnings.fromJson(w1, bulletins, clock());
          if (warnings.counties.isNotEmpty && bulletins.isEmpty) {
            return const Failure(
              '[${AppConstants.warningBulletinsDataset}] expected bulletins because ${AppConstants.warningsByCountyDataset} lists active warnings, got none',
            );
          }
          return Success(warnings);
        },
        dataset: '${AppConstants.warningsByCountyDataset}/${AppConstants.warningBulletinsDataset}',
        parseFailure: (detail) => '[${AppConstants.warningsByCountyDataset}/${AppConstants.warningBulletinsDataset}] 解析失敗：$detail',
      );

  /// 資料集內全部測站（所有縣市），不需要使用者位置。
  Future<Result<List<RainStation>>> getRainStations() => guardRequest<List<RainStation>>(
        () async {
          final response = await _dio.get<Object?>(AppConstants.rainObservationDataset);
          return Success(parseRainStations(_datastoreRecords(response.data, AppConstants.rainObservationDataset)));
        },
        dataset: AppConstants.rainObservationDataset,
        parseFailure: (detail) => '[${AppConstants.rainObservationDataset}] 解析失敗：$detail',
      );

  /// 指定縣市的雨量觀測：該縣市所有測站與離 ([latitude], [longitude]) 最近的有值測站。
  ///
  /// [county] 必須與 CWA 縣市名完全相同（用「臺」不用「台」）；
  /// 無任何測站符合或測站皆缺值 → [Failure]。
  Future<Result<CountyRainfall>> getRainfall({
    required String county,
    required double latitude,
    required double longitude,
  }) async {
    return switch (await getRainStations()) {
      Success(data: final all) => _countyRainfall(all, county, latitude, longitude),
      final Failure<List<RainStation>> f => f.retype<CountyRainfall>(),
    };
  }

  Result<CountyRainfall> _countyRainfall(List<RainStation> all, String county, double latitude, double longitude) {
    final inCounty = all.where((s) => s.county == county).toList();
    if (inCounty.isEmpty) {
      return Failure('[${AppConstants.rainObservationDataset}] 查無縣市「$county」的雨量站（共 ${all.length} 站，CWA 縣市名須用「臺」）');
    }
    final withValue = inCounty.where((s) => s.todayMm != null).toList();
    if (withValue.isEmpty) {
      return Failure('[${AppConstants.rainObservationDataset}] 縣市「$county」的 ${inCounty.length} 個雨量站今日累積皆為缺值');
    }
    withValue.sort((a, b) => a.distanceSqTo(latitude, longitude).compareTo(b.distanceSqTo(latitude, longitude)));
    return Success(CountyRainfall(county: county, stations: inCounty, allStations: all, nearest: withValue.first));
  }

  /// 1 小時雨量預測整張格點，不需要使用者位置。
  Future<Result<RainForecastGrid>> getRainForecastGrid() => _fileApi(AppConstants.rainForecast1hDataset, RainForecastGrid.fromJson);

  /// 使用者位置的 1 小時雨量預測；座標不在格點範圍內 → [Failure]。
  Future<Result<RainForecast>> getRainForecast({required double latitude, required double longitude}) async {
    return switch (await getRainForecastGrid()) {
      Success(data: final g) => g.contains(latitude, longitude)
          ? Success(RainForecast(grid: g, mmAtLocation: g.valueAt(latitude, longitude)))
          : Failure<RainForecast>('[${AppConstants.rainForecast1hDataset}] 座標 ($latitude, $longitude) 不在預報格點範圍內'),
      final Failure<RainForecastGrid> f => f.retype<RainForecast>(),
    };
  }

  // ==========================================================================
  // 私有輔助
  // ==========================================================================

  Future<Result<T>> _fileApi<T>(String dataset, T Function(Object? root) parse) => guardRequest<T>(
        () async {
          final response = await _dio.get<Object?>(AppConstants.fileApiUrl(dataset));
          final body = _jsonMap(response.data, dataset);
          return Success(parse(body['cwaopendata']));
        },
        dataset: dataset,
        parseFailure: (detail) => '[$dataset] 解析失敗：$detail',
      );

  /// fileapi 可能回 String 或已解碼的 Map
  Map<String, dynamic> _jsonMap(Object? data, String dataset) {
    final decoded = data is String ? jsonDecode(data) : data;
    if (decoded is Map<String, dynamic>) return decoded;
    throw FormatException('expected JSON object body, got ${decoded.runtimeType}');
  }

  /// datastore 回應 → `records`；`success` 必須為 "true"
  Object? _datastoreRecords(Object? data, String dataset) {
    final body = _jsonMap(data, dataset);
    if (body['success'] != 'true') {
      throw FormatException('expected success "true", got ${body['success']}');
    }
    return body['records'];
  }

  /// -002 的 `records.record`；缺漏或 null 視為無公告
  List<WarningBulletin> _bulletins(Object? records) {
    if (records is! Map<String, dynamic>) {
      throw FormatException('expected object at records, got ${records.runtimeType}');
    }
    final record = records['record'];
    if (record == null) return const [];
    if (record is! List<dynamic>) {
      throw FormatException('expected array at records.record, got ${record.runtimeType}');
    }
    return [
      for (var i = 0; i < record.length; i++)
        // 無 hazardConditions ＝ 已解除的公告（API 正常狀態），不是生效特報
        if (!_isLifted(record[i])) WarningBulletin.fromJson(record[i], 'records.record[$i]'),
    ];
  }

  bool _isLifted(Object? record) => record is Map<String, dynamic> && record['hazardConditions'] == null;
}
