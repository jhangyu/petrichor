# 設定 tab — preferences architecture (place settings + notification settings)

Spec: `docs/logs/settings-tab-contract.md` (frozen). Notifications are settings only: values are stored and restored after a restart. Nothing reads them to deliver a notification this round.
Versions (pubspec.lock): flutter_riverpod 3.3.2, shared_preferences 2.5.5. No new packages.

## 1. Current state (verified)

| Fact | Where |
|---|---|
| One SharedPreferences provider, used by place and radar code | `lib/features/location/place_provider.dart:85-88`, `lib/features/radar/radar_provider.dart:9,60,71` |
| Keys `place.current` (manual place, JSON), `place.saved` (JSON array), `place.gps` (bool, only ever written `true`) | `place_provider.dart:97-108` |
| Current-place resolution: a manual place wins. Otherwise, `place.gps` true → locate. Otherwise → `NoPlace.firstRun()` (no permission request) | `place_provider.dart:159-165` |
| `useGps()` clears the manual place, writes `place.gps=true`, and locates. The UI uses it for 允許使用位置, 重新定位 and 使用目前位置 | `place_provider.dart:178-185`; callers `location_screen.dart:88`, `weather_screen.dart:390`, `rainfall_screen.dart:117` |
| `select(place)` stores the manual place but does not touch `place.gps`, so a stale `true` stays behind | `place_provider.dart:171-175` |
| Stale results are dropped by an epoch counter | `place_provider.dart:168,188-199` |
| **Bug:** `loadUseGps()` uses `getBool`. A non-bool stored value throws an uncaught `TypeError`, not `StoredSettingException` | `place_provider.dart:106`; `shared_preferences-2.5.5/lib/src/shared_preferences_legacy.dart:117` |
| **Inconsistency:** saved places are de-duplicated by full `Place ==`, which includes coordinates. The screen matches places by county+town (a GPS place has device coordinates; the town list has town-centre coordinates). The same area can be saved twice | `place_provider.dart:215`, `place.dart:62-68`, `location_screen.dart:625-626` |
| Saved places support select and remove. Reorder is not supported. Search is a UI-only filter over county chips and the town list (`townsProvider`) | `location_screen.dart:443,576,690,700`; `place_provider.dart:229` |
| RadarSetting pattern: stored int, `prefs.get(key)` strict parse, corrupt value → `AsyncError(StoredRadarSettingException)`, `set()` shows the new value at once and recovers, failed write → error state, `retry: _noRetry` | `radar_provider.dart:37-80,148-151` |

## 2. Data model

### 2.1 Auto-locate (GPS) — reuse the existing `place.gps` key, one mechanism

`place.gps` becomes a real on/off value with three stored states:

| Stored `place.gps` | `place.current` | `CurrentPlace` result | Location requested? |
|---|---|---|---|
| absent | absent | `NoPlace` kind `firstRun` (unchanged) | no |
| `false` | absent | `NoPlace` kind `autoLocateOff` (new) | **no, never** |
| `true` | absent | `PlaceSelected(gps)` or `NoPlace` kind `locationFailed` (unchanged GPS flow) | yes |
| any | present | `PlaceSelected(manual)` (unchanged: a manual place wins) | no |
| not a bool | — | `AsyncError(StoredSettingException('place.gps', …))` | no |

The writes keep one invariant: **auto-locate on ⇔ no manual place stored.**
- `useGps()` (unchanged name and callers) = turn auto-locate on: clear `place.current`, write `place.gps=true`, locate. Calling it while already on = relocate (the 重新定位 button).
- `select(place)` = choose a manual place: write `place.current`, **and write `place.gps=false`** (new). The stale `true` is gone, so the toggle shows the real state.
- `stopAutoLocate()` (new) = turn auto-locate off. It increments the epoch first, so an in-flight fix is discarded. Then:
  - current is `PlaceSelected(gps)` → keep that place as the manual place: same body as `select(place)`, so it stays shown and no further location requests happen (lead decision).
  - otherwise → write `place.gps=false` and set state `NoPlace.autoLocateOff()`.
