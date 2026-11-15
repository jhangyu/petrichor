# 天氣首頁 — Designer 3：寬螢幕優先自適應

Mockup: `home.html` (same folder). Contract: `docs/logs/home-page-contract.md`. Brief: `docs/design/home/brief.md`.
Tokens: `lib/core/theme/app_tokens.dart`. Layout rules: `docs/design/adaptive/system.md`, `adaptive/weather.md`.

## 1. Design idea

- The page has **four blocks in a fixed reading order**: 目前天氣 (merged sun-arc card) → 7 日預報 → 未來 72 小時預報 → 警特報.
- **Wide first.** At 3 grid columns the page is a dashboard: 目前天氣 | 7 日 on top, 72 小時 spans both columns below, and 警特報 is a **side column that starts at the top**. A warning is then visible in the first screen without being first in reading order.
- **Fewer columns: the side column drops to the bottom.** Two columns: now | 7 日, 72 小時 full, 警特報 full. One column: four blocks stacked.
- On 1 and 2 columns the warnings are below the fold, so the now card eyebrow shows one alert badge (「大雨特報 生效中」). The badge scrolls to the 警特報 section. It is a pointer, not a second warnings implementation.
- Same component on both pages: the home 警特報 block and the list part of the 警特報 tab are one widget, `WarningsSection`, fed by one data path (§8).

## 2. Layout per width

`_CardFlow` + `_EqualHeightPair` (`weather_screen.dart:214-324`) are replaced by `_HomeFlow`. The hero|sun pair is gone, so the equal-height render object is deleted. Rows are top-aligned (system.md §5).

```dart
// LayoutBuilder in _HomeFlow
final columns = AppGrid.columnsFor(box.maxWidth, spanUnits: 3);   // 3 = now, 7日, side
switch (columns) {
  1 => Column([now, weekly, forecast, warnings]),
  2 => Column([Row([Expanded(now), Expanded(weekly)]), forecast, warnings]),
  _ => Row(crossAxisAlignment: start, [
         Expanded(flex: 2, child: Column([Row([Expanded(now), Expanded(weekly)]), forecast])),
         Expanded(flex: 1, child: warnings),
       ]),
}
```

| Window | Nav | Content width | Columns | Arrangement | Eyebrow badge |
|---|---|---|---|---|---|
| 375 (phone) | bottom bar | 343 | 1 | now → 7 日 → 72 h → 警特報 | shown when the county has a warning |
| 1024 | rail | 880 | 2 (432 each) | now \| 7 日; 72 h full; 警特報 full | shown |
| 1280 | rail | 1136 | 3 (368 each) | [now \| 7 日; 72 h span 2] \| 警特報 side | hidden (side column is on screen) |

All gaps are `AppLayout.gridGap` (16). Breakpoints come only from `AppGrid.columnsFor` (gridMinColumn 340). `_HomeFlow` passes `showWarningBadge: columns < 3` to the now card.

The 3-column split uses `flex 2 : 1`, which equals two grid columns plus one (each 368 at 1280). The side column is not sticky. The page scrolls as one, like every other tab (adaptive/weather.md "Short height").

## 3. Merged now card — `NowCard`

**New feature widget** `lib/features/weather/widgets/now_card.dart`. It replaces `hero_card.dart` and `sun_card.dart`. Both files are deleted, and `_SunArcPainter` moves into `now_card.dart`. Why a new widget: the contract merges two cards into one. The result is the same `AppCard(hero: true)` shell with the content of both. No new shared component.

Inputs: `current: Result<CurrentWeather>?`, `slot: HourlyForecast?` (from `currentSlot`), `sun: Result<List<SunDay>>?`, `place: Place` (lat/lon for elevation), `now`, `warningBadge: WarningGroup?`, `onWarningTap`, `onRetry`.

