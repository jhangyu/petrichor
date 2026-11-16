import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/location/location_service.dart';
import '../../core/storage/stored_setting.dart';
import '../../data/models/place.dart';
import '../../data/models/weather_models.dart';
import '../../core/api/result.dart';
import '../../data/repositories/weather_repository.dart';

final locationServiceProvider =
    Provider((ref) => LocationService(ref.watch(weatherRepositoryProvider).nearestTown));

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

/// 定位失敗 → 頁面標題（全 App 唯一對照）
String locationFailureTitle(LocationFailure failure) {
  return switch (failure) {
    LocationFailure.serviceDisabled => '定位服務已關閉',
    LocationFailure.permissionDenied => '未取得位置權限',
    LocationFailure.permissionDeniedForever => '位置權限已關閉',
    LocationFailure.positionUnavailable || LocationFailure.addressUnresolved => '無法取得目前位置',
  };
}

/// 無法開啟系統設定頁（[what] 如「應用程式設定」）時的提示
String openSettingsFailedMessage(String what) => '無法開啟$what，請手動前往系統設定';

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

// ============================================================================
// Providers
// ============================================================================

/// 目前地點：有手動選定地點就用它；自動定位開啟就定位；已關閉＝[NoPlace.autoLocateOff]；從未選過＝[NoPlace.firstRun]（皆不請求權限）。
/// GPS 失敗＝[NoPlace]（不給預設地點）。
/// 儲存資料損毀＝AsyncError(StoredSettingException)；呼叫 [CurrentPlaceNotifier.select]／startAutoLocate／stopAutoLocate 會覆寫並恢復。
final currentPlaceProvider = AsyncNotifierProvider<CurrentPlaceNotifier, CurrentPlace>(
  CurrentPlaceNotifier.new,
  retry: noRetry,
);

class CurrentPlaceNotifier extends AsyncNotifier<CurrentPlace> {
  @override
  Future<CurrentPlace> build() async {
    final store = await ref.watch(placeStoreProvider.future);
    final manual = store.loadManualPlace();
    if (manual != null) return PlaceSelected(manual, PlaceSource.manual);
    final autoLocate = store.loadAutoLocate();
    if (autoLocate == null) return NoPlace.firstRun();
    if (!autoLocate) return NoPlace.autoLocateOff();
    return await _locate() ?? state.requireValue;
  }

  /// 每次定位或手動選擇就加一；定位回來時 generation 已變＝期間有人改了地點，結果作廢。
  int _locateGeneration = 0;

  /// 設為目前地點（手動），並存到本機。
  Future<void> select(Place place) async {
    _locateGeneration++;
    final store = await ref.read(placeStoreProvider.future);
    await store.saveManualPlace(place);
    await store.saveAutoLocate(false);
    state = AsyncData(PlaceSelected(place, PlaceSource.manual));
  }

  /// 關閉自動定位。目前顯示 GPS 地點時保留它為手動地點；否則進入 [NoPlace.autoLocateOff]。進行中的定位作廢。
  Future<void> stopAutoLocate() async {
    _locateGeneration++;
    final current = state.value;
    if (current is PlaceSelected && current.source == PlaceSource.gps) {
      await select(current.place);
      return;
    }
    await (await ref.read(placeStoreProvider.future)).saveAutoLocate(false);
    state = AsyncData(NoPlace.autoLocateOff());
  }

  /// 改用 GPS：清除手動選定、記住「用 GPS」並重新定位（權限未決時會向系統請求權限）。
  Future<void> startAutoLocate() async {
    final store = await ref.read(placeStoreProvider.future);
    await store.saveManualPlace(null);
    await store.saveAutoLocate(true);
    state = const AsyncLoading();
    final located = await _locate();
    if (located != null) state = AsyncData(located);
  }

  /// 定位；回傳 null＝等待期間已被更新的定位或手動選擇取代，結果作廢。
  Future<CurrentPlace?> _locate() async {
    final generation = ++_locateGeneration;
    try {
      final location = await ref.read(locationServiceProvider).getCurrentLocation();
      if (generation != _locateGeneration) return null;
      final fixedAt = location.fixedAt ??
          (throw StateError('GPS location for ${location.county}${location.town}: expected a fix time, got null'));
      return PlaceSelected(location.toPlace(), PlaceSource.gps, fixedAt: fixedAt);
    } on LocationException catch (error) {
      return generation == _locateGeneration ? NoPlace(error) : null;
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
  Future<List<Place>> build() async => (await ref.watch(placeStoreProvider.future)).loadSavedPlaces();

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
    await (await ref.read(placeStoreProvider.future)).saveSavedPlaces(places);
    state = AsyncData(places);
  }
}

/// [county] 的鄉鎮清單（縣市名用「臺」；可選縣市＝CwaDatasets.townshipForecastDatasets.keys）
final townsProvider = FutureProvider.family<Result<List<Place>>, String>((ref, county) {
  return ref.watch(weatherRepositoryProvider).getTowns(county);
});

/// 單一地點的即時觀測（已儲存地點列表的現況溫度）。
// ponytail: 每個地點各抓一次全臺觀測（O-A0003-001），地點多時改為共用一次觀測再依座標挑站。
final placeObservationProvider = FutureProvider.family<Result<CurrentWeather>, Place>((ref, place) {
  return ref.watch(weatherRepositoryProvider).getCurrentWeather(place);
});