- The toggle value for the UI is derived. It is not a second provider, so the toggle and the current place can never disagree:
  `bool get autoLocate` on `CurrentPlace` → `PlaceSelected` → `source == gps`; `NoPlace` → `kind == locationFailed`.
  GPS state shown in the 地點設定 card: `PlaceSelected(gps).fixedAt` = located; `NoPlace(locationFailed).reason` = `permissionDenied` / `permissionDeniedForever` / `serviceDisabled` / `positionUnavailable` / `addressUnresolved` (message: `locationFailureMessage`, `place_provider.dart:58-66`).

`NoPlace` change: replace `final bool firstRun` (`place_provider.dart:39`) with `final NoPlaceKind kind`, `enum NoPlaceKind { firstRun, autoLocateOff, locationFailed }`, plus a temporary `bool get firstRun => kind == NoPlaceKind.firstRun`. **The frontend package removes this getter** when it rewrites the screens, and it switches the remaining callers to `kind`; no compatibility shim may remain after frontend wiring. Until then, existing consumers keep compiling (`location_screen.dart:72`, `place_state_test.dart:63,98`). `NoPlace.autoLocateOff()` follows the `firstRun()` precedent (`place_provider.dart:44-49`): `error = LocationException(LocationFailure.permissionDenied, 'Auto-locate is off and no manual place is selected.')`. Data pages that switch on `reason` (`weather_screen.dart:393`, `rainfall_screen.dart:51`, `warnings_screen.dart:62`, `radar_screen.dart:223`) then show 使用目前位置 / 手動選擇, the same as for first run. No edits are needed there.

Strict parse: `loadUseGps()` returns `bool?` from `prefs.get(gpsKey)`. A non-bool value → `StoredSettingException(gpsKey, '儲存資料損毀：期望 true/false，實際「$raw」')`. Recovery: `select`, `useGps` or `stopAutoLocate` overwrites the key and sets the state.

### 2.2 Saved place identity (area key)

A saved place is an area (鄉鎮). Its stable identifier is the normalized names, not the coordinates:

```dart
// lib/data/models/place.dart
/// Stable identity of the area, e.g. '臺北市/中正區' (names normalized to 「臺」, place.dart:19-24).
String get areaKey => '$county/$town';
```
- `SavedPlacesNotifier.save` de-duplicates by `areaKey`, not by `==`. This fixes the double-save case above. `remove` removes by `areaKey`.
- `location_screen.dart:626 _sameTown` is equivalent to `a.areaKey == b?.areaKey`. The frontend rewrite uses `areaKey`, and `_sameTown` goes away with that screen.
- **Delete / re-add:** notification settings keep only keys of saved places (§2.3 pruning). A place that is deleted and then added again starts with 警特報 **off**. It does not restore its old value.

### 2.3 Notification settings

| Setting | Type | Key | Stored as | Valid stored values | Default |
|---|---|---|---|---|---|
| master switch | bool | `notify.master` | int | 0 / 1 | false |
| 降雨提醒 | bool | `notify.rain` | int | 0 / 1 | false |
| 靜音時段 on/off | bool | `notify.quiet` | int | 0 / 1 | false |
| 靜音 start | minute of day | `notify.quietStart` | int | 0–1439 | 1320 (22:00) |
| 靜音 end | minute of day | `notify.quietEnd` | int | 0–1439 | 420 (07:00) |
| 分區警特報 per saved place | set of `areaKey` that are **on** | `notify.warningAreas` | JSON string array (same as `place.saved`) | array of non-empty strings, no duplicates | `[]` (every place off) |

- Defaults are all off, so a fresh install never implies that alerts are active (contract: copy must not claim delivery).
- The per-place toggles and 降雨提醒 keep their stored values while the master switch is off. The master switch is a gate, not a reset. The UI disables the dependent rows while it is off.
- Bools are stored as int 0/1, the same as `RadarRepeat` (`radar_provider.dart:115-128`), so all scalar notification values reuse one generic int-setting class (§3.1).
- **Pruning:** `warningAreasProvider` watches `savedPlacesProvider`. Its value is the stored set ∩ the saved places' area keys. When `build()` finds stored keys with no saved place, it rewrites the stored set without them. Because of the watch, a removal triggers this immediately while the provider is alive. The settings page must watch `warningAreasProvider` at the page root so it is alive whenever a place can be deleted. Known limit: a place deleted and re-added before the provider is ever built (only possible from the old 地點 screen) keeps its old value.

