# API key (token 設定) — backend/data architecture

Scope: the CWA Open Data key now comes only from in-app input. The compile-time `--dart-define=CWA_API_KEY` path is deleted. A missing key or a rejected key is a typed state that data pages render. Spec: `docs/logs/settings-tab-contract.md`.

## 1. Facts verified in code and environment

| Fact | Evidence |
|---|---|
| The compile-time key is read in one place | `lib/core/constants/app_constants.dart:18-24` (`cwaApiKey`, `hasApiKey`) |
| Datastore requests send the key as a header, but only through the default `dioProvider` | `lib/core/api/dio_client.dart:19,34-36` |
| fileapi requests put the key in the query string | `app_constants.dart:91-96` (`radarApiQueryParams` / `radarApiUrl`), used only at `lib/data/repositories/hazard_repository.dart:129` |
| HazardRepository receives the key as a constructor value and short-circuits when it is empty | `hazard_repository.dart:26,32,40,45,55,87,127` |
| WeatherRepository has **no** missing-key check. An empty key goes out as `Authorization: ''` and the server returns 401 | `weather_repository.dart:78-80,272-310`. The inventory line `docs/design/preflight/page-inventory.md:14` ("weather_repository.dart:98") is stale |
| **Radar does not use the CWA key.** It loads website JS lists and images from `www.cwa.gov.tw` through `fileApiDioProvider` | `lib/data/radar/radar_frame_list.dart:17,27`, `lib/features/radar/radar_provider.dart:158-177` |
| GPS place lookup and manual town search call CWA, so they need the key | `weather_repository.dart:160,182` (`getTowns`, `nearestTown` on O-A0001-001), consumed at `lib/core/location/location_service.dart:116-121` and `lib/features/location/place_provider.dart:229-237` |
| No `ApiException` type exists. Errors are carried by `sealed class Result` / `final class Failure(message, statusCode, dataset, location)` | `weather_repository.dart:16-72`. Hazard imports these types at `hazard_repository.dart:9` |
| Invalid key response: HTTP 401, body `401 Forbidden: Authorization key is not correct.` This is the same for datastore with a bad key, with no key, with garbage, and for fileapi | live probe 2026-11-15 with the dummy key `CWA-00000000-…` (no real key used) |
| Key format: `CWA-` + uppercase UUID (8-4-4-4-12 hex), 40 characters | The real key in `token.txt` (gitignored, `.gitignore:49`) matches `^CWA-[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$`. Only the match result was printed. Evidence base: 1 sample |
| Versions | flutter_riverpod 3.3.2, shared_preferences 2.5.5, dio 5.9.2 (`pubspec.lock`) |

## 2. Storage: shared_preferences (already installed)

Storage key `cwa.apiKey`, a String. It is stored trimmed and only after it passes the format check.

Why not `flutter_secure_storage`: its current version is 11.2.0 (pub.dev, published 2026-09-16), and it supports all six platforms. Its costs here are concrete:
- **macOS:** it needs the `keychain-access-groups` entitlement, which needs a provisioning profile. On a free developer account the built app launches only on the Mac that built it. The documented workaround is a `Platform.isMacOS` branch (`MacOsOptions(usesDataProtectionKeychain: false)`), which is a platform fork that the project rules forbid.
- **Linux:** the build needs `libsecret-1-dev` in the OrbStack build image, and the runtime needs a keyring daemon.
- It adds a native plugin to every platform build.

Threat model: the key is a free, rate-limited open-data token. Until now it was compiled into the binary as a constant, which anyone holding a build can extract. A sandboxed preferences file is strictly better than that and matches every other setting. **Recommendation: shared_preferences.** The user can choose otherwise (see §8).

## 3. Value type and validation (boundary parse)

New file `lib/core/api/api_key.dart`:

```dart
/// A CWA Open Data key that passed the format check. The only way to build one is [parse].
extension type const CwaApiKey._(String value) {
  static final _format = RegExp(r'^CWA-[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$');

  /// Trims [input]; throws FormatException('expected CWA-XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX (uppercase hex), got <len> chars') otherwise.
  /// The message gives the length, never the input (do not echo secrets into logs).
  static CwaApiKey parse(String input);
}

// Corrupt stored key or failed write: reuse StoredSettingException(key, message) from lib/core/storage/stored_setting.dart
// (preferences plan, arch-preferences.md:100). No key-specific exception type.
```

There is no case folding. Real keys are uppercase, and the server's case sensitivity is unverified, so the app does not rewrite input.

## 4. Provider API (Riverpod 3, same pattern as `RadarSetting`, radar_provider.dart:36-78)

