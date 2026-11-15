# Architecture plan — merged now card (observation + sun arc)

Contract: `docs/logs/home-page-contract.md` (requirements 1–3). Brief: `docs/design/home/brief.md`. Data map: `docs/design/home/code-data.md`.

## 1. Decision summary

- The merged card replaces `HeroCard` (`lib/features/weather/widgets/hero_card.dart`) and `SunCard` (`lib/features/weather/widgets/sun_card.dart`). Both files and their logic (`SunPosition`, `sunPosition`, `sunNowLine`, `home_logic.dart:113-155`) are deleted, with their tests (`test/unit/home_logic_test.dart:33-46`). No parallel path stays.
- All sun times come from CWA `A-B0062-001`. Only the **current solar elevation** is computed (NOAA general solar position equations, pure Dart, no new dependency).
- The sun dataset grows from `[今天, 明天]` to `[昨天, 今天, 明天]`, so the night arc fraction before sunrise uses the real previous sunset (no approximation).
- One pure builder `nowCard(WeatherState, now)` returns a sealed state. The screen calls it with the injected clock. No new provider.
- Missing or stale sun data is an explicit failure shown in the card. No default times, no hidden arc.

## 2. Compute vs API

| Value | Source | Field / function | Notes |
|---|---|---|---|
| 日出 | CWA `A-B0062-001` | `SunRiseTime` → `SunDay.sunrise` (`weather_repository.dart:759`) | minute resolution, county level |
| 日落 | CWA | `SunSetTime` → `SunDay.sunset` (:760) | |
| 曙光 (civil dawn) | CWA | `BeginCivilTwilightTime` → `SunDay.civilDawn` (:758) | |
| 暮光 (civil dusk) | CWA | `EndCivilTwilightTime` → `SunDay.civilDusk` (:761) | |
| 過中天 time | CWA | `SunTransitTime` → `SunDay.transit` (:762) | arc mark |
| 過中天 elevation | CWA | `SunTransitAlt` "47S" → `transitAltitudeDegrees` (:748-752) | kept for the transit mark label / semantics |
| **Current elevation (仰角)** | **Computed** | `solarElevationDegrees(lat, lon, instant)` (new) | from `WeatherState.location` (`Place.latitude/longitude`, `place.dart:8-9`) and the injected clock |
| Phase (before sunrise / daytime / after sunset) | Computed | `sunNow(...)` (new) | from CWA times + now |
| Arc fraction (day and night) | Computed | `sunNow(...)` | time-linear, see §4.2 |
| Countdown in note | Computed | `sunNow(...)` | to next sunrise / sunset |
| 體感 / 降雨機率 / 天氣建議 | CWA `F-D0047-*` slot covering now | `currentSlot` (`home_logic.dart:164-169`) | unchanged |
| 溫度 / 濕度 / 風 / 天氣現象 / 高低溫 | CWA `O-A0003-001` | `CurrentWeather` (`weather_models.dart:6-53`) | unchanged |

No CWA dataset in use gives elevation at an arbitrary moment (`code-data.md` §1 item 1). `SunRiseAZ`/`SunSetAZ` exist in the payload but are not needed.

## 3. Data model

### 3.1 Repository (changed)

`WeatherRepository.getSunTimes(city, now)` (`weather_repository.dart:185-200`) returns `Result<List<SunDay>>` for **three consecutive Taiwan dates: yesterday, today, tomorrow** (`timeFrom = today-1`, `timeTo = today+2`, exclusive). `_sunDayCount` (:361) becomes 3 and the start offset becomes −1. A missing date stays a `Failure` (:737). `SunDay` (`weather_models.dart:81-106`) is unchanged.

`WeatherState.sun` (`weather_provider.dart:16`) doc becomes `[昨天, 今天, 明天]`. Nothing else in `WeatherState` changes.

### 3.2 Solar elevation (new, pure)

File: `lib/features/weather/solar_elevation.dart`

```dart
/// Apparent solar elevation in degrees at [instant] for the point
/// ([latitude], [longitude]) (north and east positive). NOAA general solar
/// position equations plus Sæmundsson refraction above −1°.
/// Negative below the horizon.
double solarElevationDegrees({required double latitude, required double longitude, required DateTime instant});
```