### 2.4 Quiet hours — pure function

```dart
/// Minutes in a day; valid minute-of-day values are 0 ..< minutesPerDay.
const minutesPerDay = 24 * 60;

/// Whether [at] (its local wall-clock hour:minute) falls in the quiet window
/// [startMinute, endMinute). The window crosses midnight when start > end.
/// start == end is an empty window (never quiet). No clock is read: the caller passes [at].
/// Throws ArgumentError when a minute is outside 0..1439.
bool isQuietAt({required bool enabled, required int startMinute, required int endMinute, required DateTime at});
```
Contract (m = `at.hour * 60 + at.minute`): `!enabled` → false; `start == end` → false; `start < end` → `start <= m && m < end`; `start > end` → `m >= start || m < end`. Seconds are ignored, and the end minute is exclusive. Frontend converts `TimeOfDay` ↔ minute with `h * 60 + m` / `TimeOfDay(hour: v ~/ 60, minute: v % 60)`.
No clock provider is added: nothing evaluates quiet hours against "now" this round. A future delivery feature injects its clock and calls this function.

## 3. Storage layer and error states

### 3.1 One generic stored-int setting (refactor RadarSetting, no second copy)

New `lib/core/storage/stored_setting.dart`:
- `sharedPreferencesProvider` **moves here** from `place_provider.dart:85-88`, with the same name and body. `place_provider.dart` and `radar_provider.dart` import it. (The API key plan imports it from here too.)
- `Duration? noRetry(int retryCount, Object error) => null;` replaces the two private copies (`place_provider.dart:83`, `radar_provider.dart:32`).
- `class StoredSettingException implements Exception { final String key; final String message; }` replaces `StoredRadarSettingException` (`radar_provider.dart:22-29`). Messages stay the same: `儲存資料損毀：期望 $expected，實際「$raw」` / `寫入失敗：期望 true，實際 false`.
- `abstract class IntSetting<T> extends AsyncNotifier<T>` is the body of `RadarSetting` (`radar_provider.dart:43-79`) with `String get key` made abstract: `defaultValue`, `expected`, `fromStored(int)`, `toStored(T)`, `build()`, `set(T)`.
- `RadarSetting<T> extends IntSetting<T>` keeps only `group`, `name` and `key => 'radar.${group.name}.$name'`. Radar behaviour is unchanged.

PlaceStore throws the same `StoredSettingException` as scalar settings. The UI tells place errors from setting errors by which provider failed (`savedPlacesProvider` vs `warningAreasProvider`), not by exception type.

### 3.2 Error states (all recoverable by overwrite)

| Provider | Error state | Cause | Recovery |
|---|---|---|---|
| `currentPlaceProvider` | `AsyncError(StoredSettingException(key))`, key ∈ `place.current`, `place.gps` | corrupt stored value | `select` / `useGps` / `stopAutoLocate` |
| `savedPlacesProvider` | `AsyncError(StoredSettingException('place.saved'))` | corrupt array | `SavedPlacesNotifier.clear()` overwrites with `[]` (lead decision; UI offers it only in this error state) |
| `notifyToggleProvider(t)`, `quietMinuteProvider(e)` | `AsyncError(StoredSettingException(key))` | wrong type or out of range | `set(value)` |
| `warningAreasProvider` | `AsyncError(StoredSettingException('notify.warningAreas'))` | not JSON / not an array of unique non-empty strings | `WarningAreas.reset()` overwrites with `[]` (works with zero saved places); `setPlace(...)` also overwrites the whole set |
| `warningAreasProvider` | `AsyncError(StoredSettingException('place.saved'))` | saved places corrupt (watched dependency) | fix saved places |
| any setter | `AsyncError(... '寫入失敗 …')` | `prefs.set*` returned false | set again |

