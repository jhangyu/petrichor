# 天氣 tab — Designer 2：精簡（compact）

Mockup: `home.html` (same folder). Contract: `docs/logs/home-page-contract.md`. Brief: `docs/design/home/brief.md`.
Inputs read: `weather_screen.dart`, `widgets/{hero_card,sun_card,weekly_card,forecast_72h_card,home_logic,weather_glyph_icon}.dart`, `hazard/warnings_screen.dart`, `hazard/warnings/*`, `core/widgets/*`, `docs/design/home/code-data.md`, `code-warnings.md`, `docs/design/adaptive/weather.md`.

Direction: **minimum page height**. One now card instead of two cards, a thin sun-arc strip beside the temperature, all 8 small values in one dense chip strip, two notes. Forecast cards keep their content; 特警報 moves to the page end.

## 1. Page order and frames

| # | Block | Widget (proposed) | Replaces |
|---|---|---|---|
| 1 | Now card (即時觀測 + 日出日落) | `NowCard` (new, `features/weather/widgets/now_card.dart`) | `HeroCard` + `SunCard` |
| 2 | 7 日預報 | `WeeklyCard` (row height 56 → 48) | — |
| 3 | 未來 72 小時預報 | `Forecast72hCard` (unchanged) | — |
| 4 | 特警報 | `WarningsPanel` (new shared, `features/hazard/warnings/warnings_panel.dart`) | `WeatherScreen._warningEntry` banner at the page top |
| — | Source line | `SourceLine` (unchanged rule: only datasets on screen) | — |

Frames in `home.html`: phone 375 px — A 白天＋生效中特報, B 夜間＋無特報, C 載入中, D 部分錯誤, E 無 token, F 無地點（權限被拒）; wide 1024 px — G 白天＋特報.

Height estimate at 375 px (now area only): today hero (≈330) + gap 16 + sun card (≈350) ≈ 700 px → now card ≈ 400 px (top row 24, main row 92, 8 chips 2 × 44 + 8, notes ≈ 2 × 40–80, paddings). The idle 「下拉即可重新整理」 hint is removed on this page (the app bar has 重新整理); the loading pill stays.

## 2. Now card (`NowCard`)

Shell: `AppCard(hero: true)` (brand-160 → bg-1 gradient, shadow-8). Children, top to bottom, gap `AppSpace.s12`:

