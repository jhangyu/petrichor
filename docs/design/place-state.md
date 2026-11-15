# 目前地點狀態（place-state）

全 App 唯一的「目前地點」來源。所有頁面都讀它，不要直接呼叫 `LocationService`。程式碼在 `lib/features/location/place_provider.dart`，`Place` 定義在 `lib/data/models/place.dart`。

## 型別
- `Place`：`county`、`town`（CWA 寫法，用「臺」）、`latitude`、`longitude`；`name` 回傳「臺北市中正區」；`hazardLocation` 回傳雨量／警特報用的 `HazardLocation`。比較時看全部四個欄位。
- `CurrentPlace`（sealed）
  - `PlaceSelected(place, source)`：`source` 是 `PlaceSource.gps` 或 `PlaceSource.manual`。
  - `NoPlace(error)`：目前沒有地點。`reason` 是 `LocationFailure`：`permissionDenied`、`permissionDeniedForever`、`serviceDisabled`、`positionUnavailable` 或 `addressUnresolved`。**沒有預設地點。** 這時頁面不顯示資料，改顯示引導；`locationFailureMessage(reason)` 提供中文說明。
  - `cause`：底層原因原文（`LocationException.message`，如 `Failed to read current position: …`）。頁面在 `locationFailureMessage(reason)` 下方原樣顯示一行「原因：…」；`reason` 只用來選引導方式。
  - `firstRun`：`true`＝首次使用，使用者還沒選 GPS 或手動地點，App 尚未請求定位權限（地點頁顯示首次說明）。此時 `reason` 是 `permissionDenied`（權限未決時 geolocator 也回報 denied），所以各頁沿用同一套引導。

## Providers
| Provider | 型別 | 用途 |
|---|---|---|
| `currentPlaceProvider` | `AsyncValue<CurrentPlace>` | 目前地點。loading＝讀取儲存資料或定位中；error＝本機儲存資料損毀（`StoredSettingException`） |
| `savedPlacesProvider` | `AsyncValue<List<Place>>` | 已儲存地點，依加入順序 |
| `townsProvider(county)` | `AsyncValue<Result<List<Place>>>` | 某縣市的鄉鎮清單與經緯度（資料來源是該縣市的 3 天鄉鎮預報資料集） |
| `placeObservationProvider(place)` | `AsyncValue<Result<CurrentWeather>>` | 某地點的即時觀測（已儲存地點列表顯示現況溫度） |
| `weatherNotifierProvider` | `WeatherState` | 首頁資料；`location` 是 `Place?`，地點一變就重新載入；沒有地點時 `error` 為引導訊息 |

縣市清單（橫向捲動）：`AppConstants.townshipForecastDatasets.keys`，共 22 縣市。搜尋只篩選所選縣市的鄉鎮清單。

## 頁面讀法
「手動選擇」切到地點 tab：`ref.read(appTabProvider.notifier).select(AppTab.location)`（`lib/core/navigation/app_tab.dart`）。

```dart
switch (ref.watch(currentPlaceProvider)) {
  AsyncData(value: PlaceSelected(:final place)) => /* 用 place，或用 place.hazardLocation */,
  AsyncData(value: NoPlace(:final reason)) => /* 依 reason 顯示引導與「手動選擇」 */,
  AsyncError(:final error) => /* 儲存資料損毀；讓使用者重新選擇地點 */,
  _ => /* 載入中 */,
}
```
雨量頁與警特報頁：`rainfallProvider(place.hazardLocation)`。

## 操作
- 設為目前地點（手動）：`ref.read(currentPlaceProvider.notifier).select(place)`。會存到本機，下次啟動仍沿用，也會覆寫損毀的資料。
- 改用 GPS／請求定位權限：`ref.read(currentPlaceProvider.notifier).useGps()`。會清除手動選擇、記住「使用者選了 GPS」，並重新定位；權限尚未決定時，會跳出系統的權限詢問。結果為 `PlaceSelected(gps)` 或 `NoPlace(reason)`。地點頁首次說明的「允許使用位置」就是呼叫它。
- 「前往設定」（`permissionDeniedForever`）：`Geolocator.openAppSettings()`；定位服務關閉（`serviceDisabled`）：`Geolocator.openLocationSettings()`。
- 儲存地點：`ref.read(savedPlacesProvider.notifier).save(place)`（已存在就不重複加入）。移除地點：`.remove(place)`。

## 啟動行為
1. 有手動選擇 → 用它，不定位。
2. 使用者選過 GPS（本機 `place.gps`）→ 啟動就定位。定位失敗就是 `NoPlace`。
3. 兩者都沒有（首次使用）→ `NoPlace.firstRun()`，**不請求權限、不跳系統詢問**；地點頁先顯示首次說明。

定位有時限：取得座標（`getCurrentPosition`）超過 `locationTimeout`（10 秒，使用者決定）沒有結果，就當失敗：`NoPlace(positionUnavailable)`，`cause` 寫明「10 秒內未取得位置」，頁面顯示引導與「手動選擇」。權限詢問是系統對話框，不計時。逾時或晚到的定位結果，若期間使用者已手動選地點或重新定位，一律作廢，不覆蓋。

`NoPlace` 時任何天氣 API 都不會被呼叫。

## 測試
`SharedPreferences.setMockInitialValues({...})`，並覆寫 `locationServiceProvider`；要測 GPS 路徑時放 `{PlaceStore.gpsKey: true}`（空的本機資料＝首次使用，不會定位）；`ProviderScope` 不需要額外的 override。