### 3.3 Now-card view model (new, pure)

File: `lib/features/weather/widgets/home_logic.dart` (replaces the deleted sun section).

```dart
enum SunPhase { beforeSunrise, daytime, afterSunset }

/// Sun state at one instant, derived from three consecutive SunDays.
class SunNow {
  /// The SunDay of now's Taiwan calendar date: source of the 日出/日落/曙光/暮光 tiles and the 過中天 mark.
  final SunDay day;
  final SunPhase phase;
  /// Position on the current half of the arc, 0–1.
  /// daytime: sunrise → sunset of [day]; night: previous sunset → next sunrise.
  final double arcFraction;
  /// The sunrise or sunset the note counts to.
  final DateTime nextEvent;
  /// Rounded apparent elevation (negative at night), from solarElevationDegrees.
  final int elevationDegrees;
  /// Sun-status note, e.g. 「現在 21:40，已日落，距明天日出 8 小時 12 分」.
  String note(DateTime now);
}

/// Builds SunNow; Failure when [days] cannot cover [now] (stale data).
Result<SunNow> sunNow(List<SunDay> days, Place place, DateTime now);

sealed class NowCardState {}
final class NowCardLoading extends NowCardState {}
final class NowCardApiKey extends NowCardState { final ApiKeyIssue issue; }
final class NowCardFailed extends NowCardState { final String message; }      // observation failed
final class NowCardReady extends NowCardState {
  final CurrentWeather observation;
  final HourlyForecast? slot;      // null: 體感/降雨機率 tiles show 「—」, 天氣建議 note absent (current behavior, hero_card.dart:88,106,109)
  final Result<SunNow> sun;        // Failure: inline sun error block in the card
}

NowCardState nowCard(WeatherState state, DateTime now);
```

Note text patterns (designers may change wording, not structure):
- before sunrise: `現在 05:40，日出前，距日出 30 分`
- daytime: `現在 14:00，距日落 3 小時 7 分`
- after sunset: `現在 21:40，已日落，距明天日出 8 小時 12 分`

Durations reuse `durationText` (`home_logic.dart:54-59`); clock text reuses `clockText` (:23-26).

## 4. Algorithms

### 4.1 Current elevation — NOAA general solar position

Standard: NOAA Global Monitoring Laboratory, "General Solar Position Calculations" (`https://gml.noaa.gov/grad/solcalc/solareqns.PDF`), Fourier series after Spencer (1971). Inputs in UTC, so the time-zone term is 0.

```
N   = 366 if leap year else 365
γ   = 2π/N · (dayOfYear − 1 + (hourUTC − 12)/24)                       [rad]
eq  = 229.18 · (0.000075 + 0.001868 cosγ − 0.032077 sinγ − 0.014615 cos2γ − 0.040849 sin2γ)   [min]
δ   = 0.006918 − 0.399912 cosγ + 0.070257 sinγ − 0.006758 cos2γ + 0.000907 sin2γ − 0.002697 cos3γ + 0.00148 sin3γ   [rad]
tst = minutesOfDayUTC + eq + 4 · longitude                               [min]
ha  = tst/4 − 180                                                        [deg]
cos z = sin φ sin δ + cos φ cos δ cos ha                                 (φ = latitude)
e   = 90 − z                                                             [deg, geometric]
refraction (Sæmundsson, e > −1°): R = 1.02 / tan(e + 10.3/(e + 5.11)) arcmin; else R = 0
elevation = e + R/60
```

Clamp `cos z` to [−1, 1] before `acos` (float rounding at the poles); this is not a fallback, the value is mathematically in range.

Accuracy: the Spencer series has declination error ≤ ~0.0006 rad (0.035°) and equation-of-time error ≤ ~0.6 min (≤ 0.15° hour angle), so geometric elevation error is ≤ ~0.2°. The card shows whole degrees, so this is below display resolution. Refraction matters only near the horizon (0.57° at 0°); without it the card would show 「−1°」 at the CWA sunrise minute.

Prototype check (one-off, scratch, deleted) on Taipei (25.0375 N, 121.5637 E), 2026-11-14, against the CWA fixture `test/fixtures/cwa/A-B0062-001.json` (臺北市):

