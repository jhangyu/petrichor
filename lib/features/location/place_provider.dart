import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/location/location_service.dart';
import '../../core/storage/stored_setting.dart';
import '../../data/models/place.dart';
import '../../data/models/weather_models.dart';
import '../../core/api/result.dart';
import '../../data/repositories/weather_repository.dart';

// ============================================================================
// 目前地點狀態
// ============================================================================

/// 目前地點的來源
enum PlaceSource { gps, manual }

/// 全 App 唯一的「目前地點」。要嘛已有地點，要嘛沒有地點＋原因（絕無預設地點）。
sealed class CurrentPlace {
  const CurrentPlace();

  /// 自動定位開關的實際狀態：GPS 地點，或定位失敗（仍開啟）。
  bool get autoLocate;
}

/// 已有目前地點
final class PlaceSelected extends CurrentPlace {
  final Place place;
  final PlaceSource source;

  /// GPS 定位時刻（地點頁「定位於」）；手動地點為 null
  final DateTime? fixedAt;

  const PlaceSelected(this.place, this.source, {this.fixedAt});

  @override
  bool get autoLocate => source == PlaceSource.gps;
}

/// 尚無地點的種類
enum NoPlaceKind { firstRun, autoLocateOff, locationFailed }

/// 尚無地點：首次使用、自動定位已關閉且無手動地點，或自動定位失敗。頁面顯示引導（開權限／手動選擇），不顯示資料。
final class NoPlace extends CurrentPlace {
  final LocationException error;

  final NoPlaceKind kind;

  const NoPlace(this.error) : kind = NoPlaceKind.locationFailed;

  @override
  bool get autoLocate => kind == NoPlaceKind.locationFailed;

  /// 首次使用。原因記為 permissionDenied：權限尚未決定時 geolocator 也回報 denied。
  NoPlace.firstRun()
      : error = LocationException(
          LocationFailure.permissionDenied,
          'Location permission not requested yet: the user has chosen neither GPS nor a manual place.',
        ),
        kind = NoPlaceKind.firstRun;

  /// 自動定位已關閉且沒有手動地點：絕不請求定位。
  NoPlace.autoLocateOff()
      : error = LocationException(
          LocationFailure.permissionDenied,
          'Auto-locate is off and no manual place is selected.',
        ),
        kind = NoPlaceKind.autoLocateOff;

  LocationFailure get reason => error.failure;

  /// 底層原因（[LocationException.message]，如 'Failed to read current position: …'）；頁面在引導文字下方原樣顯示。
  String get cause => error.message;
}

/// 定位失敗 → 使用者可讀訊息（含下一步）
String locationFailureMessage(LocationFailure failure) {
  return switch (failure) {
    LocationFailure.serviceDisabled => '裝置的定位服務已關閉，請開啟後重試，或手動選擇地點',
    LocationFailure.permissionDenied => '尚未允許定位權限，請允許後重試，或手動選擇地點',
    LocationFailure.permissionDeniedForever => '定位權限已被永久拒絕，請到系統設定開啟，或手動選擇地點',
    LocationFailure.positionUnavailable => '無法取得目前位置，請稍後重試，或手動選擇地點',
    LocationFailure.addressUnresolved => '無法判斷所在縣市與鄉鎮，請稍後重試，或手動選擇地點',
  };
}

// ============================================================================
// 本機儲存
// ============================================================================

/// 本機儲存的地點資料損毀（[key] 為受影響的儲存鍵）
class StoredPlaceException implements Exception {
  final String key;
  final String message;
  const StoredPlaceException(this.key, this.message);

  @override
  String toString() => 'StoredPlaceException($key): $message';
}

final placeStoreProvider = FutureProvider<PlaceStore>(
  (ref) async => PlaceStore(await ref.watch(sharedPreferencesProvider.future)),
  retry: noRetry,
);

/// 已儲存地點與手動選定地點的本機存取。讀取時一次解析成 [Place]，損毀即丟 [StoredPlaceException]。
class PlaceStore {
  static const currentKey = 'place.current';
  static const savedKey = 'place.saved';

  /// true＝自動定位開啟（啟動時定位）；false＝已關閉；不存在＝首次使用
  static const gpsKey = 'place.gps';

  final SharedPreferences _prefs;
  PlaceStore(this._prefs);

  /// null＝尚未選過；非 bool＝損毀，丟 [StoredPlaceException]。
  bool? loadUseGps() {
    final Object? raw = _prefs.get(gpsKey);
    if (raw == null || raw is bool) return raw as bool?;
    throw StoredPlaceException(gpsKey, '儲存資料損毀：期望 true/false，實際「$raw」');
  }

  Future<void> saveUseGps(bool value) => _write(gpsKey, _prefs.setBool(gpsKey, value));

  /// 手動選定的地點；null＝使用 GPS
  Place? loadCurrent() {
    final raw = _prefs.getString(currentKey);
    return raw == null ? null : _decode(currentKey, raw, (json) => Place.fromJson(json, currentKey));
  }

  Future<void> saveCurrent(Place? place) => place == null
      ? _write(currentKey, _prefs.remove(currentKey))
      : _write(currentKey, _prefs.setString(currentKey, jsonEncode(place.toJson())));

  List<Place> loadSaved() {
    final raw = _prefs.getString(savedKey);
    if (raw == null) return const [];
    return _decode(savedKey, raw, (json) {
      if (json is! List<Object?>) throw FormatException('期望陣列，實際 ${json.runtimeType}');
      return [for (var i = 0; i < json.length; i++) Place.fromJson(json[i], '$savedKey[$i]')];
    });
  }

