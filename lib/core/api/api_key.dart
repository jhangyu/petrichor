import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../storage/stored_setting.dart';
import 'dio_client.dart';

/// A CWA Open Data key that passed the format check. The only way to build one is [parse].
extension type const CwaApiKey._(String value) {
  static final _format = RegExp(r'^CWA-[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$');

  /// Trims [input]; throws [FormatException] when it is not `CWA-` + uppercase UUID.
  /// The message gives the length, never the input (do not echo secrets into logs).
  static CwaApiKey parse(String input) {
    final trimmed = input.trim();
    if (!_format.hasMatch(trimmed)) {
      throw FormatException(
        'expected CWA-XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX (uppercase hex), got ${trimmed.length} chars',
      );
    }
    return CwaApiKey._(trimmed);
  }
}

/// Stored key: null = 未設定. A corrupt stored value = AsyncError(StoredSettingException); save()/clear() recover.
class CwaApiKeyNotifier extends AsyncNotifier<CwaApiKey?> {
  static const storageKey = 'cwa.apiKey';

  @override
  Future<CwaApiKey?> build() async {
    // Raw get: getString throws TypeError on a wrong stored type.
    final Object? raw = (await ref.watch(sharedPreferencesProvider.future)).get(storageKey);
    if (raw == null) return null;
    if (raw is! String) {
      throw StoredSettingException(storageKey, '儲存資料損毀：期望字串，實際型別 ${raw.runtimeType}');
    }
    try {
      return CwaApiKey.parse(raw);
    } on FormatException catch (error) {
      throw StoredSettingException(storageKey, '儲存資料損毀：${error.message}');
    }
  }

  /// Stores [key]; a failed write becomes the state.
  Future<void> save(CwaApiKey key) => _write(key, (preferences) => preferences.setString(storageKey, key.value));

  Future<void> clear() => _write(null, (preferences) => preferences.remove(storageKey));

  Future<void> _write(CwaApiKey? value, Future<bool> Function(SharedPreferences preferences) write) async {
    state = await AsyncValue.guard(() async {
      final preferences = await ref.read(sharedPreferencesProvider.future);
      await writeChecked(storageKey, write(preferences));
      return value;
    });
  }
}

final cwaApiKeyProvider = AsyncNotifierProvider<CwaApiKeyNotifier, CwaApiKey?>(CwaApiKeyNotifier.new, retry: noRetry);

/// Why a stored key is shown as 無效.
enum ApiKeyInvalidKind { rejected, unreachable, unexpected, unreadable }

/// Settings-card status of the *stored* key.
sealed class ApiKeyStatus {
  const ApiKeyStatus();
}

/// 未設定
final class ApiKeyNotSet extends ApiKeyStatus {
  const ApiKeyNotSet();
}

/// 驗證中
final class ApiKeyVerifying extends ApiKeyStatus {
  const ApiKeyVerifying();
}

/// 有效
final class ApiKeyValid extends ApiKeyStatus {
  final DateTime checkedAt;
  const ApiKeyValid(this.checkedAt);
}

/// 無效 + [reason]. [ApiKeyInvalidKind.unreachable] means the key could not be verified.
final class ApiKeyInvalid extends ApiKeyStatus {
  final ApiKeyInvalidKind kind;
  final String reason;
  const ApiKeyInvalid(this.kind, this.reason);
}

/// Saved but not verified yet in this run.
final class ApiKeyUnchecked extends ApiKeyStatus {
  const ApiKeyUnchecked();
}

/// Dataset used to probe the key (one station is enough).
const String _verifyDatasetId = AppConstants.observationDatasetId;

class ApiKeyStatusNotifier extends Notifier<ApiKeyStatus> {
  /// Bumped on every rebuild and verify; a verify result of an older one is dropped.
  int _generation = 0;

  @override
  ApiKeyStatus build() {
    _generation++;
    return switch (ref.watch(cwaApiKeyProvider)) {
      AsyncLoading() => const ApiKeyVerifying(),
      AsyncError(:final error) => ApiKeyInvalid(ApiKeyInvalidKind.unreadable, '$error'),
      AsyncData(value: null) => const ApiKeyNotSet(),
      AsyncData() => const ApiKeyUnchecked(),
    };
  }

  /// Asks CWA once whether the stored key is accepted.
  Future<void> verify() async {
    if (ref.read(cwaApiKeyProvider).value == null) return;
    final generation = ++_generation;
    state = const ApiKeyVerifying();
    final result = await _probe();
    if (!ref.mounted || generation != _generation) return;
    state = result;
  }

  Future<ApiKeyStatus> _probe() async {
    try {
      final response = await ref.read(cwaDioProvider).get<Object?>(_verifyDatasetId, queryParameters: {'limit': 1});
      final data = response.data;
      if (response.statusCode == 200 && data is Map<String, dynamic> && data['success'] == 'true') {
        return ApiKeyValid(DateTime.now());
      }
      final success = data is Map<String, dynamic> ? data['success'] : data.runtimeType;
      return ApiKeyInvalid(
        ApiKeyInvalidKind.unexpected,
        '期望 HTTP 200 + success "true"，實際 HTTP ${response.statusCode} success $success',
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      return switch (error.type) {
        _ when status == 401 || status == 403 => ApiKeyInvalid(ApiKeyInvalidKind.rejected, '金鑰被 CWA 拒絕（HTTP $status）'),
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError =>
          const ApiKeyInvalid(ApiKeyInvalidKind.unreachable, '無法連線 CWA，金鑰未驗證'),
        _ => ApiKeyInvalid(ApiKeyInvalidKind.unexpected, '期望 HTTP 200 + success "true"，實際 ${status ?? error.type.name}'),
      };
    }
  }
}

final apiKeyStatusProvider = NotifierProvider<ApiKeyStatusNotifier, ApiKeyStatus>(ApiKeyStatusNotifier.new);