| Part (top → bottom) | Widget | Notes |
|---|---|---|
| Shell | `AppCard(hero: true)` (`app_card.dart:15`) | brand-160 → bg-1 gradient, shadow-8, padding 16/16/16/20 (unchanged). |
| Eyebrow | `Row[Text caption1 fg3, ?AppBadge]` | Text: `即時觀測 · {stationName}站 {clockText(observedAt)}`. The station name is new on screen (`CurrentWeather.stationName`, `weather_models.dart:8`). Badge: `AppBadge(tone: alert1/alert3 via WarningLevelStyle.of(level).tone, icon: Icons.warning_amber_outlined, label: '{name} {生效中/即將生效}')` inside `InkWell` → `Scrollable.ensureVisible(warningsKey)`. Shown only when `showWarningBadge` and the county has ≥ 1 group. The old 降雨機率 badge is removed (it moves to a tile). |
| Head row | `Row[display temp + 高/低 column, Text(weather) subtitle1]` | Same text styles as `HeroCard` (`hero_card.dart:61-80`). The 64-px weather glyph leaves the head row and rides the arc. |
| Sun arc | `CustomPaint(_SunArcPainter)` in `AspectRatio(320/150)` | See §4. |
| Comfort tiles | `MetricGrid(columns: 4, [MetricTile × 4])` | 體感 `tempText(slot.apparentTemperature)` · 濕度 `{humidity}%` · `風 · {observedWindLabel}` / `speedText(windSpeed)` · 降雨機率 `percentText(slot.pop)`. `icon: null` and `onHero: true`. |
| Sun tiles | `MetricGrid(columns: 4, [MetricTile × 4])` | 曙光 `civilDawn` · 日出 `sunrise` · 日落 `sunset` · 暮光 `civilDusk` (today, chronological). Same tile style, same level as the comfort tiles (contract item 2). |
| Notes | `Column(spacing: s8, [_NowNote × 1–2])` | 天氣建議 (rain tone): `slot.description` verbatim, the old `HeroCard._summary`. 日照 (neutral tone): `sunNowLine(today, tomorrow, now)` (`home_logic.dart:146`), plus `· 白晝 {durationText(day length)}` in daytime (the day length moves here from the old sun card). Each note has a caption1 semibold label line, then body1 text. Both notes are the same widget at the same level (contract item 3). |

`_NowNote` is **feature-private** (one file, two tones: rain = `rainBg/rainFg`, neutral = `bg2/fg1` with a `brandFg` icon). It is not promoted to `lib/core/widgets`. Only this card uses it. `SettingsNote` (`settings_parts.dart:83`) is a footnote style without a background, so it is not the same thing.

### MetricGrid change (foundation-owned, `data_display.dart:141`)

Add an optional `columns` (int?). When set, the grid uses that many columns if each tile can be at least `AppSize.metricMinTile` (64) wide. Otherwise it falls back to 2. Why: eight tiles at the existing "all in one row from 520" rule would be 60 px wide on wide cards, and 2 columns on phones would give 4 rows (≈ 232 px). Four columns give 2 rows (≈ 112 px) at every width from 320 up. With `columns: 4`, `MetricTile` uses horizontal padding s8 instead of s12 (so 「4.2 m/s」 fits in a 72-px tile at 375). Existing callers pass nothing and keep their behaviour.

## 4. Sun arc — what it carries and how it stays readable at 375

View box 320 × 150. The horizon is at y 100. The day half-ellipse has rx 128, ry 76. The **night half-ellipse below the horizon** has ry 28 and runs from sunset back to sunrise.

