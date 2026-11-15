# Home page data layer — code map

Paths relative to repo root. All claims verified in code (fixtures noted where used).

## Answers to the two explicit questions

1. **Solar elevation (仰角) — only ONE value per day is in the API: the elevation at solar noon.** `A-B0062-001` field `SunTransitAlt` (e.g. `"47S"`) is parsed into `SunDay.transitAltitudeDegrees` (int) + `transitSide` (N/S): `weather_repository.dart:748-752,763-764`, `weather_models.dart:91-94`. There is **no** elevation for the current moment, and no hourly/curve data in any dataset read (`_sunDay` reads only the 7 fields at `weather_repository.dart:754-765`). Current-time elevation must be **computed** client-side (no solar-position code exists in `lib/`; the arc painter only interpolates by time-fraction, `sun_card.dart:184-189`). The existing card only draws the noon elevation label `仰角 N°` at the transit point (`sun_card.dart:245`).
2. **Solar-noon time (過中天) — available from the API.** Field `SunTransitTime` → `SunDay.transit` (absolute DateTime): `weather_repository.dart:762`, `weather_models.dart:92`. Already displayed (`sun_card.dart:71`) and drawn on the arc (`sun_card.dart:231`).

## 1. WeatherState (`lib/features/weather/weather_provider.dart`)

| Field | Type | Line | Meaning |
|---|---|---|---|
| `location` | `Place?` | :10 | selected place |
| `current` | `Result<CurrentWeather>?` | :11 | observation |
| `hourly` | `Result<List<HourlyForecast>>?` | :12 | 72h forecast |
| `weekly` | `Result<List<DailyForecast>>?` | :13 | 7-day forecast |
| `sun` | `Result<List<SunDay>>?` | :16 | `[今天, 明天]` |
| `hourlyIssuedAt` | `Result<DateTime>?` | :19 | 72h dataset issue time |
| `fetchedAt` | `DateTime?` | :22 | load completion time (clock-injected) |
| `isLoading` | `bool` (default true) | :23, :36 | |
| `error` | `String?` | :26 | page-level only (no place / corrupt stored place) |

- Doc comment: four datasets succeed/fail independently, `null` = not loaded yet or no place (:7-8).
- Loading: `_load` runs 5 requests in parallel via record `.wait` (:67-73); result dropped if place changed (`buildRef.mounted`, :75).
- `Result<T>` = `Success(data)` | `Failure(message,statusCode,dataset,location,apiKeyIssue)`: `weather_repository.dart:16-74`.

## 2. Datasets and models

Base URL `https://opendata.cwa.gov.tw/api/v1/rest/datastore/` (`lib/core/constants/app_constants.dart:12-13`). Dataset IDs: `app_constants.dart:20,26,34-57`.

| Data | Dataset ID | Repo method | Query | Model |
|---|---|---|---|---|
| 即時觀測 | `O-A0003-001` (:20) | `getCurrentWeather` `weather_repository.dart:147-154` | `limit=1000` (:151, `app_constants.dart:29`); nearest station with AirTemperature, haversine (`:426-468`) | `CurrentWeather` `weather_models.dart:6-53` |
| 日出日沒/曙暮光/過中天 | `A-B0062-001` (:26) | `getSunTimes(city, now)` `:185-200` | `CountyName`, `timeFrom=today(TW)`, `timeTo=today+2` (:187-197) | `SunDay` `weather_models.dart:81-106` |
| 72h 預報 | per-county `threeDay`, e.g. 臺北市 `F-D0047-061` (`app_constants.dart:34,50`) | `getHourlyForecast` `:161-168` | `LocationName=<town>` (:309) | `HourlyForecast` `weather_models.dart:109-142` |
| 7日預報 | per-county `oneWeek`, e.g. 臺北市 `F-D0047-063` | `getWeeklyForecast` `:171-178` | same | `DailyForecast` `weather_models.dart:145-178` |
| 72h 發布時間 | threeDay dataset via **file API** `…/fileapi/v1/opendataapi/<id>` (`app_constants.dart:64-65`) | `getForecastIssueTime` `:260-285` | `Range: bytes=0-4095` (:275,:475), regex `IssueTime` (:519-530) | `DateTime` |

### CurrentWeather fields (`weather_models.dart:6-53`)
stationName, countyName, townName, distanceKm, observedAt, temperature (non-null, :20-21), humidity?, windSpeed?, windDirection? (`ObservedWind`: calm / variable / degrees, :56-75; parse `weather_repository.dart:532-549`), weather? (text), dailyHigh?, dailyLow? (`:460-467`). **No 體感溫度 and no 降雨機率 in observation** — those come from the forecast slot (`weather_screen.dart:146` passes `currentSlot(hourly.data, now)` to HeroCard; `home_logic.dart:164-169`).

