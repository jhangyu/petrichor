# 首頁預報區 — architecture plan (7日預報 / 未來72小時預報)

Contract: `docs/logs/home-page-contract.md` item 4. Brief: `docs/design/home/brief.md`.
Scope: order of the two forecast cards, merge decision, data model and provider API for both options, error states, tests, work packages.
All references are to the code at commit `96a3b78`.

## 1. Evidence: what each card carries

Sources:
- 72h: `WeatherRepository.getHourlyForecast` → `_parseHourly` (`lib/data/repositories/weather_repository.dart:161-168`, `:625-650`), dataset `threeDay` (臺北市 = F-D0047-061, `lib/core/constants/app_constants.dart:50`).
- 7 日: `WeatherRepository.getWeeklyForecast` → `_parseWeekly` (`weather_repository.dart:171-178`, `:657-710`), dataset `oneWeek` (臺北市 = F-D0047-063, `app_constants.dart:50`).
- Raw element lists: fixtures `test/fixtures/cwa/F-D0047-061.json` and `F-D0047-091.json` (same 1-week element schema as the per-county `oneWeek` datasets).

| Aspect | 未來72小時 (`HourlyForecast`) | 7日 (`DailyForecast`) |
|---|---|---|
| Dataset | 3-day township forecast, 1 request (`weather_repository.dart:165`) | 1-week township forecast, 1 request (`:175`) |
| Unit of one record | one 3-hour slot (`weather_models.dart:108-142`; `forecastSlotLength` `home_logic.dart:161`) | one Taiwan calendar day, aggregated from 12-hour slots 06–18 / 18–06 (`weather_repository.dart:655-710`) |
| Raw granularity in API | 溫度 / 體感溫度 / 相對濕度 / 露點 / 舒適度: hourly points (`DataTime`); 風速 / 風向: 3-hourly points; 天氣現象 / 3小時降雨機率 / 綜合描述: 3-hour intervals (fixture F-D0047-061) | every element: 12-hour intervals (`StartTime`/`EndTime`) (fixture F-D0047-091) |
| Granularity kept by parser | 3 h — iterates `天氣現象` keys only, so 2 of every 3 hourly temperature points are dropped (`weather_repository.dart:636`) | 1 day — max/min over the day's slots; other fields from the 06:00 slot, else the first slot (`:681-707`, `_daySlotStartHour = 6` `:364`) |
| Horizon | ~72 h from issue time (≈ today + 2 days, partial 4th day) | 7 calendar days (`_weeklyDayCount = 7` `:358`) |
| Temperature | point value per slot (`:639`) | daily max / min (`:698-699`) |
| 體感 | point per slot (`:640`), drawn as dashed line (`forecast_72h_card.dart:408-411`) | daily max / min parsed (`:700-701`) — **not shown anywhere** |
| 降雨機率 | 3小時 (`:644`), bars (`forecast_72h_card.dart:462-487`) | 12小時 of the day slot (`:704`), text (`weekly_card.dart:100-111`) |
| 天氣現象 | per slot glyph (`forecast_72h_card.dart:124-130`) | per day glyph (`weekly_card.dart:99`) |
| 風 | 風速 + 風向 per slot (`forecast_72h_card.dart:488-489`) | 風速 parsed (`:703`), 風向 not parsed — **neither shown** |
| 濕度 | parsed (`:641`) — not shown by the 72h card | 平均相對濕度 parsed (`:702`) — not shown |
| Description text | 天氣預報綜合描述 (`:647`), shown only in HeroCard (`hero_card.dart:109`) | not parsed |
| Issue time | separate request `getForecastIssueTime` (`weather_repository.dart:260-285`), card meta (`forecast_72h_card.dart:46-50`) | none; meta is the date range (`weekly_card.dart:54`) |
| Summary logic | `forecastExtremes` (`home_logic.dart:181-193`) | `weeklyScale` with today's observed temperature marker (`home_logic.dart:210-220`, `weekly_card.dart:125`) |
| Visual | 340 px horizontally scrolling chart (`forecast_72h_card.dart:246`, `:134`) | 7 rows × 56 px with shared temp axis (`weekly_card.dart:32`, `:58`) |

Overlap: days 0–2 exist in both, from **two different forecast products with different issue cycles**. For those days the 7-day max/min and the max/min of the 72h points can differ (12-hour extremes vs 3-hour point samples).

## 2. Decision

**Keep separate; reorder only (7日 first, then 72小時).** The two cards do not carry the same level of information:
1. Granularity: 3-hour points vs one aggregated value per day (4× and 8× coarser for pop and weather).
2. Horizon: ~3 days vs 7 days; days 3–6 have no hourly data, so a merged card would have two kinds of day rows.
3. Element set: 72h shows 體感 curve, wind direction/speed, 3h pop; 7 日 shows daily range on a shared axis and the observed-now marker.
4. Two datasets, two issue times, independent failure (`weather_provider.dart:67-73`). A merged card has to show values from two products side by side for days 0–2, where the day row (7-day max/min) can disagree with its own expanded hourly detail (72h points). Hiding that would be a silent substitution; showing it costs a second meta line inside one card.