| Mark | Daytime | Night (before sunrise / after sunset) |
|---|---|---|
| Elapsed path | solid `iconSun` 3 px, sunrise → now | day arc dashed `stroke2` (dim). Night arc: solid `iconCloud` 60 % from sunset → now |
| Remaining path | dashed `stroke1` now → sunset | dashed `stroke2` now → sunrise |
| Twilight | dawn/dusk segments, dashed `iconSun` 40 % (unchanged) | same |
| Current weather | **glyph on the sun position**: bg-1 disc r 16, `iconSun` ring, `WeatherGlyphIcon` 20 inside | glyph on the night arc. Position = share of the night elapsed (sunset → next sunrise). The glyph uses the night variant (§9) |
| 仰角 label | 「仰角 33°」 caption1 semibold fg1, next to the marker on the outer side (below it when the label would cross the card edge) | 「仰角 −62°」 to the right of the marker |
| 過中天 label | 「過中天 11:39」 caption1 fg2 above the transit dot (y 13) | same (today's transit) |

Sunrise and sunset times are **not** drawn on the arc. They are tiles. The arc carries only two labels, so at 375 nothing collides.

Readability at 375: card interior = 375 − 2×16 page − 2×16 card = 311. Arc height = 311 × 150/320 ≈ 146. Labels are painted **after** `canvas.scale` is undone (unscaled caption1 12 px), so they never shrink below 12 px. The current painter scales labels with the canvas (`sun_card.dart:202,244`), which would give 11.7 px at 311. The marker disc is 32 px at view scale, ≈ 31 px on screen, and holds a 20-px glyph. Label placement uses a fixed rule (outer side of the marker, flip below when `x > viewWidth − 70`), so long labels never cross the card edge.

Elevation: `A-B0062-001` carries only the noon elevation (`SunDay.transitAltitudeDegrees`). Current elevation is **computed on the device**: a new pure function `solarElevation(latitude, longitude, DateTime utc)` in `home_logic.dart` (NOAA low-precision formula, ±0.5°), with `Place.latitude/longitude`. The arc **position** stays time-based (`sunPosition().dayFraction`), as today. Only the label shows the real angle. Semantics label: 「太陽位置：日出 06:13、過中天 11:39（仰角 47°）、日落 17:06；現在 14:10 仰角 33°，短暫陣雨」.

## 5. 7 日預報 — `WeeklyCard` (unchanged)

`weekly_card.dart` as is: rows 今天/明天/週X, glyph, 12-h 降雨機率, min, temperature range bar with the current-temperature dot on today's row, max, legend. It now comes **before** 72 小時 in every layout (contract item 4). At 1280 it sits beside the now card (368 wide, the width it was designed for).

## 6. 未來 72 小時預報 — `Forecast72hCard` (unchanged)

`forecast_72h_card.dart` as is: summary (最高溫/最低溫/降雨機率 with when), horizontally scrolling chart (temperature line, 體感 dashed line, glyphs, 3-h bars, wind), legend. At 1280 it spans the two main columns (752 wide). At 16 px/h it still scrolls (72 × 16 = 1152), but it shows about 2 days at once instead of 1.

## 7. 7日 / 72小時 merge decision — **keep separate**

The two cards do not carry the same level of information, so the contract says to keep them apart:

1. **Different time grain**: 7 日 = one row per day (12-h max/min and 12-h 降雨機率, F-D0047-063). 72 小時 = 3-hour slots (F-D0047-061).
2. **Different fields**: only 72 小時 has 體感 per slot, wind per slot, hourly glyphs, and the extremes summary. Only 7 日 has the week-wide temperature range bars and the observed-temperature dot.
3. **Different questions**: 「這週哪天會下雨/變冷」 vs 「今晚到後天幾點下雨」. A merged card with a day selector hides one answer behind a tap.
4. **Overlap is partial**: 72 小時 covers only days 1–3 of the 7.
5. **The wide layout already solves the "two cards" cost**: at 3 columns both are visible at once (7 日 top right of the main area, 72 小時 below). A selector would remove that glance.

## 8. 警特報 — one component, one data path

### Shared widget: `WarningsSection` (new, `lib/features/hazard/warnings/warnings_section.dart`)

This is the list part that `WarningsScreen` builds inline today (`warnings_screen.dart:145-206`), moved into a widget that both pages use:

| Part | Widget |
|---|---|
| Header | `SectionHeader(title, trailing: caption1 meta)` (`app_card.dart:176`). Home: 「警特報 · 臺北市」 / 「1 項 · 依等級排序」. Tab: 「生效中」 or county / 「依等級排序」 (as today) |
| List | masonry `WarningCard`s, `columns = AppGrid.columnsFor(width, spanUnits: n)`, item i → column i % columns (moved unchanged). In the home side column (368) this is always 1 column. First card `initiallyOpen` on both pages |
| Empty | Home: `StatusBanner(tone: empty, icon: check)` 「臺北市目前無警特報 · 最近檢查 21:38」 (compact). Tab: the existing `EmptyState` variants. Selected with `compactEmpty: true` |
| Footer (home only) | `AppButton(subtle, block)` 「查看全臺警特報 · N 項 ›」 → `appTabProvider.select(AppTab.warnings)` |
| Loading / error / API key | rendered by the section from the shared view (below). Error text always says 「這不代表目前沒有警特報。」 |

The tab keeps its own page parts around the section: `WarningsHero`, the 全部/我的縣市 chips, and the page header. These exist only on the tab, so they are not duplicates.

### Shared data path

- One provider stays: `activeWarningsProvider` (`hazard_provider.dart:11`).
- New pure function `warningsView(AsyncValue<Result<ActiveWarnings>>, String county)` → sealed `WarningsView { loading, apiKey(issue), error(message), data(all, mine, fetchedAt, updatedAt) }`. It replaces the two `Result` switches (`weather_screen.dart:171-177`, `warnings_screen.dart:80-89`) and the two inline county filters.
- One clock: `warningsClockProvider` is removed. Both pages use `weatherClockProvider`, renamed to `appClockProvider` (code-warnings.md §5 item 7).
- One time format: `formatTaiwanMonthDayClock` everywhere. The home `_range` (`weather_screen.dart:207`) and its level→tone mapping (`:199`) are deleted with `_warningEntry`.
- The 即將生效/生效中 strings are exported once from `warning_card.dart` and used by the badge.

### Deleted on home

`_warningEntry`, `_warningError`, `_activeEntry`, `_range` (`weather_screen.dart:163-208`). The top-of-page banner goes away. The eyebrow badge (§3) is the only warning hint above the fold on 1–2 columns.

## 9. Weather glyph at night

`weatherGlyphStyle` (`weather_glyph_icon.dart:7`) gains `night: bool`. Then `sun` → moon (`Icons.nightlight_outlined`, `iconCloud`) and `partly` → `Icons.nights_stay_outlined`. Other glyphs do not change. `night = sunPosition(...).phase != daytime`. Why: a sun glyph riding the arc below the horizon at 21:40 contradicts the arc. Only the now card passes `night`. The 72-hour chart can adopt it later (parking lot).

## 10. States

| State | What renders | Frame |
|---|---|---|
| Daytime + active warning | full page; eyebrow badge on 1–2 columns; first `WarningCard` open | A (375), G (1280) |
| Night + no warnings | marker on the night arc, negative elevation, moon glyph; section shows the compact empty banner + 「查看全臺 · 2 項」 | B (375), H (1024) |
| Loading | loading pill; each card `AppCard.loading` with its data height (now card skeleton 560: eyebrow, temp, arc 146, 2 tile rows, 2 notes); section header + one 76-px skeleton | C |
| Error (offline) | each card `AppCard.error` + 重試 independently; section `StatusBanner(error)` with 「這不代表目前沒有警特報。」 | D |
| Partial: sun data failed | now card still renders observation. The arc area becomes a danger-tinted inline row 「無法取得日出日落資料 · 重試」. Sun tiles show 「—」. The 日照 note is hidden | D2 |
| No API key | **one** `ApiKeyNotice` for the page (`api_key_notice.dart:11`) + `EmptyState`. Today every card shows its own notice (4–5 copies). Rule: if any weather dataset or warnings returns `apiKeyIssue`, `_content` returns just the notice | E |
| No place / location denied | `_NoPlaceGuide` unchanged (`weather_screen.dart:370`); header 「尚未選擇地點」, refresh disabled | F |

Per-dataset independence stays as today: `WeatherState` keeps one `Result` per dataset, and each block switches on its own.

## 11. New / changed components (with justification)

| Item | Kind | Why |
|---|---|---|
| `NowCard` | new feature widget, replaces `HeroCard` + `SunCard` | Contract item 1 (merge). Net file count −1. |
| `_HomeFlow` | replaces `_CardFlow` + `_EqualHeightPair` | New order and side column. Deletes a custom render object. |
| `WarningsSection` | new feature widget, extracted from `WarningsScreen` | Contract item 5: one component for the home block and the tab list. |
| `warningsView()` + `WarningsView` | new pure function + sealed type | One data path; removes the duplicate switches and filters. |
| `solarElevation()` | new pure function in `home_logic.dart` | The 仰角 now-mark needs data the API does not provide. |
| `MetricGrid(columns:)` | optional parameter on a shared widget | Eight tiles in 2 rows at every width; default behaviour unchanged. |
| `weatherGlyphStyle(night:)` | optional flag | Correct glyph on the night arc. |
| `_NowNote` | private to `now_card.dart` | Two notes at one level. One user, so not shared. |

No new tokens except `AppSize.metricMinTile = 64` (equal to `AppSize.icon64`; it is a separate name because it means something different).

## 12. Uncertain / for the merge round

- **Eyebrow warning badge.** It is my addition for safety, because moving warnings to the bottom hides a 大豪雨 on phones. It is removable without affecting anything else. The user should confirm it does not break 「特警報移到底部」.
- **Night arc direction.** The marker travels right → left below the horizon (west → under → east). This is physically correct, but the night part has no time labels. If users read it as 「time runs backwards」, the alternative is a static marker at the sunset end.
- **Elevation formula accuracy** (±0.5°) is enough for a whole-degree label. Not verified against CWA values.
- **After sunset the sun tiles still show today's times.** Tomorrow's sunrise appears only through the 日照 note's countdown. The old 「明天 日出 · 日落」 line is dropped.
- Label naming: the app uses 「警特報」 (`app_shell.dart:43`). The contract writes 「特警報」. The mockup follows the app.