### SunDay fields (`weather_models.dart:81-106`, parse `weather_repository.dart:754-765`)
| Model field | CWA field | Notes |
|---|---|---|
| `civilDawn` | `BeginCivilTwilightTime` | **civil twilight exists** (曙光始) |
| `sunrise` | `SunRiseTime` | |
| `sunset` | `SunSetTime` | |
| `civilDusk` | `EndCivilTwilightTime` | 暮光終 |
| `transit` | `SunTransitTime` | 過中天 |
| `transitAltitudeDegrees`/`transitSide` | `SunTransitAlt` e.g. `47S` | noon elevation only (regex `^(\d{1,2})([NS])$`, :748-752) |

Times are `"HH:mm"` strings → `DateTime.parse('${date}T$text:00+08:00')` (:713-719), minute resolution. Only civil twilight; no nautical/astronomical twilight, no moon data read. Sun dataset covers `[today, tomorrow]` only (`_sunDayCount = 2`, :361); a missing date = Failure (:737).

## 3. 72h vs 7-day forecast — same elements? same granularity?

**Different granularity, different element sets, partially overlapping elements; not the same level of information.**

72h (`F-D0047-061` pattern; parse `weather_repository.dart:625-650`; fixture `test/fixtures/cwa/F-D0047-061.json` is truncated to 4 slots, so span "未來3天" comes from the doc comment `weather_repository.dart:160` / `app_constants.dart:31-32`):
- Slot list is driven by the **天氣現象 slots, 3 h each** (`StartTime`/`EndTime` 3 h apart in fixture; iteration `for start in weather.keys`, :636). `forecastSlotLength = 3h` (`home_logic.dart:161`).
- Elements 溫度, 體感溫度, 相對濕度, 風速, 風向 in the dataset are **hourly** `DataTime` entries (fixture: 18:00, 19:00, 20:00, 21:00); the parser looks them up by the exact 3 h slot start (`temperature[start]` etc., :639-643), so only the value at each 3 h boundary is kept; hourly in-between values are discarded. If the boundary entry is missing → null (`test/unit/weather_repository_test.dart:115-135`, `hours[2].temperature` null).
- Element list consumed: 天氣現象 (text + code), 溫度, 體感溫度, 相對濕度, 風速, 風向 (Chinese text, e.g. 偏北風), 3小時降雨機率, 天氣預報綜合描述 (:627-634). Dataset also contains 露點溫度, 舒適度指數 (fixture) — not read.
- `HourlyForecast` fields: `weather_models.dart:109-142`.

7-day (`F-D0047-063` pattern; parse `weather_repository.dart:657-710`; fixture `test/fixtures/cwa/F-D0047-091.json` used as a stand-in for the weekly dataset, `test/unit/weather_provider_test.dart:78`):
- **12 h slots** (day 06–18 / night 18–06; `StartTime`+`EndTime` 12 h apart in fixture; comment :655-656, `_daySlotStartHour = 6` :364).
- Elements consumed: 最高溫度, 最低溫度, 最高體感溫度, 最低體感溫度, 平均相對濕度, 風速, 12小時降雨機率, 天氣現象 (:659-666). Not read: 平均溫度, 露點, 舒適度, 風向, 紫外線指數 (UV; fixture), 綜合描述.
- Aggregation to a TW calendar day: max/min temps = extreme over all slots touching that day (:681-688,:698-701); humidity/wind/pop/weather from the day slot starting 06:00 (fallback first slot when only night left, :692-695,:702-706). At most 7 days (`_weeklyDayCount`, :358,:690).
- `DailyForecast` fields: `weather_models.dart:145-178` (maxTemperature, minTemperature, max/min apparent, humidity, windSpeed, pop, weather, weatherCode). **No wind direction, no description, no per-slot (day/night) split exposed.**

Overlap: first ~3 days of the 7-day list cover the same dates as the 72h list. Common elements: 天氣現象, 風速, 降雨機率 (3 h vs 12 h), 溫度 (hourly-at-3h point vs daily max/min), 體感, 相對濕度 (point vs 12 h average). 72h-only: 風向, 綜合描述, per-3h resolution. 7-day-only: daily max/min as first-class values, days 4–7. Pop windows differ (`3小時降雨機率` :633 vs `12小時降雨機率` :665; labels `home_logic.dart:6-7`).

Helpers over this data: `currentSlot` (:164-169), `forecastExtremes` hottest/coldest/wettest over 72h (:172-193), `weeklyScale` temp axis incl. current temp (:210-219).

## 4. "Now" and clocks

