import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/location/location_service.dart';
import '../../data/models/place.dart';
import '../../data/models/weather_models.dart';
import '../../data/repositories/weather_repository.dart';

// ============================================================================
// 目前地點狀態
// ============================================================================

/// 目前地點的來源
enum PlaceSource { gps, manual }

/// 全 App 唯一的「目前地點」。要嘛已有地點，要嘛沒有地點＋原因（絕無預設地點）。
sealed class CurrentPlace {
  const CurrentPlace();
}

/// 已有目前地點
final class PlaceSelected extends CurrentPlace {
  final Place place;
  final PlaceSource source;
  const PlaceSelected(this.place, this.source);
}

/// 尚無地點：未選手動地點且 GPS 定位失敗。頁面顯示引導（開權限／手動選擇），不顯示資料。
final class NoPlace extends CurrentPlace {
  final LocationException error;
  const NoPlace(this.error);

  LocationFailure get reason => error.failure;
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

/// 儲存資料是確定性的，重試不會修好損毀資料，故不重試。
Duration? _noRetry(int retryCount, Object error) => null;

final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
  retry: _noRetry,
);

final placeStoreProvider = FutureProvider<PlaceStore>(
  (ref) async => PlaceStore(await ref.watch(sharedPreferencesProvider.future)),
  retry: _noRetry,
);

/// 已儲存地點與手動選定地點的本機存取。讀取時一次解析成 [Place]，損毀即丟 [StoredPlaceException]。
class PlaceStore {
  static const currentKey = 'place.current';
  static const savedKey = 'place.saved';

  final SharedPreferences _prefs;
  PlaceStore(this._prefs);

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

/// 目前地點：有手動選定地點就用它，否則用 GPS；GPS 失敗＝[NoPlace]（不給預設地點）。
/// 儲存資料損毀＝AsyncError(StoredPlaceException)；呼叫 [CurrentPlaceNotifier.select] 會覆寫並恢復。
final currentPlaceProvider = AsyncNotifierProvider<CurrentPlaceNotifier, CurrentPlace>(
  CurrentPlaceNotifier.new,
  retry: _noRetry,
);

class CurrentPlaceNotifier extends AsyncNotifier<CurrentPlace> {
  @override
  Future<CurrentPlace> build() async {
    final manual = (await ref.watch(placeStoreProvider.future)).loadCurrent();
    if (manual != null) return PlaceSelected(manual, PlaceSource.manual);
    return _locate();
  }

  /// 設為目前地點（手動），並存到本機。
  Future<void> select(Place place) async {
    await (await ref.read(placeStoreProvider.future)).saveCurrent(place);
    state = AsyncData(PlaceSelected(place, PlaceSource.manual));
  }

  /// 改用 GPS：清除手動選定並重新定位（權限未決時會向系統請求權限）。
  Future<void> useGps() async {
    await (await ref.read(placeStoreProvider.future)).saveCurrent(null);
    state = const AsyncLoading();
    state = AsyncData(await _locate());
  }

  Future<CurrentPlace> _locate() async {
    try {
      final location = await ref.read(locationServiceProvider).getCurrentLocation();
      return PlaceSelected(Place.fromLocation(location), PlaceSource.gps);
    } on LocationException catch (e) {
      return NoPlace(e);
    }
  }
}

/// 已儲存地點（依加入順序）
final savedPlacesProvider = AsyncNotifierProvider<SavedPlacesNotifier, List<Place>>(
  SavedPlacesNotifier.new,
  retry: _noRetry,
);

class SavedPlacesNotifier extends AsyncNotifier<List<Place>> {
  @override
  Future<List<Place>> build() async => (await ref.watch(placeStoreProvider.future)).loadSaved();

  /// 儲存地點；已存在則不重複加入。
  Future<void> save(Place place) async {
    final current = await future;
    if (current.contains(place)) return;
    await _persist([...current, place]);
  }

  Future<void> remove(Place place) async =>
      _persist([for (final p in await future) if (p != place) p]);

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
