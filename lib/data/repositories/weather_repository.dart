import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/dio_client.dart';
import '../../core/constants/app_constants.dart';
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
  factory Result.failure(String message, {int? statusCode}) = Failure<T>;

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

/// 失敗結果
final class Failure<T> extends Result<T> {
  final String message;
  final int? statusCode;
  const Failure(this.message, {this.statusCode});
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
  // 一週預報
  // ==========================================================================

  /// 取得一週天氣預報
  ///
  /// [locationName] 鄉鎮市區名稱（如「臺北市」、「新竹縣」）
  ///
  /// 回傳 [Result]：
  /// - [Success] 包含 [WeeklyForecast]
  /// - [Failure] 包含錯誤訊息與 HTTP 狀態碼
  Future<Result<WeeklyForecast>> getWeeklyForecast(String locationName) async {
    if (!AppConstants.hasApiKey) {
      return const Failure('API Key 未設定，請使用 --dart-define=CWA_API_KEY=your_key');
    }

    try {
      final response = await _dio.get(
        AppConstants.forecast24hDataset,
        queryParameters: {'locationName': locationName},
      );

      final forecast = WeeklyForecast.fromCwaJson(response.data, targetLocation: locationName);

      if (forecast.days.isEmpty) {
        return Failure('查無此地點的天氣預報：$locationName');
      }

      return Success(forecast);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return Failure('解析天氣資料失敗：$e');
    }
  }

  // ==========================================================================
  // 目前天氣
  // ==========================================================================

  /// 取得目前天氣（示範用，需確認 CWA 即時觀測 API endpoint）
  ///
  /// 注意：CWA 即時觀測資料集可能需要不同 dataset ID，
  /// 此處使用通用結構，需依實際 API 文件調整。
  Future<Result<CurrentWeather>> getCurrentWeather(String locationName) async {
    if (!AppConstants.hasApiKey) {
      return const Failure('API Key 未設定，請使用 --dart-define=CWA_API_KEY=your_key');
    }

    try {
      // 目前使用 F-D0047-089取得最新預報資料作為「目前天氣」，
      // 如有專用即時觀測 API 再替換。
      final response = await _dio.get(
        AppConstants.forecast24hDataset,
        queryParameters: {'locationName': locationName},
      );

      final forecast = WeeklyForecast.fromCwaJson(response.data, targetLocation: locationName);

      if (forecast.days.isEmpty) {
        return Failure('查無此地點的天氣資料：$locationName');
      }

      // 取第一筆預報作為「目前」天氣
      final today = forecast.days.first;
      return Success(CurrentWeather(
        locationName: forecast.locationName,
        temperature: (today.maxTemperature + today.minTemperature) / 2,
        feelsLike: (today.maxTemperature + today.minTemperature) / 2,
        humidity: today.pop,
        windSpeed: 0, // 預報資料無風速，取0
        weatherDescription: today.weatherDescription,
        weatherCode: today.weatherCode,
        pop: today.pop,
        observationTime: DateTime.now().toIso8601String(),
      ));
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return Failure('取得目前天氣失敗：$e');
    }
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
  // 向後相容方法
  // ==========================================================================

  /// 取得24 小時預報（向後相容）
  @Deprecated('使用 getWeeklyForecast 取代')
  Future<List<WeatherCondition>> get24hForecast(
    String city,
    String district,
  ) async {
    final result = await getWeeklyForecast(_normalizeCountyName(city));
    return result.fold(
      onSuccess: (forecast) {
        return forecast.days
            .take(3)
            .map((d) => WeatherCondition(
                  wx: d.weatherDescription,
                  pop: d.pop,
                  t: d.maxTemperature.round(),
                  startTime: d.date,
                  endTime: d.date,
                ))
            .toList();
      },
      onFailure: (_, _) => [],
    );
  }

  String _normalizeCountyName(String countyName) {
    const cwaCountyNames = {
      '台北市': '臺北市',
      '台中市': '臺中市',
      '台南市': '臺南市',
      '台東縣': '臺東縣',
    };
    return cwaCountyNames[countyName] ?? countyName;
  }

  // ==========================================================================
  // 私有輔助方法
  // ==========================================================================

  /// 處理 Dio 例外
  Result<T> _handleDioError<T>(DioException e) {
    if (isApiError(e)) {
      return Failure(
        'API 授權失敗，請確認 API Key 正確',
        statusCode: e.response?.statusCode,
      );
    }
    return Failure(
      _formatDioError(e),
      statusCode: e.response?.statusCode,
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
