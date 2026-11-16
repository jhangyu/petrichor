import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/stored_setting.dart';

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
