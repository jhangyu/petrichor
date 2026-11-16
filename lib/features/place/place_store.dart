import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/stored_setting.dart';
import '../../data/models/place.dart';

final placeStoreProvider = FutureProvider<PlaceStore>(
  (ref) async => PlaceStore(await ref.watch(sharedPreferencesProvider.future)),
  retry: noRetry,
);

/// 已儲存地點與手動選定地點的本機存取。讀取時一次解析成 [Place]，損毀即丟 [StoredSettingException]。
class PlaceStore {
  static const manualPlaceKey = 'place.current';
  static const savedPlacesKey = 'place.saved';

  /// true＝自動定位開啟（啟動時定位）；false＝已關閉；不存在＝首次使用
  static const autoLocateKey = 'place.gps';

  final SharedPreferences _preferences;
  PlaceStore(this._preferences);

  /// null＝尚未選過；非 bool＝損毀，丟 [StoredSettingException]。
  bool? loadAutoLocate() {
    final Object? raw = _preferences.get(autoLocateKey);
    if (raw == null || raw is bool) return raw as bool?;
    throw StoredSettingException(autoLocateKey, '儲存資料損毀：期望 true/false，實際「$raw」');
  }

  Future<void> saveAutoLocate(bool value) => writeChecked(autoLocateKey, _preferences.setBool(autoLocateKey, value));

  /// 手動選定的地點；null＝使用 GPS
  Place? loadManualPlace() {
    final raw = _preferences.getString(manualPlaceKey);
    return raw == null ? null : _decode(manualPlaceKey, raw, (json) => Place.fromJson(json, manualPlaceKey));
  }

  Future<void> saveManualPlace(Place? place) => place == null
      ? writeChecked(manualPlaceKey, _preferences.remove(manualPlaceKey))
      : writeChecked(manualPlaceKey, _preferences.setString(manualPlaceKey, jsonEncode(place.toJson())));

  List<Place> loadSavedPlaces() {
    final raw = _preferences.getString(savedPlacesKey);
    if (raw == null) return const [];
    return _decode(savedPlacesKey, raw, (json) {
      if (json is! List<Object?>) throw FormatException('期望陣列，實際 ${json.runtimeType}');
      return [for (var i = 0; i < json.length; i++) Place.fromJson(json[i], '$savedPlacesKey[$i]')];
    });
  }

  Future<void> saveSavedPlaces(List<Place> places) =>
      writeChecked(savedPlacesKey, _preferences.setString(savedPlacesKey, jsonEncode([for (final p in places) p.toJson()])));

  T _decode<T>(String key, String raw, T Function(Object? json) parse) {
    try {
      return parse(jsonDecode(raw));
    } on FormatException catch (error) {
      throw StoredSettingException(key, '儲存資料損毀：${error.message}；實際內容「$raw」');
    }
  }
}
