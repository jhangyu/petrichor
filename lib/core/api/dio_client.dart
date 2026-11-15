import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'result.dart' show ApiKeyIssue, CwaApiKeyException;
import '../constants/app_constants.dart';
import '../storage/stored_setting.dart';
import 'api_key.dart';

/// Dio HTTP 用戶端 Provider（datastore 與 fileapi 皆經此）
///
/// 自動處理：
/// - 連線/接收逾時
/// - 以 query 加入使用者在「設定」輸入的 API key（缺少或讀不出 → 拒絕請求，不送出）
///
/// 監看 [cwaApiKeyProvider]：金鑰變更後本 provider 重建，下游 repository 隨之重建。
final dioProvider = Provider<Dio>((ref) {
  final key = ref.watch(cwaApiKeyProvider.future);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.cwaApiBaseUrl,
      connectTimeout: Duration(milliseconds: AppConstants.connectTimeoutMs),
      receiveTimeout: Duration(milliseconds: AppConstants.receiveTimeoutMs),
      followRedirects: true,
      maxRedirects: AppConstants.maxRedirects,
      headers: {
        'Accept': 'application/json',
      },
      queryParameters: {
        'format': 'JSON',
      },
    ),
  );

  // query 不會隨 fileapi 的 302 轉址帶到 S3
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final CwaApiKey? resolved;
      try {
        resolved = await key;
      } on StoredSettingException catch (e) {
        return handler.reject(DioException(
          requestOptions: options,
          error: CwaApiKeyException(ApiKeyIssue.unreadable, '儲存的 token 無法讀取：${e.message}'),
        ));
      }
      if (resolved == null) {
        return handler.reject(DioException(
          requestOptions: options,
          error: const CwaApiKeyException(ApiKeyIssue.missing, '尚未設定 token，請到「設定」輸入'),
        ));
      }
      options.queryParameters['Authorization'] = resolved.value;
      handler.next(options);
    },
  ));

  return dio;
});

/// Dio HTTP 用戶端 Provider（網站資源，無金鑰）
///
/// 獨立的 Dio實例，只給雷達用（www.cwa.gov.tw 的 JS 清單與圖片）。
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