- `weatherClockProvider = Provider<DateTime Function()>((ref) => DateTime.now)` — `weather_provider.dart:42`; doc: "測試可覆寫".
- Read in `_load` for the sun query and `fetchedAt` (:71,:84), and in the screen once per build: `final now = ref.read(weatherClockProvider)();` `weather_screen.dart:115`; passed as `now` to SunCard (:149), Forecast72hCard (:150), WeeklyCard (:154-ish). Note: `ref.read`, so `now` updates only when the screen rebuilds (no ticking timer in this code path).
- Tests override it: `test/unit/weather_provider_test.dart:69` (`DateTime.utc(2026, 11, 14, 4)` = TW 12:00).
- Time zone: fixed UTC+8, no DST — `home_logic.dart:3-4,12-18` (`taiwanWall`, `fromTaiwanWall`, `taiwanDate`); repo `_taiwanOffset` `weather_repository.dart:355`. `getSunTimes` uses TW calendar day of `now` (:187; test `weather_repository_test.dart:228-262`, UTC 17:00 → next TW day).
- Sun-position logic (pure, takes `now`): `sunPosition(day, now)` → phase (beforeSunrise / daytime / afterSunset), `dayFraction` 0–1 by time between sunrise and sunset, `untilEvent` — `home_logic.dart:116-143`. `sunNowLine` ("現在 HH:mm · 距日落…/已日落，距明天日出…") — `home_logic.dart:146-155`; tested `test/unit/home_logic_test.dart:33`.
- Arc painter (`sun_card.dart:158-250`): position = time fraction on a half-ellipse (`_fraction` :184, `_point` :186-189) — this is a **linear-in-time** placement, not true elevation; civil dawn/dusk points use negative/>1 fractions (:219-220); current-sun marker only drawn in daytime (:236-240); noon label shows time + `仰角 N°` (:244-245).

## 5. Error / no-key / loading states

- Key store: `CwaApiKeyNotifier` (`lib/core/api/api_key.dart:27-57`): null = not set (:34), corrupt → `StoredSettingException` (:35-42).
- Dio interceptor (`lib/core/api/dio_client.dart:34-54`): no key → request **rejected, not sent**, `CwaApiKeyException(missing, '尚未設定 token，請到「設定」輸入')` (:45-50); unreadable → `unreadable` (:38-44). Key attached as `Authorization` query param (:51). `dioProvider` watches key provider; repo rebuilt on key change (`weather_provider.dart:49`).
- `failureFromDio` (`weather_repository.dart:90-118`): maps key exception / HTTP 401,403 → `ApiKeyIssue {missing, rejected, unreadable}` (:77,:93-97); other types → Chinese messages with dataset (+location) (:101-112). Parse failures → `Failure('解析 $dataset 失敗…')` (:339-343); non-object response (:328-334). Unsupported county → Failure (:300-305).
- Page-level (`WeatherState.error`): loading place → `WeatherState()` (:51); place error (:52); `NoPlace(reason)` → `locationFailureMessage` (:53-54).
- Per-card UI: `SunCard` switch: `null` → loading skeleton; `Failure(apiKeyIssue != null)` → `ApiKeyNotice`; other `Failure` → error card with retry; `Success` → card (`sun_card.dart:33-38`). Same pattern expected in the other cards (HeroCard/Forecast72hCard/WeeklyCard take `Result?` + `onRetry`; `weather_screen.dart:144-158`) — **not individually verified for each card's code**.
- Refresh: `ref.invalidate(weatherNotifierProvider)` + warnings (`weather_screen.dart:41-44`).
- Missing values are `null`, never fake numbers: `-99`, `"-"` (`_noValueMarker`) → null (`weather_repository.dart:353,391-401`); non-numeric → Failure. `test/unit/weekly_missing_value_test.dart:23,37`.
- Source credits shown only for datasets on screen (`weather_screen.dart:121-133`).

## 6. Tests touching this layer
- `test/unit/weather_provider_test.dart` (:81 GPS load of all datasets, :97 permission denied → no place, :112 manual town, :134 one dataset failing keeps the others).
- `test/unit/weather_repository_test.dart` (hourly join :115, issue time :153-163, sun times :228-269 incl. bad `SunTransitAlt` → Failure).
- `test/unit/weekly_missing_value_test.dart`, `test/unit/home_logic_test.dart` (sun line :33, day labels :48, extremes :59, weekly scale :78, glyph :98, wind :108, issue time :118), `place_state_test.dart`, `nearest_town_test.dart`.
- Fixtures: `test/fixtures/cwa/{A-B0062-001,F-D0047-061,F-D0047-091,O-A0003-001}.json`.

## Uncertain / not verified
- Full real-world span of 72h/7-day (fixtures truncated to 4 slots); "3 days / 1 week" taken from code comments.
- Whether real hourly elements (溫度 etc.) in the live 3-day dataset are hourly for the whole span — fixture shows hourly `DataTime` entries; assumed same live.
- Other cards' (Hero/72h/Weekly) internal error handling not read line by line.
- The weekly parser being tested against `F-D0047-091` fixture renamed to `F-D0047-063` (`weather_provider_test.dart:78`) — fixture ID differs from the production weekly ID.