| Instant (TW) | CWA | Computed apparent |
|---|---|---|
| 11:38 transit | 47S | 47.03° |
| 06:10 sunrise | horizon | −0.06° |
| 17:07 sunset | horizon | −0.15° |
| 05:46 civil dawn | −6° by definition | −5.80° |

Known limit: CWA times are county-level (reference point not documented); elevation uses the town or GPS point. Inside one county the difference is below ~1°, so the transit label (CWA `47°`) and the computed elevation at transit can differ by 1°. The arc shows the computed value at the sun marker and the CWA value at the 過中天 mark only; they never claim to be the same number.

### 4.2 Phase, arc fraction, countdown

Input `days` = `[d0, d1, d2]`, consecutive. Let `i` = index of the SunDay whose `date` equals now's Taiwan date (`taiwanWall`, `home_logic.dart:12`).

1. No such `i` → `Failure('日出日落資料不含現在日期：期望 <now date>，實際 <d0.date>–<d2.date>，請重新整理', dataset: A-B0062-001)`.
2. `now < days[i].sunrise` → phase `beforeSunrise`; needs `days[i-1]` (else Failure as in 1). `arcFraction = (now − prev.sunset) / (day.sunrise − prev.sunset)`; `nextEvent = day.sunrise`.
3. `sunrise ≤ now < sunset` → `daytime`; `arcFraction = (now − sunrise) / (sunset − sunrise)`; `nextEvent = sunset`.
4. `now ≥ sunset` → `afterSunset`; needs `days[i+1]` (else Failure). `arcFraction = (now − sunset) / (next.sunrise − sunset)`; `nextEvent = next.sunrise`.

With a fetch at date D this covers every instant from D 00:00 to (D+1) before sunset, so a card left open past midnight keeps working and fails loudly one day later. Civil dawn/dusk marks keep the current daylight-relative placement (`sun_card.dart:184,219-222`, negative or >1 fractions); that is painter geometry, not model data.

### 4.3 Clock injection

- Single clock: `weatherClockProvider` (`weather_provider.dart:42`). The screen already reads it once per build (`weather_screen.dart:115`) and passes `now` down. `nowCard`, `sunNow` and `solarElevationDegrees` take `now`/`instant` as parameters; none calls `DateTime.now`.
- Tests pass fixed instants (`tw(...)` helper, `home_logic_test.dart:6`) and override `weatherClockProvider` for provider tests (existing pattern).
- Mechanical check for the implementer: `grep -rn "DateTime.now" lib/features/weather lib/data` returns only `weather_provider.dart:42`.
- Not changed: `now` updates only on rebuild (no minute tick). Today the same staleness exists in `SunCard`. See §8.

## 5. Error states (merged card)

Precedence top to bottom; first match wins.

| Condition | `NowCardState` | UI |
|---|---|---|
| `state.current == null` or `state.sun == null` | `NowCardLoading` | one `AppCard.loading(hero: true)` skeleton |
| `current` or `sun` is `Failure(apiKeyIssue: issue?)` | `NowCardApiKey(issue)` | `ApiKeyNotice` (same as `hero_card.dart:30`) |
| `current` is `Failure` | `NowCardFailed(message)` | `AppCard.error(title: '無法取得目前天氣', onRetry)` |
| `current` ok, `sun` is `Failure` | `NowCardReady(sun: Failure)` | observation, temperature, comfort tiles, 天氣建議 note shown; arc, 4 sun tiles and sun note replaced by one inline error block 「無法取得日出日落資料：<message>」 + 重試 |
| `current` ok, `sun` ok, `sunNow` → Failure (stale/out of range) | `NowCardReady(sun: Failure)` | same inline error block, message from §4.2 |
| `current` ok, forecast slot missing | `NowCardReady(slot: null)` | 體感 / 降雨機率 「—」, 天氣建議 note absent (unchanged; the forecast card shows its own error) |
| all ok | `NowCardReady` | full card; night when `phase != daytime` |

The page-level states (no place, location denied, page error) stay in `WeatherScreen` (`weather_provider.dart:50-56`). Sun times are never replaced by defaults; a sun failure never hides itself by dropping the arc silently.