```dart
/// Stored key: null = 未設定. A corrupt stored value = AsyncError(StoredSettingException); save()/clear() recover.
class CwaApiKeyNotifier extends AsyncNotifier<CwaApiKey?> {
  static const storageKey = 'cwa.apiKey';
  @override Future<CwaApiKey?> build();          // raw prefs.get(storageKey) (never getString: wrong type throws TypeError, shared_preferences 2.5.5 legacy.dart:117); non-String or bad format → StoredSettingException
  Future<void> save(CwaApiKey key);              // setString; false → AsyncError(StoredSettingException '寫入失敗：期望 true，實際 false')
  Future<void> clear();                          // remove; false → same error shape
}
final cwaApiKeyProvider = AsyncNotifierProvider<CwaApiKeyNotifier, CwaApiKey?>(CwaApiKeyNotifier.new, retry: noRetry);
// sharedPreferencesProvider, noRetry and StoredSettingException are imported from lib/core/storage/stored_setting.dart. That file is owned by the
// preferences plan (arch for place/notification settings) and moves sharedPreferencesProvider there from place_provider.dart:85.
// The key is a String, so this does not use the IntSetting<T> base; it uses the same conventions by hand.

/// Settings-card status of the *stored* key.
sealed class ApiKeyStatus {}
final class ApiKeyNotSet extends ApiKeyStatus {}                 // 未設定
final class ApiKeyVerifying extends ApiKeyStatus {}              // 驗證中
final class ApiKeyValid extends ApiKeyStatus { final DateTime checkedAt; }   // 有效
final class ApiKeyInvalid extends ApiKeyStatus { final ApiKeyIssue issue; final String reason; } // 無效 + reason
final class ApiKeyUnchecked extends ApiKeyStatus {}              // saved, not verified yet in this run

class ApiKeyStatusNotifier extends Notifier<ApiKeyStatus> {
  @override ApiKeyStatus build();   // watches cwaApiKeyProvider: null → NotSet, key → Unchecked, AsyncError → Invalid(unreadable)
  Future<void> verify();            // Verifying → one GET O-A0003-001 limit=1 through dioProvider → Valid / Invalid
}
final apiKeyStatusProvider = NotifierProvider<ApiKeyStatusNotifier, ApiKeyStatus>(ApiKeyStatusNotifier.new);
```

The verify result maps as follows:
- 200 with `success == "true"` → Valid.
- 401 or 403 → Invalid(`rejected`, "金鑰被 CWA 拒絕（HTTP 401）").
- A connection or timeout error → Invalid(`unreachable`, "無法連線 CWA，金鑰未驗證").
- Any other status or body → Invalid(`unexpected`, "期望 HTTP 200 + success \"true\"，實際 …").

The UI may label `unreachable` as 「無法驗證」 rather than 「無效」. The designer decides the copy.

A verify result that arrives after the key changed is dropped. The check is `ref.mounted` / generation, the same way `buildRef.mounted` works at weather_provider.dart:74. `ApiKeyUnchecked` exists because the brief's four states do not cover "saved but not verified yet in this run". The status is not persisted. The settings card may call `verify()` right after `save()`.

### How dio and the repositories get the key (invalidation)

`dioProvider` (dio_client.dart:10) gets these changes:
- It drops the `Authorization` header from `BaseOptions` and drops the `AppConstants` key read.
- In its body: `final key = ref.watch(cwaApiKeyProvider.future);`. Watching `.future` rebuilds `dioProvider` when the key changes after the first load. The first load completes the pending future without a rebuild, per `riverpod/lib/src/core/element.dart` onData (completer path), so startup should not fetch twice. This is read from the source, not run. Two WP-A tests prove the runtime behaviour: the invalidation test proves the rebuild after `save`, and a startup test asserts that the fake adapter's request count equals one fetch.
- One interceptor, `onRequest: (options, handler) async { … }`:
  - `await key`. If it throws `StoredSettingException` → `handler.reject(DioException(requestOptions: options, error: CwaApiKeyException(ApiKeyIssue.unreadable, …)))`.
  - `null` → reject with `CwaApiKeyException(ApiKeyIssue.missing, …)`.
  - Otherwise `options.queryParameters['Authorization'] = key.value; handler.next(options)`.

The key goes in the **query** for both datastore and fileapi. Both forms are documented and in use (`docs/logs/2026-11-14/cwa-datasets-conclusion.md:12-13`). The query string does not follow the fileapi 302 redirect to S3, while a header could follow it.

After this change, every CWA request goes through `dioProvider`. HazardRepository's fileapi calls use it with an absolute URL; dio ignores `baseUrl` for absolute URLs, and `maxRedirects` is already 5 (dio_client.dart:16-17). `fileApiDioProvider` stays keyless and is used only by radar (website URLs). That way the key never reaches `www.cwa.gov.tw`, and radar keeps working without a key.