Merge (option B) is still specified below so designer-4's direction can be built if the user picks it. Recommendation stays A.

## 3. Option A — keep separate (recommended)

### Data model / provider
No change. `WeatherState.hourly`, `WeatherState.weekly`, `WeatherState.hourlyIssuedAt` (`weather_provider.dart:9-39`) stay as they are; `WeatherNotifier._load` (`:65-87`) unchanged.

### Widget change
- `_CardFlow` (`weather_screen.dart:214-255`): constructor order and child order become `weekly` before `forecast`:
  - 1 column: `[now, weekly, forecast]` (now = merged hero+sun card from the now-card plan).
  - 2 columns: `[now, weekly, forecast]`.
  - ≥3 columns: `pair(weekly, forecast, aFlex: _weeklyFlex, bFlex: _forecastFlex)` — 7 日 on the left (2 parts), 72 小時 on the right (3 parts). Doc comment `:211-213` and `_forecastFlex` comment `:222` updated to the new order.
- `WeeklyCard` and `Forecast72hCard` unchanged.

### Error states (unchanged, per card)
| State | 7日 card | 72小時 card |
|---|---|---|
| loading (`null`) | `AppCard.loading` 424 px (`weekly_card.dart:40`) | `AppCard.loading` 456 px (`forecast_72h_card.dart:40`) |
| API key issue | `ApiKeyNotice` (`:41`) | `ApiKeyNotice` (`:41`) |
| failure | `AppCard.error` 無法取得 7 日預報 + retry (`:42`) | `AppCard.error` 無法取得 72 小時預報 + retry (`:42`) |
| empty list | `AppCard.empty` 暫無 7 日預報 (`:43`) | `AppCard.empty` 暫無 72 小時預報 (`:43`) |
| issue time failed | — | meta 發布時間無法取得 (`:48`) |
| no observed temp | legend without now marker (`weekly_card.dart:156-160`) | — |

Note: when both have an API-key issue, two `ApiKeyNotice` blocks render. That is current behaviour; deduplication belongs to the page-state plan, not here.

### Tests
None new: reorder is layout wiring (testing policy excludes it). Existing `home_logic_test.dart` and `weather_repository_test.dart` stay.

## 4. Option B — merge into one 預報 card (day selector → hourly detail)

### Behaviour
One card `ForecastCard`, title 預報. Seven day rows (current WeeklyCard row content). Rows whose day is covered by 72h data are expandable; expanding shows that day's 3-hour slots (the current 72h chart, clipped to the day). Rows without hourly coverage are not expandable and show no affordance. One row expanded at a time; default = today.

### Data model (pure, `home_logic.dart`)
```dart
/// One row of the merged forecast card.
class ForecastDay {
  const ForecastDay({required this.day, required this.slots});
  final DailyForecast day;
  /// 3-hour slots whose start falls on [day]'s Taiwan date; empty = no hourly coverage.
  final List<HourlyForecast> slots;
}

/// Joins the 7-day list with the 72h slots by Taiwan calendar date.
/// Slots on dates outside [days] are a FormatException-free programming error → StateError
/// naming the slot time and the day range (no silent drop).
List<ForecastDay> forecastDays(List<DailyForecast> days, List<HourlyForecast> slots);
```
- Join key: `_dateKey(taiwanWall(slot.startTime))` == `DailyForecast.date`. Uses existing `taiwanWall` (`home_logic.dart:12`) and `taiwanDate` (`:18`).
- Slots before the first 7-day date (72h data issued earlier than the 7-day data, crossing midnight) are not an error: they belong to a past day and are dropped **by rule**, documented in the doc comment; slots after the last 7-day date raise `StateError` (cannot happen with 72 h < 7 d; stated so a broken dataset fails loudly).
- `forecastExtremes` stays and is applied per day (`forecastExtremes(fd.slots)`), so no new summary helper.

### Provider API
No new provider and no change to `WeatherState`; the join is computed in the widget from `weather.weekly` and `weather.hourly`. Reason: both are already independent `Result`s; a combined `Result<List<ForecastDay>>` would force one failure to hide the other.

