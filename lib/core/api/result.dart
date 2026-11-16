import 'package:dio/dio.dart';

// ============================================================================
// Result 型別（Error handling）
// ============================================================================

/// API 操作結果封裝
sealed class Result<T> {
  const Result();

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
  final String? dataset;
  final String? location;

  /// Non-null = the request failed because of the API key; pages show 「請到「設定」輸入 / 更新 token」.
  final ApiKeyIssue? apiKeyIssue;
  const Failure(this.message, {this.dataset, this.location, this.apiKeyIssue});

  /// The same failure as another result type (message, dataset, location and API-key issue kept).
  Failure<R> retype<R>() => Failure<R>(message, dataset: dataset, location: location, apiKeyIssue: apiKeyIssue);
}

/// Why a request failed because of the API key.
enum ApiKeyIssue { missing, rejected, unreadable }

/// Interceptor rejection payload (`DioException.error`).
class CwaApiKeyException implements Exception {
  final ApiKeyIssue issue;
  final String message;
  const CwaApiKeyException(this.issue, this.message);

  @override
  String toString() => 'CwaApiKeyException(${issue.name}): $message';
}

/// The one DioException → [Failure] mapping for every repository.
Failure<T> failureFromDio<T>(DioException e, {required String dataset, String? location}) {
  final status = e.response?.statusCode;
  final error = e.error;
  final issue = error is CwaApiKeyException
      ? error.issue
      : (status == 401 || status == 403)
          ? ApiKeyIssue.rejected
          : null;
  final message = switch (error) {
    CwaApiKeyException(:final message) => message,
    _ when issue == ApiKeyIssue.rejected => 'API 授權失敗，請確認 API Key 正確（HTTP $status）',
    _ => switch (e.type) {
        DioExceptionType.connectionTimeout => '連線逾時，請檢查網路',
        DioExceptionType.sendTimeout => '傳送逾時，請稍後再試',
        DioExceptionType.receiveTimeout => '接收逾時，請稍後再試',
        DioExceptionType.badResponse => '伺服器回應錯誤：$status',
        DioExceptionType.cancel => '請求已取消',
        DioExceptionType.connectionError => '連線失敗，請檢查網路',
        _ => '網路錯誤：${e.message}',
      },
  };
  return Failure(
    _withScope(message, dataset, location),
    dataset: dataset,
    location: location,
    apiKeyIssue: issue,
  );
}

/// 受影響的資料集與地點附在訊息尾端（全 App 唯一格式）。
String _withScope(String message, String dataset, String? location) =>
    location == null ? '$message（資料集 $dataset）' : '$message（資料集 $dataset，地點 $location）';

/// The one request guard for every repository: runs [request]; a [DioException] becomes
/// [failureFromDio], a [FormatException] a 「解析失敗」 [Failure]. Both carry [dataset] and [location].
Future<Result<T>> guardRequest<T>(
  Future<Result<T>> Function() request, {
  required String dataset,
  String? location,
}) async {
  try {
    return await request();
  } on DioException catch (error) {
    return failureFromDio(error, dataset: dataset, location: location);
  } on FormatException catch (error) {
    return Failure(_withScope('解析失敗：${error.message}', dataset, location), dataset: dataset, location: location);
  }
}
