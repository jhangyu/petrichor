import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

/// Dio HTTP 用戶端 Provider（REST API）
///
///單例模式，全域共享。自動處理：
/// - API 授權 header
/// - 連線/接收逾時
/// - 錯誤處理與日誌
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.cwaApiBaseUrl,
      connectTimeout: Duration(milliseconds: AppConstants.connectTimeoutMs),
      receiveTimeout: Duration(milliseconds: AppConstants.receiveTimeoutMs),
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
    onError: (error, handler) {
      // 統一錯誤處理
      final message = _formatDioError(error);
      //開發模式輸出錯誤
      assert(() {
        print('[DioClient] API Error: $message');
        return true;
      }());
      handler.next(error);
    },
  ));

  // -------------------------------------------------------------------------
  //開發模式日誌（release模式關閉）
  // -------------------------------------------------------------------------
  dio.interceptors.add(LogInterceptor(
    request: false,
    requestHeader: false,
    requestBody: false,
    responseHeader: false,
    responseBody: false,
    error: true,
    logPrint: (obj) => print('[DioClient] $obj'),
  ));

  return dio;
});

/// Dio HTTP 用戶端 Provider（File API）
///
/// 獨立的 Dio實例，用於 fileapi/v1/opendataapi 端點。
/// 不使用 baseUrl 和預設 queryParameters，直接使用完整 URL。
final fileApiDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: Duration(milliseconds: AppConstants.connectTimeoutMs),
      receiveTimeout: Duration(milliseconds: AppConstants.receiveTimeoutMs),
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(LogInterceptor(
    request: false,
    requestHeader: false,
    requestBody: false,
    responseHeader: false,
    responseBody: false,
    error: true,
    logPrint: (obj) => print('[FileApiDio] $obj'),
  ));

  return dio;
});

// ============================================================================
// 錯誤處理
// ============================================================================

/// Dio 例外封裝
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const ApiException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => 'ApiException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

///格式化 Dio 錯誤為易讀訊息
String _formatDioError(DioException error) {
  return switch (error.type) {
    DioExceptionType.connectionTimeout => '連線逾時，請檢查網路',
    DioExceptionType.sendTimeout => '傳送逾時，請稍後再試',
    DioExceptionType.receiveTimeout => '接收逾時，伺服器回應過慢',
    DioExceptionType.badCertificate => 'SSL 憑證錯誤',
    DioExceptionType.badResponse => _formatHttpError(error.response),
    DioExceptionType.cancel => '請求已取消',
    DioExceptionType.connectionError => '連線失敗，請檢查網路設定',
    DioExceptionType.unknown => error.message ?? '未知錯誤',
  };
}

/// 格式化 HTTP 錯誤狀態碼
String _formatHttpError(Response? response) {
  if (response == null) return '無回應';
  final statusCode = response.statusCode ?? 0;
  final reason = response.statusMessage ?? '';

  return switch (statusCode) {
    400 => '請求格式錯誤（HTTP 400）',
    401 => '未授權，請確認 API Key 正確',
    403 => '拒絕存取，API Key 無效或已過期',
    404 => '找不到資料（HTTP 404）',
    429 => '請求頻率過高，請稍後再試',
    >= 500 => '伺服器錯誤（HTTP $statusCode），請稍後再試',
    _ => 'HTTP錯誤 $statusCode${reason.isNotEmpty ? ' $reason' : ''}',
  };
}

/// 檢查是否為網路相關錯誤（可重試）
bool isNetworkError(DioException error) {
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError =>
      true,
    _ => false,
  };
}

/// 檢查是否為 API 錯誤（需檢查 API key）
bool isApiError(DioException error) {
  final statusCode = error.response?.statusCode;
  return statusCode == 401 || statusCode == 403;
}