### Widget split (one shared module, old cards deleted)
- New `lib/features/weather/widgets/forecast_card.dart`: card shell, day rows (moved from `weekly_card.dart` `_row`, `_TempRange`, `_NowDot`, `_legend`), expansion.
- `forecast_72h_card.dart` → renamed `hourly_chart.dart`: keeps `_ChartGeometry`, `_AxisPainter`, `_ChartPainter`, `_DashKeyPainter` as a public `HourlyChart(slots, now)` without the card shell and without the 72h summary row (the day row already shows the day's high/low/pop). Day-boundary lines and labels inside the painter (`forecast_72h_card.dart:334-368`) are removed: one day per chart.
- Deleted: `weekly_card.dart`, `forecast_72h_card.dart` (as files), `Forecast72hCard`, `WeeklyCard`, the `_summary`/`_stat` widgets (`forecast_72h_card.dart:71-112`). `forecastExtremes` is kept only if the expanded day view shows a summary; otherwise delete it and its test (`home_logic_test.dart:66-71`).
- `_CardFlow` takes 3 children `[now, forecast]` plus warnings at the bottom; `_forecastFlex`/`_weeklyFlex` deleted.

### Error states (merged card)
Each source keeps its own state; nothing is substituted.
| weekly | hourly | Card shows |
|---|---|---|
| loading | any | `AppCard.loading` (one skeleton, 7-row height) |
| API key issue | any | `ApiKeyNotice` once (hourly issue is the same key) |
| Failure | Success | `AppCard.error` 無法取得 7 日預報 + retry; hourly is **not** shown as day rows (no day row without daily data). Under the error, a secondary line「72 小時預報可用」is not added — retry reloads both. |
| empty | any | `AppCard.empty` 暫無 7 日預報 |
| Success | loading | day rows render; covered rows show an inline skeleton when expanded |
| Success | Failure | day rows render, no row expandable, inline `AppNote`/error line 無法取得 72 小時預報 + retry inside the card |
| Success | empty | day rows render, no row expandable, inline line 暫無 72 小時預報 |
| Success | Success | normal |
| issue time Failure | — | meta line 72 小時發布時間無法取得 (only while a row is expanded) |

### Tests (core logic only)
`test/unit/home_logic_test.dart` add:
1. `forecastDays` joins slots to the right Taiwan date across midnight (slot 23:00 UTC+8 vs 00:00 UTC+8 boundary; 15:00Z = 23:00 local stays on the same date, 16:00Z moves to next date).
2. Days 3–6 have empty `slots`.
3. Slots before the first day are dropped; a slot after the last day throws `StateError` whose message names the slot time and the day range.
Delete tests for removed functions only (see widget split).

## 5. Work packages (disjoint file ownership)

### Option A
| Package | Files (sole owner) | Acceptance |
|---|---|---|
| A1 reorder | `lib/features/weather/weather_screen.dart` (`_CardFlow` only) | 1/2/≥3-column order = now, 7日, 72小時; `flutter analyze` clean; `test/unit` green |

`weather_screen.dart` is also touched by the now-card plan (hero+sun → one child) and the warnings plan (warnings to bottom). Lead must give the whole file to one implementer, or serialize the three edits.

### Option B
| Package | Files (sole owner) | Acceptance |
|---|---|---|
| B1 join logic | `lib/features/weather/widgets/home_logic.dart`, `test/unit/home_logic_test.dart` | tests 1–3 above red first, then green |
| B2 hourly chart | `lib/features/weather/widgets/forecast_72h_card.dart` → `hourly_chart.dart` (git mv lists both paths) | `HourlyChart(slots, now)` public; no card shell, no summary, no day-boundary drawing; analyze clean |
| B3 merged card | new `lib/features/weather/widgets/forecast_card.dart`; delete `weekly_card.dart` | all rows in §4 error table render; uses `forecastDays` and `HourlyChart`; analyze clean |
| B4 page wiring | `lib/features/weather/weather_screen.dart` | `_CardFlow` uses `ForecastCard`; no reference to `WeeklyCard`/`Forecast72hCard` (`grep` = 0); `test/unit` green |

Order: B1 and B2 in parallel → B3 → B4. Same `weather_screen.dart` note as option A.

## 6. Parking lot (found while reading; not in this plan's scope)
- Dead model fields: `DailyForecast.maxApparentTemperature`, `minApparentTemperature`, `humidity`, `windSpeed`, `weatherCode`, the `weekdayName` getter (`weather_models.dart:150-177`), and `HourlyForecast.humidity` / `weatherCode` (`:116`, `:125`) are parsed but no widget reads them (grep over `lib/`). Project rule "no dead code" → delete with their parse lines, or show them in the redesign.
- `_parseHourly` drops the hourly 溫度/體感 points between 3-hour slot starts (`weather_repository.dart:636`); the 72h chart could plot hourly temperature if wanted.
- `_parseWeekly` falls back to `starts.first` when a day has no 06:00 slot (`weather_repository.dart:692-695`); documented in `:656` (today with only the night slot), so it is a rule, not a silent fallback.