Rules: `prefs.get(key)` only, never typed getters. Parse happens once in `build()`. No silent default for a present but corrupt value. Every provider uses `retry: noRetry`.

## 4. Provider API (frontend calls these)

```dart
// lib/features/location/place_provider.dart (existing, changed)
final currentPlaceProvider = AsyncNotifierProvider<CurrentPlaceNotifier, CurrentPlace>(...);
class CurrentPlaceNotifier {
  Future<void> select(Place place);   // manual place; auto-locate off
  Future<void> useGps();               // auto-locate on + (re)locate
  Future<void> stopAutoLocate();       // auto-locate off; keeps a located place as manual
}
sealed class CurrentPlace { bool get autoLocate; }
enum NoPlaceKind { firstRun, autoLocateOff, locationFailed }
final class NoPlace { NoPlaceKind kind; bool get firstRun; LocationFailure reason; String cause; }
final savedPlacesProvider = AsyncNotifierProvider<SavedPlacesNotifier, List<Place>>(...);
class SavedPlacesNotifier { Future<void> save(Place p); Future<void> remove(Place p); Future<void> clear(); } // de-duplicate by areaKey; clear() writes [] (recovery from a corrupt list)
final townsProvider = FutureProvider.family<Result<List<Place>>, String>(...);           // search source, unchanged

// lib/features/settings/notification_settings.dart (new)
enum NotifyToggle { master, rain, quiet }          // keys notify.master / notify.rain / notify.quiet
enum QuietEdge { start, end }                       // keys notify.quietStart / notify.quietEnd
final notifyToggleProvider = AsyncNotifierProvider.family<NotifyToggleSetting, bool, NotifyToggle>(..., retry: noRetry);
final quietMinuteProvider  = AsyncNotifierProvider.family<QuietMinuteSetting, int, QuietEdge>(..., retry: noRetry);
// both are IntSetting subclasses: ref.read(notifyToggleProvider(NotifyToggle.rain).notifier).set(true)

final warningAreasProvider = AsyncNotifierProvider<WarningAreas, Set<String>>(WarningAreas.new, retry: noRetry);
class WarningAreas extends AsyncNotifier<Set<String>> {
  Future<void> setPlace(Place place, bool on);   // ArgumentError if place is not saved
}
// UI reads: ref.watch(warningAreasProvider).value?.contains(place.areaKey)

bool isQuietAt({required bool enabled, required int startMinute, required int endMinute, required DateTime at});
```
`WarningAreas.setPlace` follows `RadarSetting.set` (`radar_provider.dart:66-79`): it shows the new value at once, then writes, and a failed write becomes the state. On a corrupt current state it writes `{place.areaKey}` or `{}`.

## 5. Work packages (disjoint files; run in order: package 2 compiles against package 1)

### Package 1 — storage core + place settings (sonnet)
Owns: `lib/core/storage/stored_setting.dart` (new), `lib/features/radar/radar_provider.dart`, `lib/features/location/place_provider.dart`, `lib/data/models/place.dart`, `test/unit/place_state_test.dart`, `test/unit/radar_settings_test.dart` (only the exception type rename, if referenced).
Does: §3.1 extraction; §2.1 auto-locate (`stopAutoLocate`, `select` writes gps=false, strict `place.gps` parse, `NoPlaceKind`, `autoLocate` getter); §2.2 `areaKey` + de-duplicate/remove by area; `SavedPlacesNotifier.clear()`.
Must not touch: any screen file (no caller changes are needed: `useGps`, `select` and `firstRun` keep their signatures).
Acceptance:
1. `flutter analyze` clean.
2. `grep -rn "Duration? _noRetry\|StoredRadarSettingException\|getBool(" lib` → no output.
3. `sharedPreferencesProvider` is defined only in `lib/core/storage/stored_setting.dart` (`grep -rn "final sharedPreferencesProvider" lib` → 1 line).
4. `flutter test test/unit/place_state_test.dart test/unit/radar_settings_test.dart test/unit/location_timeout_test.dart test/unit/weather_provider_test.dart` green. The last two are existing users of `PlaceStore.gpsKey` and act as a regression check.
5. These tests are among the green ones in item 4: (a) `stopAutoLocate()` after a GPS fix keeps the same place selected as manual; (b) `clear()` recovers a corrupt `place.saved` to `[]`. The `NoPlace.firstRun` getter has a doc comment saying it is temporary and the frontend package removes it.
Tests to add (place_state_test.dart, each ≤1 s, mocked LocationService, `SharedPreferences.setMockInitialValues`):
- `place.gps=false`, no manual place → `NoPlace` kind `autoLocateOff`, `verifyNever(getCurrentLocation)`; survives a new container.
- `place.gps='yes'` → `AsyncError(StoredSettingException(key: 'place.gps'))`; `select()` recovers, and a new container reads the manual place.
- `stopAutoLocate()` after a GPS fix → `PlaceSelected(manual)` with the same place, `autoLocate` false, no further location call in a new container.
- `select()` after `useGps()` → stored `place.gps == false`.
- saving the same area with different coordinates keeps one entry.
- `place.saved='{'` → `AsyncError(StoredSettingException(key: 'place.saved'))`; `clear()` → `AsyncData([])`, and a new container reads `[]`.