Chain of invalidation: key save/clear → `dioProvider` rebuild → `weatherRepositoryProvider` (weather_repository.dart:78) and `hazardRepositoryProvider` (hazard_repository.dart:28) rebuild → every `FutureProvider` that watches them refetches (hazard_provider.dart:11-32, place_provider.dart:229-237).

**Gap to fix:** `WeatherNotifier.build` (weather_provider.dart:46-55) only `ref.read`s the repository inside `_load` (:66), so a key change would not reload the home page. Add `ref.watch(weatherRepositoryProvider);` at the top of `build`.

## 5. Error type carried to every data page

In `weather_repository.dart` (where `Result` lives):

```dart
enum ApiKeyIssue { missing, rejected, unreadable }

/// Interceptor rejection payload (DioException.error).
class CwaApiKeyException implements Exception { final ApiKeyIssue issue; final String message; }

final class Failure<T> extends Result<T> {
  …existing fields…
  /// Non-null = the request failed because of the key; pages show 「請到「設定」輸入 / 更新 token」.
  final ApiKeyIssue? apiKeyIssue;
}

/// The one DioException → Failure mapping for both repositories.
Failure<T> failureFromDio<T>(DioException e, {required String dataset, String? location});
```

`failureFromDio` sets these values:
- `e.error is CwaApiKeyException` → `apiKeyIssue = e.error.issue`.
- Status 401 or 403 → `apiKeyIssue = rejected`.
- Anything else → null.

The message keeps the dataset and location, as today.

`failureFromDio` replaces three things:
- `WeatherRepository._handleDioError` / `_formatDioError` (weather_repository.dart:301-323)
- `HazardRepository._dioFailure` (hazard_repository.dart:174-182)
- `isApiError` (dio_client.dart:63-66)

The three `apiKey.isEmpty` short-circuits in hazard are deleted, because the interceptor covers every request. `getRainForecast`'s re-wrap (hazard_repository.dart:117) must carry `apiKeyIssue` through. It uses `fold`, which drops extra fields, so switch on `Failure` instead.

Page rendering. Pages need no new provider. Each existing `Failure(:final message)` arm (listed in WP-B) gets a preceding arm `Failure(apiKeyIssue: final issue?)` that renders the shared `ApiKeyNotice`. A missing key is always explicit, never an empty page.

Location flows: GPS `nearestTown` failure becomes `LocationException(addressUnresolved, …message…)` (location_service.dart:116-121). The message already contains the key text. Rendering a dedicated key state there belongs to the place/settings plan; this plan does not edit location files.

## 6. Removal list

| Location | Action |
|---|---|
| `lib/core/constants/app_constants.dart:1-4` | doc comment about `--dart-define`: rewrite (key comes from 設定) |
| `app_constants.dart:16-24` | delete `cwaApiKey`, `hasApiKey` |
| `app_constants.dart:90-96` | replace `radarApiQueryParams(apiKey)` / `radarApiUrl(id, apiKey)` with keyless `fileApiUrl(String datasetId) => '$cwaFileApiBaseUrl$datasetId?downloadType=WEB&format=JSON'` (it was never used by radar) |
| `lib/core/api/dio_client.dart:3,19,28-39,62-66` | key header, interceptor and `isApiError` replaced as in §4 and §5 |
| `lib/data/repositories/hazard_repository.dart:7,26,28-34,38-45,55,87,127-129,174-182` | drop `_missingApiKeyMessage`, `apiKey` field and constructor parameter, `_fileApiDio`; use `dioProvider` + `fileApiUrl`; use `failureFromDio` |
| `lib/data/repositories/weather_repository.dart:301-323` | replaced by `failureFromDio` |
| `.env.example:3,5` | delete the file (its only content is the dart-define instruction) |
| `docs/design/preflight/page-inventory.md:14` | rewrite: key from 設定 tab, missing → `Failure.apiKeyIssue` |
| `docs/design/team-a/home.html:973` | demo copy "開發版未帶入 CWA_API_KEY…" → "尚未設定 token，請到「設定」輸入". Owner: the frontend implementer of the chosen design. Listed here, not owned here |
| `test/unit/hazard_repository_test.dart:35-44` | `_repo` loses `apiKey` and the second Dio |
| historical logs (`docs/logs/2026-06-11/*`, `docs/logs/2026-11-1[45]/*handover*/*contract*`, `artifacts/api_verification_2026-06-11.md`, `docs/SOP/task.md:126`, `docs/SOP/memory.md:122`) | **leave unchanged**. Dated records of what was run. New verify commands are plain `flutter build macos` |