## 6. Tests (core logic only, all < 1 s, hermetic, fixed instants)

| File | Test | Why kept |
|---|---|---|
| `test/unit/solar_elevation_test.dart` (new) | Taipei 2026-11-14 at CWA transit 11:38 → `round() == 47` (matches fixture `SunTransitAlt`) | core math vs authoritative data |
| same | at CWA sunrise 06:10 and sunset 17:07 → `abs() < 0.5` | refraction + horizon correctness |
| same | Taipei 2026-06-21 at local apparent noon → within 0.3° of `90 − |φ − 23.44|` | independent reference, other season |
| `test/unit/home_logic_test.dart` (replace :33-46) | `sunNow` daytime / before sunrise / after sunset: phase, `arcFraction` at a known instant, `nextEvent`, `note` text | core logic |
| same | `sunNow` with now's date not in the list, and before-sunrise on the first day → `Failure` naming expected and actual dates | data integrity (no silent default) |
| same | `nowCard`: observation ok + sun Failure → `NowCardReady` with sun Failure and observation kept | data integrity |
| `test/unit/weather_repository_test.dart` (update :228-262) | three dates `[昨天, 今天, 明天]`, `timeFrom = today−1`, `timeTo = today+2` | data path |
| `test/unit/weather_provider_test.dart` (update :92, :148) | `sun` has length 3 | data path |

No widget, painter or screenshot tests.

## 7. Work packages (disjoint file ownership)

| WP | Owner files | Depends on | Acceptance |
|---|---|---|---|
| WP-S1 solar math | new `lib/features/weather/solar_elevation.dart`, new `test/unit/solar_elevation_test.dart` | none | 3 tests in §6 green; `flutter analyze` clean |
| WP-S2 sun data, 3 days | `lib/data/repositories/weather_repository.dart` (`getSunTimes`, `_sunDayCount`), `lib/features/weather/weather_provider.dart` (doc of `sun`), `test/unit/weather_repository_test.dart`, `test/unit/weather_provider_test.dart`, `test/fixtures/cwa/A-B0062-001.json` | none | repo/provider tests green with 3 dates |
| WP-S3 view model | `lib/features/weather/widgets/home_logic.dart` (delete :113-155, add §3.3), `test/unit/home_logic_test.dart` | WP-S1 signature (frozen in §3.2); runs in parallel, compiles after WP-S1 lands | §6 home_logic tests green; old `sunPosition`/`sunNowLine` tests gone |
| WP-S4 card UI | new `lib/features/weather/widgets/now_card.dart`; delete `hero_card.dart`, `sun_card.dart`; `lib/features/weather/weather_screen.dart` (`_CardFlow` hero/sun slots, :144-149, :212-260) | WP-S3, chosen design version | `grep -rn "HeroCard\|SunCard\|sunNowLine\|sunPosition" lib test` empty; app builds; manual run shows day and night |

Fixture note for WP-S2: the recorded fixture has only `2026-11-14` and `2026-11-15`. It needs `2026-11-13`. Preferred: re-record the real `A-B0062-001` response for `timeFrom=2026-11-13&timeTo=2026-11-16` with a valid key. Hand-adding a day would put synthetic data in a "recorded" fixture; if no key is available, report BLOCKED to the lead.

`weather_screen.dart` is also touched by the forecast-order and warnings plans (other `arch-*.md`). The lead serializes WP-S4 with them; WP-S4 owns only the hero/sun slot change.

## 8. Open items for the lead

1. **Minute tick.** The note shows 「現在 21:40」 and goes stale while the app stays open (existing behavior: `ref.read` at `weather_screen.dart:115`, no timer). Fix if wanted: a minute tick derived from `weatherClockProvider` at screen level; the model in §3.3 does not change. Not in this plan without user approval.
2. **Night tiles.** After sunset the 日出/日落 tiles show today's (passed) times; the note gives the countdown to tomorrow's sunrise. Showing tomorrow's sunrise instead is a design choice; the model already exposes `nextEvent`.
3. **CWA reference point.** CWA does not document which point in a county the sun times use; the ≤1° label difference in §4.1 is accepted, not verified per county.