### Package 2 — notification settings (sonnet; starts after package 1 is committed)
Owns: `lib/features/settings/notification_settings.dart` (new), `test/unit/notification_settings_test.dart` (new).
Does: §2.3, §2.4 and the §4 notification API on top of `IntSetting`, `noRetry`, `StoredSettingException`, `Place.areaKey`, `savedPlacesProvider`.
Must not touch: any package 1 file, any screen.
Acceptance:
1. `flutter analyze` clean.
2. `flutter test test/unit/notification_settings_test.dart` green, each test ≤1 s.
3. No `DateTime.now` in `notification_settings.dart` (`grep -c "DateTime.now" lib/features/settings/notification_settings.dart` → 0).
Tests (hermetic, no real clock: `at` values are fixed `DateTime(2026, 1, 1, h, m)`):
- fresh install → all defaults (§2.3 table).
- each setting set → survives a new container.
- corrupt values → `AsyncError(StoredSettingException(key))`, and `set` recovers. Cases: `notify.master=2`, `notify.quietStart=1440`, `notify.quietEnd='x'`, `notify.warningAreas='{'`, `notify.warningAreas='["a","a"]'`, `notify.warningAreas='[""]'`.
- warning areas: toggle on for a saved place → contains `areaKey`; remove the place from saved places → the key is gone from the value and the store; re-add → off; `setPlace` for an unsaved place → `ArgumentError`.
- `isQuietAt` table: disabled → false; 22:00–07:00 at 21:59 false, 22:00 true, 03:00 true, 06:59 true, 07:00 false; 09:00–17:00 at 08:59 false, 09:00 true, 16:59 true, 17:00 false; 08:00–08:00 → false at 08:00 and 20:00; minute 1440 → ArgumentError.

## 6. Coordination with the API key plan
Shared contract with architect-key-opus: `sharedPreferencesProvider`, `noRetry` and `StoredSettingException` live in `lib/core/storage/stored_setting.dart`, which package 1 owns. The key plan imports these and does not edit that file. Key prefixes do not overlap (`place.*`, `notify.*`, `radar.*` here). The new directory `lib/features/settings/` is shared; this plan claims only `notification_settings.dart` in it.
API key plan files (from architect-key-opus) are `lib/core/api/*`, `lib/core/widgets/api_key_notice.dart`, the repositories, and the weather and hazard screens. None of them overlaps with this plan. The key package must land after package 1, because it imports `sharedPreferencesProvider` from its new path. Without a key, `townsProvider` (the source for the 地點設定 search) returns `Failure` with `apiKeyIssue=missing`. The 地點設定 card renders that Failure, and no backend change is needed for it.

## 7. Decisions (team lead)
1. Turning auto-locate off while a GPS place is shown keeps that place as the selected (manual) place.
2. A corrupt saved-places list is recovered by `SavedPlacesNotifier.clear()`, which overwrites it with `[]`. The UI offers this only from the corrupt-list error state.
3. The `NoPlace.firstRun` getter is temporary; the frontend package removes it.
