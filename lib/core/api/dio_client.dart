import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

/// Dio HTTP 用戶端 Provider（REST API）
///
///單例模式，全域共享。自動處理：
/// - API 授權 header
/// - 連線/接收逾時
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.cwaApiBaseUrl,
      connectTimeout: Duration(milliseconds: AppConstants.connectTimeoutMs),
      receiveTimeout: Duration(milliseconds: AppConstants.receiveTimeoutMs),
      followRedirects: true,
      maxRedirects: AppConstants.maxRedirects,
      headers: {
        'Authorization': AppConstants.cwaApiKey,
        'Accept': 'application/json',
      },
      queryParameters: {
        'format': 'JSON',
      },
    ),
  );

  // -------------------------------------------------------------------------
  // 請求攔截器：注入 API key header
  // -------------------------------------------------------------------------
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      // 確保每次請求都有 API key
      if (AppConstants.hasApiKey) {
        options.headers['Authorization'] = AppConstants.cwaApiKey;
      }
      handler.next(options);
    },
  ));

  return dio;
});

/// Dio HTTP 用戶端 Provider（File API）
///
/// 獨立的 Dio實例，用於 fileapi/v1/opendataapi 端點。
/// 不使用 baseUrl 和預設 queryParameters，直接使用完整 URL。
final fileApiDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: Duration(milliseconds: AppConstants.connectTimeoutMs),
      receiveTimeout: Duration(milliseconds: AppConstants.receiveTimeoutMs),
      followRedirects: true,
      maxRedirects: AppConstants.maxRedirects,
      headers: {
        'Accept': 'application/json',
      },
    ),
  );
});

/// 檢查是否為 API 錯誤（需檢查 API key）
bool isApiError(DioException error) {
  final statusCode = error.response?.statusCode;
  return statusCode == 401 || statusCode == 403;
}