  Future<void> saveSaved(List<Place> places) =>
      _write(savedKey, _prefs.setString(savedKey, jsonEncode([for (final p in places) p.toJson()])));

  T _decode<T>(String key, String raw, T Function(Object? json) parse) {
    try {
      return parse(jsonDecode(raw));
    } on FormatException catch (e) {
      throw StoredPlaceException(key, '儲存資料損毀：${e.message}；實際內容「$raw」');
    }
  }

  Future<void> _write(String key, Future<bool> write) async {
    if (!await write) throw StoredPlaceException(key, '寫入失敗：期望 true，實際 false');
  }
}

// ============================================================================
// Providers
// ============================================================================

/// 目前地點：有手動選定地點就用它；自動定位開啟就定位；已關閉＝[NoPlace.autoLocateOff]；從未選過＝[NoPlace.firstRun]（皆不請求權限）。
/// GPS 失敗＝[NoPlace]（不給預設地點）。
/// 儲存資料損毀＝AsyncError(StoredPlaceException)；呼叫 [CurrentPlaceNotifier.select]／useGps／stopAutoLocate 會覆寫並恢復。
final currentPlaceProvider = AsyncNotifierProvider<CurrentPlaceNotifier, CurrentPlace>(
  CurrentPlaceNotifier.new,
  retry: noRetry,
);

class CurrentPlaceNotifier extends AsyncNotifier<CurrentPlace> {
  @override
  Future<CurrentPlace> build() async {
    final store = await ref.watch(placeStoreProvider.future);
    final manual = store.loadCurrent();
    if (manual != null) return PlaceSelected(manual, PlaceSource.manual);
    final useGps = store.loadUseGps();
    if (useGps == null) return NoPlace.firstRun();
    if (!useGps) return NoPlace.autoLocateOff();
    return await _locate() ?? state.requireValue;
  }

  /// 每次定位或手動選擇就加一；定位回來時 epoch 已變＝期間有人改了地點，結果作廢。
  int _epoch = 0;

  /// 設為目前地點（手動），並存到本機。
  Future<void> select(Place place) async {
    _epoch++;
    final store = await ref.read(placeStoreProvider.future);
    await store.saveCurrent(place);
    await store.saveUseGps(false);
    state = AsyncData(PlaceSelected(place, PlaceSource.manual));
  }

  /// 關閉自動定位。目前顯示 GPS 地點時保留它為手動地點；否則進入 [NoPlace.autoLocateOff]。進行中的定位作廢。
  Future<void> stopAutoLocate() async {
    _epoch++;
    final current = state.value;
    if (current is PlaceSelected && current.source == PlaceSource.gps) {
      await select(current.place);
      return;
    }
    await (await ref.read(placeStoreProvider.future)).saveUseGps(false);
    state = AsyncData(NoPlace.autoLocateOff());
  }

  /// 改用 GPS：清除手動選定、記住「用 GPS」並重新定位（權限未決時會向系統請求權限）。
  Future<void> useGps() async {
    final store = await ref.read(placeStoreProvider.future);
    await store.saveCurrent(null);
    await store.saveUseGps(true);
    state = const AsyncLoading();
    final located = await _locate();
    if (located != null) state = AsyncData(located);
  }

  /// 定位；回傳 null＝等待期間已被更新的定位或手動選擇取代，結果作廢。
  Future<CurrentPlace?> _locate() async {
    final epoch = ++_epoch;
    try {
      final location = await ref.read(locationServiceProvider).getCurrentLocation();
      if (epoch != _epoch) return null;
      final fixedAt = location.fixedAt ??
          (throw StateError('GPS location for ${location.city}${location.district}: expected a fix time, got null'));
      return PlaceSelected(Place.fromLocation(location), PlaceSource.gps, fixedAt: fixedAt);
    } on LocationException catch (e) {
      return epoch == _epoch ? NoPlace(e) : null;
    }
  }
}

/// 已儲存地點（依加入順序）
final savedPlacesProvider = AsyncNotifierProvider<SavedPlacesNotifier, List<Place>>(
  SavedPlacesNotifier.new,
  retry: noRetry,
);

class SavedPlacesNotifier extends AsyncNotifier<List<Place>> {
  @override
  Future<List<Place>> build() async => (await ref.watch(placeStoreProvider.future)).loadSaved();

  /// 儲存地點；已存在則不重複加入。
  Future<void> save(Place place) async {
    final current = await future;
    if (current.any((p) => p.areaKey == place.areaKey)) return;
    await _persist([...current, place]);
  }

  Future<void> remove(Place place) async =>
      _persist([for (final p in await future) if (p.areaKey != place.areaKey) p]);

  /// 覆寫成空清單：損毀的已儲存地點的復原方式。
  Future<void> clear() => _persist(const []);

  Future<void> _persist(List<Place> places) async {
    await (await ref.read(placeStoreProvider.future)).saveSaved(places);
    state = AsyncData(places);
  }
}

/// [county] 的鄉鎮清單（縣市名用「臺」；可選縣市＝AppConstants.townshipForecastDatasets.keys）
final townsProvider = FutureProvider.family<Result<List<Place>>, String>((ref, county) {
  return ref.watch(weatherRepositoryProvider).getTowns(county);
});

/// 單一地點的即時觀測（已儲存地點列表的現況溫度）。
// ponytail: 每個地點各抓一次全臺觀測（O-A0003-001），地點多時改為共用一次觀測再依座標挑站。
final placeObservationProvider = FutureProvider.family<Result<CurrentWeather>, Place>((ref, place) {
  return ref.watch(weatherRepositoryProvider).getCurrentWeather(place.toLocationData());
});