Mechanical check after both packages: `grep -rn "CWA_API_KEY\|fromEnvironment\|cwaApiKey\|hasApiKey\|radarApiUrl\|isApiError" lib test .env.example` → no output.

## 7. Work packages (disjoint files)

### WP-A — key storage, plumbing, error type (backend)
Start order: WP-A's `api_key.dart` imports `lib/core/storage/stored_setting.dart`, which the preferences plan creates. Start WP-A after that file is committed. Alternatively, WP-A can do everything except `api_key.dart` first: dio, repositories and the `Failure` field.
Owns:
- NEW `lib/core/api/api_key.dart`, NEW `test/unit/api_key_test.dart`
- `lib/core/api/dio_client.dart`, `lib/core/constants/app_constants.dart`
- `lib/data/repositories/weather_repository.dart`, `lib/data/repositories/hazard_repository.dart`
- `lib/features/weather/weather_provider.dart`
- `test/unit/hazard_repository_test.dart`, `test/support/fake_cwa_adapter.dart` (only if a helper is needed)
- `.env.example` (delete), `docs/design/preflight/page-inventory.md`

Acceptance:
1. `flutter analyze` → No issues.
2. `flutter test test/unit` green. Each new test ≤1 s, no network (Dio uses a fake `HttpClientAdapter`; prefs use `SharedPreferences.setMockInitialValues`).
3. The §6 grep gives no output.
4. `flutter build macos` (no `--dart-define`) RC=0. Run by the gate runner.

Tests to add (only these), in `api_key_test.dart`:
- parse: the real-format sample accepted; surrounding whitespace trimmed; lowercase, `CWA-`+35/37 chars, missing prefix and empty string each rejected. The message does not contain the input.
- persist: `save` → new container reads the same key; `clear` → null.
- corrupt stored value: `{'cwa.apiKey': 'abc'}` and `{'cwa.apiKey': 42}` → `AsyncError<StoredSettingException>` naming `cwa.apiKey`; `save` recovers it.
- interceptor: no key → repository returns `Failure.apiKeyIssue == missing` and the fake adapter received **zero** requests. Stored key → request query has `Authorization=<key>`. Adapter 401 → `apiKeyIssue == rejected`.
- invalidation: `save` then reading `weatherRepositoryProvider` gives a new instance (proves pages refetch). Startup with a stored key: one provider read sends exactly one request (no double fetch from the first key load).
- verify state: fake 200 + success → Valid; 401 → Invalid(rejected); connection error → Invalid(unreachable); no key → NotSet without a request.

Hazard test: existing cases stay green after the `_repo` change. Add one case: fileapi URL has no key inside, and the key arrives via the interceptor query.

### WP-B — data pages render the key state (frontend-light; independent of the settings design pick)
Owns:
- NEW `lib/core/widgets/api_key_notice.dart`. A thin wrapper over `AppCard.error`-style layout (app_card.dart:45): title 「需要 CWA token」, text per issue, button 「前往設定」 → `ref.read(appTabProvider.notifier).select(AppTab.location)` (app_shell.dart:13-24; whoever renames the tab updates this one call site).
- `lib/features/weather/weather_screen.dart` (:171)
- `lib/features/weather/widgets/hero_card.dart` (:29), `sun_card.dart` (:34), `forecast_72h_card.dart` (:40), `weekly_card.dart` (:40)
- `lib/features/hazard/warnings_screen.dart` (:82), `lib/features/hazard/rainfall_screen.dart` (:271)

Depends on WP-A's `Failure.apiKeyIssue` (one field). It starts after WP-A has committed `weather_repository.dart`. Radar: no change (no key used).

Acceptance:
1. `flutter analyze` → No issues.
2. `grep -n "apiKeyIssue" <each owned page file>` matches once per listed `Failure` arm.
3. No new committed tests. Per project policy there are no UI tests. The logic that decides "key problem" is `failureFromDio`, which is already covered by WP-A tests.

Not owned by either package: `lib/core/storage/stored_setting.dart`, `lib/features/settings/notification_settings.dart`, `lib/data/models/place.dart`, `lib/features/location/*`, `lib/core/location/*`, `lib/app_shell.dart`, `lib/features/radar/*`, `docs/design/team-a/home.html` (place/settings plan and frontend implementer).

## 8. Open questions for the user
1. **Storage:** app preferences file (recommended: no new package, identical on all platforms, a big improvement over the old compiled-in key) vs. OS keychain via `flutter_secure_storage` 11.2.0. The keychain is stronger at rest, but it needs a macOS signing entitlement (or a macOS-only code branch) and libsecret on Linux. The default unless told otherwise is the preferences file.
