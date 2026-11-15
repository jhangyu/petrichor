import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stored data is deterministic: a retry never repairs it.
Duration? noRetry(int retryCount, Object error) => null;

final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
  retry: noRetry,
);

/// Stored setting is corrupt or could not be written ([key] = storage key).
class StoredSettingException implements Exception {
  final String key;
  final String message;
  const StoredSettingException(this.key, this.message);

  @override
  String toString() => 'StoredSettingException($key): $message';
}

/// Awaits [write] (a SharedPreferences write); false = the write failed.
Future<void> writeChecked(String key, Future<bool> write) async {
  if (!await write) throw StoredSettingException(key, '寫入失敗：期望 true，實際 false');
}

/// One setting remembered across restarts as an int under [key]. A corrupt
/// stored value is an [AsyncError]; [set] overwrites it and recovers.
abstract class IntSetting<T> extends AsyncNotifier<T> {
  /// Storage key, e.g. `radar.taiwan.opacity`.
  String get key;

  /// Value of a fresh install.
  T get defaultValue;

  /// Human-readable list of valid stored ints, for messages.
  String get expected;

  /// The setting for a stored int, or null when it is not a valid one.
  T? fromStored(int stored);

  int toStored(T value);

  @override
  Future<T> build() async {
    final Object? raw = (await ref.watch(sharedPreferencesProvider.future)).get(key);
    if (raw == null) return defaultValue;
    final value = raw is int ? fromStored(raw) : null;
    return value ?? (throw StoredSettingException(key, '儲存資料損毀：期望 $expected，實際「$raw」'));
  }

  /// Shows [value] at once, then stores it; a failed write becomes the state.
  Future<void> set(T value) async {
    if (fromStored(toStored(value)) == null) throw ArgumentError.value(value, 'value', 'expected $expected');
    state = AsyncData(value);
    final written = await AsyncValue.guard(() async {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await writeChecked(key, prefs.setInt(key, toStored(value)));
      return value;
    });
    // A later set() may have replaced the state meanwhile; only a failure overrides it.
    if (written is AsyncError || state.value == value) state = written;
  }
}