1. **Top row** — eyebrow `即時觀測 14:10 · 信義站 0.8 km` (caption1, fg3, tabular; `CurrentWeather.observedAt`, `stationName`, `distanceKm`). Right side, only when the county has active warnings: `AppBadge(tone: alert1..4)` 「大雨特報等 2 項 ↓」. Tap scrolls to the 特警報 section (`Scrollable.ensureVisible` on the panel's `GlobalKey`). This is a pointer, not a second warning UI: no list, no text, same `groupsForCounty` result the panel uses.
2. **Main row** — `Row`: temperature column | `SunArcStrip` (Expanded, max width 240).
   - Temperature column: `tempText(temperature)` in `AppType.display` with line height = font size (68, tighter than today's 92 line); 高/低 (`dailyHigh`/`dailyLow`, tempHot/tempCold, subtitle2); 天氣現象 text (body1 strong). The 64 px `WeatherGlyphIcon` leaves this column — the glyph now rides on the arc.
3. **Chip strip** — 8 `MetricTile`s in `MetricGrid(dense: true)`: row 1 comfort 體感 / 濕度 / 風 · 東北 / 降雨機率; row 2 sun 曙光 / 日出 / 日落 / 暮光. Same level: same tile, same type, no icons. 4 columns at phone, 8 columns once the grid is ≥ `AppLayout.cardWideWidth`.
4. **Notes** — `AppNote` ×2, same widget, shape, padding, icon size and type (lead clarification: 天氣建議 = the HeroCard summary strip, `hero_card.dart:114-129`, `code-ui.md` §6; the sun line `home_logic.dart:145-155` is its sibling in the same style). Only the tint differs, so the forecast text keeps its rain meaning and the sun line does not read as rain:
   - 天氣建議: tone rain, umbrella icon, `HourlyForecast.description` of `currentSlot(...)` verbatim (today's `HeroCard._summary`).
   - 日照: tone neutral (bg-1, stroke-3 edge on the hero gradient), clock icon by day / moon icon by night. Text from `sunNowLine` extended: day 「現在 14:10，距日落 2 小時 56 分 · 白晝 10 小時 44 分」; night 「現在 21:40，已日落，距明天日出（06:23）8 小時 43 分」; before sunrise 「現在 05:10，距日出 1 小時 12 分」. This absorbs SunCard's 白晝長度 and 明天日出 line, so nothing from SunCard is lost.

Removed from SunCard with reason: the "明天 11/16 日出 · 日落" divider line (tomorrow's sunrise is in the night note; tomorrow's sunset is one minute off today's and not worth a row); the 曙光／暮光 dots on the arc (the values are chips now).

### Data per element

| Element | Source | Field |
|---|---|---|
| Temperature, 高/低, 天氣現象, 濕度, 風 | O-A0003-001 | `CurrentWeather` |
| 體感, 降雨機率, 天氣建議 | 72h slot covering now | `currentSlot(hourly, now)` → `apparentTemperature`, `pop`, `description` |
| 曙光／日出／日落／暮光, 過中天 | A-B0062-001 | `SunDay.civilDawn/sunrise/sunset/civilDusk/transit` |
| 目前仰角 | **computed** (no API value, `code-data.md` Q1) | new pure `solarElevationDegrees(lat, lon, now)` in `home_logic.dart` (NOAA solar-position formula), `Place.latitude/longitude` |
| Arc position | `sunPosition(day, now)` (existing, time fraction) | `dayFraction`; night fraction = share of sunset→next sunrise |

The arc keeps today's time-linear placement (matches SunCard). The elevation number is the true computed angle; the glyph height is not tied to it, so the label is the only claim of accuracy.

### `SunArcStrip` (replaces `_SunArcPainter`)

View box 184 × 84, horizon y 60, half-ellipse rx 76 / ry 44, centre x 92 (sunrise x 16, sunset x 168). Painted by a `CustomPainter` in the same way as today (`chart_paint.dart` `dashedPath`, `paintLabel`).

- Day: travelled part solid `iconSun` 3 px, rest dashed `stroke1`; ends are rings; 過中天 is a small ring at the apex with the label 「過中天 11:44」 under it; the current-weather glyph (`weatherGlyphStyle`, 20) sits in a bg-1 disc (r 12, sun-coloured edge) at the sun position; 「仰角 31°」 (caption2 semibold) under the disc. 「日出」「日落」 under the ends.
- Night (before sunrise / after sunset): the upper arc is fully dashed; a shallow track under the horizon (ry 14) goes from sunset back to sunrise; the disc (moon glyph for 晴, cloud for 多雲 etc.) sits on it at the night fraction; 「仰角 −56°」 above the horizon next to it.
- Semantics: one label, e.g. 「太陽位置：日出 06:22，現在 14:10 太陽仰角 31 度，過中天 11:44，日落 17:06」.

**Readability at 375 px.** Card content width = 375 − 2 × 16 (page) − 2 × 20 (hero padding) = 303. Temperature column ≈ 100, gap 12 → the strip gets ≈ 190 px, i.e. ≈ 1.03 × the view box, so the 10 px labels render at ≈ 10 px. Rules that keep it readable:
1. Only two text marks on the arc (過中天 time, 仰角). All other times are chips.
2. Labels are painted unscaled (`paintLabel` after `canvas.scale` is undone for text) so they never shrink below caption2 when the strip is narrower (min useful width 160 → strip hides the 過中天 label below 160, never the 仰角 label).
3. The two labels sit on different rows (y 33 at the apex, y 52 under the disc) so they cannot collide; at 11:00–12:30 when the disc is near the apex, the 過中天 label moves above the horizon to the left end (`x = 16 + labelWidth/2`), checked by comparing x ranges in the painter.
4. Wide: strip fixed at 240 px; labels unscaled.

### Night glyph

`weatherGlyph` returns `sun` for 「晴」 also at night. Proposed: `weatherGlyphStyle(glyph, night: phase != daytime)` maps sun → `Icons.nightlight_outlined`, partly → `Icons.nights_stay_outlined`; others unchanged. Only the now card passes `night` (forecast rows keep day glyphs).

### States (one card, three datasets)

| Condition | Now card shows |
|---|---|
| any of current / sun still `null` | `AppCard.loading(hero: true, skeletonHeight: _nowSkeletonHeight)` — skeleton: line, temp block + arc block, 8 chip blocks, 2 note blocks (frame C) |
| current `Failure` (not key) | temperature column shows 「—／觀測失敗」 (muted), an `AppNote(tone: error)` row 「無法取得目前天氣 · message」 + `RetryButton` under the main row; arc, sun chips, sun note stay (frame D). 濕度／風 chips show 「—」; 體感／降雨機率 still come from the forecast slot |
| sun `Failure` | arc strip and the 4 sun chips are replaced by one error note 「無法取得日出日落資料」 + retry; comfort chips and notes stay |
| hourly `Failure` / no slot | 體感／降雨機率 chips show 「—」, no 天氣建議 note (the 72h card already shows that error) |
| both current and sun `Failure` | `AppCard.error(title: '無法取得目前天氣與日照', …)` |
| any `Failure(apiKeyIssue)` | page-level notice (§6), the card is not built |

Missing values show 「—」 (existing `tempText`/`percentText`), never defaults.

## 3. Chips and notes — shared widgets

- **`MetricGrid(dense: true)` / `MetricTile(dense: true)`** (change in `core/widgets/data_display.dart`): padding 4/8 instead of 8/12, no icon, columns 4 (narrow) or all (≥ `cardWideWidth`) via a `narrowColumns` parameter (default 2 keeps other callers unchanged). Needed because 8 tiles at 2 columns would be 4 rows (≈ 220 px); dense 4×2 is ≈ 96 px. Width check at 375: (303 − 3 × 8) / 4 ≈ 70 px per chip, 54 px text width: 「風 · 東北」 (≈ 46 px at 12 px) and 「3.2 m/s」 (≈ 48 px at 14 px semibold) fit; longer values ellipsize (`softWrap: false` already).
- **`AppNote`** (new, `core/widgets/status.dart`): icon 20 + body1 text, padding 8/12, radius small; tones `rain` (rainBg/rainFg), `neutral` (bg1 + stroke3), `error` (dangerBg/dangerStroke, optional trailing action). Justification: the 天氣建議 container exists only privately in `HeroCard._summary`; the requirement makes the sun line a sibling of it, so both need one definition. `SettingsNote` (`settings_parts.dart:83`) is a caption footnote without container — different element, not reused.

## 4. 7日預報 and 72小時預報 — decision: keep separate

Order: 7 日 first, then 72 小時 (contract item 4). **Not merged**, because they do not carry the same level of information (`code-data.md` §3):

1. Granularity differs: 72h = 3-hour slots (temperature at the slot boundary, 3-hour 降雨機率); 7-day = one row per day built from 12-hour slots (daily max/min, 12-hour 降雨機率).
2. Elements differ: 風向 and 天氣預報綜合描述 exist only in 72h; daily max/min as first-class values and days 4–7 exist only in 7-day. A day row cannot expand into 72h detail for days 4–7, and days 1–3 would show two different 降雨機率 windows for the same day.
3. A merged card with a day selector adds a selection state and a tall expanded area — opposite of this direction's minimum height goal.

Changes:
- `WeeklyCard._rowMinHeight` 56 → 48 (rows are not interactive; content 36 + padding 8). Saves 56 px.
- `Forecast72hCard` unchanged.
- `_CardFlow`: 1 column → now, weekly, 72h stacked; ≥ 2 columns → now card full row, then weekly (2 parts) | 72h (3 parts). `_EqualHeightPair` and `_RenderEqualHeightPair` are deleted (no hero|sun pair any more).

## 5. 特警報 at the page end — one shared component

**`WarningsPanel`** (new, owns the list part of today's `WarningsScreen`):

```
WarningsPanel({
  required AsyncValue<Result<ActiveWarnings>> warnings,   // activeWarningsProvider
  required String county,
  required WarningScope scope,          // county | all
  required DateTime now,
  required bool openFirst,              // tab: true, home: false
  Widget? trailing,                     // home: 「全臺 N 項 ›」 → AppTab.warnings
})
```

- One `switch` over loading / `AsyncError` / `Failure(apiKeyIssue)` / `Failure` / `Success` (today duplicated at `weather_screen.dart:171-177` and `warnings_screen.dart:80-89`).
- Success with groups: `SectionHeader('特警報', meta: '臺北市 · 2 項')` + `WarningCard`s (same widget as the tab; masonry columns via `AppGrid.columnsFor`, collapsed on home).
- Success, none: `StatusBanner(tone: empty)` with a success check — 「臺北市目前無警特報 · 全臺 0 項生效中 · 最近檢查 21:40」 (frame B). The tab uses the same row under its hero instead of its own `EmptyState`.
- Failure: `StatusBanner(error)` 「無法取得警特報」 + message + 「這不代表目前沒有警特報。」 + `RetryButton` (frame D). Same on the tab.
- Loading: one skeleton warning card (frame C).
- ApiKey failure: renders nothing on home (the page-level notice covers it); the tab shows `ApiKeyNotice` as today.

`WarningsScreen` keeps only what is tab-specific: `WarningsHero`, the 全部／我的縣市 chips, page scaffold; the list part becomes `WarningsPanel(scope: _mineOnly ? county : all, openFirst: true)`. Home: `WarningsPanel(scope: county, openFirst: false, trailing: 全臺 link)` as the last grid item. Deleted: `_warningEntry`, `_warningError`, `_activeEntry`, `_range` in `weather_screen.dart`; the `StatusTone.alert1/alert3` mapping that collapsed levels 2 and 4.

Also unified: one clock (`weatherClockProvider` and `warningsClockProvider` → one `appClockProvider`), one time-range formatter (`formatTaiwanMonthDayClock`), status labels 即將生效／生效中 as public constants in `warning_card.dart`. Source line keeps adding W-C0033-001/002 only when the panel shows data.

Wide (frame G): the panel spans the full row; cards in 2 columns.

## 6. Page-level states

| State | Page shows | Frame |
|---|---|---|
| Loading (first load) | loading pill 「載入天氣資料…」, now / weekly / 72h skeletons, panel skeleton; refresh button disabled; subtitle 「目前位置 · 更新中…」 | C |
| Partial errors | each block shows its own error in place (§2 states, `AppCard.error` for 72h, panel error) | D |
| No API key | **one** `ApiKeyNotice` (missing / rejected / unreadable text unchanged, 「前往設定」 primary); no cards. Rule: if any dataset Failure has `apiKeyIssue`, all requests share the same key, so the page shows one notice instead of four identical ones (today each card shows its own) | E |
| No place / permission denied | `_NoPlaceGuide` unchanged (permission banner, 使用目前位置 + 手動選擇); title 「尚未選擇地點」 with warning-coloured pin | F |
| Night | §2 night arc + moon note | B |
| Day | §2 | A, G |
| Active warning | badge in now card top row + panel cards at the end | A, G |
| No warnings | no badge; panel success-empty row | B |

## 7. Wide layout (≥ 1024)

`NavigationRail` + content. Now card spans the full row with the main row as temperature | arc strip (240) | notes (flex), and the 8 chips in one row below. Then 7 日 (2 parts) | 72 小時 (3 parts), then the panel full row (2 card columns). Card height on wide ≈ 230 px.

## 8. New / changed / deleted code (for the architecture plan)

| Item | Kind | Why |
|---|---|---|
| `widgets/now_card.dart` (`NowCard`, `SunArcStrip` painter) | new | requirement 1–3; replaces two cards |
| `widgets/hero_card.dart`, `widgets/sun_card.dart` | delete | replaced, no other callers |
| `home_logic.dart`: `solarElevationDegrees`, `sunNote` (extends `sunNowLine` with 白晝 / tomorrow sunrise time), night fraction | new functions | elevation is not in the API; note text |
| `weather_glyph_icon.dart`: `night` flag | change | 「晴」 at night must not show a sun |
| `core/widgets/data_display.dart`: `MetricGrid(dense, narrowColumns)`, `MetricTile(dense)` | change | 8 chips in 2 rows |
| `core/widgets/status.dart`: `AppNote` | new | two sibling notes, one definition |
| `hazard/warnings/warnings_panel.dart` | new | requirement 5, single list implementation |
| `weather_screen.dart`: `_CardFlow` 2 layouts, delete `_EqualHeightPair`, delete warning-entry code, page-level key notice, drop idle pull hint | change | |
| `warnings_screen.dart`: list part → `WarningsPanel` | change | |

Tests to keep/add (per project policy): `solarElevationDegrees` against 2–3 known values (e.g. Taipei 2026-11-15 11:44 ≈ 47°, matching `SunTransitAlt 47S`); `sunNote` day / night / before-sunrise strings (extends `home_logic_test.dart:33`). No widget tests.

## 9. Uncertain

- Elevation formula accuracy: NOAA approximation is ±0.5° class; shown as integer. Needs the place's lat/lon (present in `Place`); for a GPS place this is the device point, for a manual place the town centroid.
- The jump badge in the now card is my addition to keep an active warning visible above the fold after moving the panel to the end; drop it if the user wants nothing about warnings at the top.
- Dropping the idle 「下拉即可重新整理」 hint and the SunCard tomorrow-sunset line are compactness choices, not contract items.
- Arc SVG in the mockup scales labels with the strip; the Flutter painter is specified to draw labels unscaled (§2 rule 2).
- Mockup chart and data values are illustrative (Taipei, 2026-11-15); not taken from a live fetch.
