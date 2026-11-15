# 天氣 tab — Designer 1：太陽弧為主角（arc-as-hero）

Mockup: `home.html` (same folder). Contract: `docs/logs/home-page-contract.md`. Brief: `docs/design/home/brief.md`.
Plans this design follows: `arch-solar.md` (now card data and states), `arch-forecast.md` (7日 / 72小時), `arch-warnings.md` (shared warnings section).
Tokens: `lib/core/theme/app_tokens.dart`. Layout: `docs/design/adaptive/system.md`, `adaptive/weather.md`.

## 1. Design idea

- One hero card answers "what is it like now, and where is the sun". A large sun arc spans the card top. The current weather glyph and the current solar elevation sit in **one pill** that rides the arc at the sun's position. The temperature sits inside the dome.
- Below the arc: **two rows of 4 tiles** with a fixed meaning per row. Row 1 = comfort (體感 / 濕度 / 風向 / 降雨機率). Row 2 = sun times in time order (曙光 / 日出 / 日落 / 暮光).
- Two notes of the same level, same widget and same style: 天氣建議 (today's HeroCard summary strip) and the sun-status line (`home_logic.dart:145-155`).
- Then 7 日預報 → 未來 72 小時預報 (kept separate) → 警特報 (the shared section, last).

## 2. Page order and frames

| # | Block | Widget |
|---|---|---|
| 0 | Pull hint / loading pill | `_PullHint` (`weather_screen.dart:327`), unchanged |
| 1 | Now card (merged) | new `NowCard` in `lib/features/weather/widgets/now_card.dart`; replaces `HeroCard` and `SunCard` (both deleted) |
| 2 | 7 日預報 | `WeeklyCard` (`weekly_card.dart`), unchanged |
| 3 | 未來 72 小時預報 | `Forecast72hCard` (`forecast_72h_card.dart`), unchanged |
| 4 | 警特報 | `WarningsSection` (`arch-warnings.md` §3), the same widget the 警特報 page uses |
| 5 | Source line | `SourceLine` (`page_scaffold.dart`), adds W-C0033-001/002 whenever the warnings fetch succeeded (the 「無警特報」 hero is data too) |

The top-of-page warning banner (`_warningEntry`, `weather_screen.dart:163-208`) is deleted.

Mockup frames (phone 375 px): A 白天＋生效中警特報 · B 夜間＋無警特報 · C 載入中 · D 錯誤 · E 沒有 API 授權碼 · F 沒有地點／定位被拒 · arc strip (4 moments) · G wide 1280 px.

## 3. Now card — card by card mapping

| Part | Widget | Spec |
|---|---|---|
| Card | `AppCard(hero: true)` (`app_card.dart`) | brand-160 → bg-1 gradient, shadow-8, gap s12; unchanged hero look day and night (dark theme out of scope) |
| Eyebrow | `Row`: `Text` caption1 fg3 tabular 「即時觀測 14:10 · 臺北測站」 + optional jump badge | observation time stays here (moved from `hero_card.dart:46`) |
| Jump badge (optional) | `AppBadge(tone: alert1..4, icon)` inside `InkWell`, tap target ≥ `AppSize.touch` | only when the user's county has an active warning: 「大雨特報 ⌄」 → `Scrollable.ensureVisible` on the warnings section key. Not a second warnings block; one line. Remove if the user wants zero warning UI at the top |
| Sun arc | new `SunArc` (`CustomPaint`) in `now_card.dart`; reuses `dashedPath`, `paintLabel` (`chart_paint.dart`) | see §4 |
| Temperature in the dome | `Text` `AppType.display` tabular, `height: 1`; below it 天氣現象 body1 fg2 + 「高 24° 低 19°」 caption1 (tempHot / tempCold) | `Positioned` in a `Stack` over the arc, centred, bottom at 26 % of the arc box (= 8 view units above the horizon) |
| Tiles | `MetricGrid(columns: 4)` of `MetricTile(dense: true)` (`data_display.dart:90-171`) | two grids: comfort row, sun row. See §5 |
| Notes | new `NoteCallout(icon, text)` ×2, identical style | 天氣建議 = `slot.description` verbatim (moved from `hero_card.dart:114-129`); sun note = `SunNow.note(now)` (`arch-solar.md` §3.3) |

Removed vs today: 白晝長度, tomorrow's sunrise/sunset line (`sun_card.dart:66, 135-149`), the 降雨機率 badge in the hero eyebrow (`hero_card.dart:50`, duplicate of the tile). The sun note carries the next event (「距日落 2 小時 56 分」 / 「已日落，距明天日出 8 小時 36 分」).

### Wide interior (card content ≥ `AppLayout.cardWideWidth` 520)
`Row`: arc (max 360, left) | `Column(tiles row 1, tiles row 2, notes)` (right), `crossAxisAlignment: center`, gap s24. Same rule as today's SunCard (`sun_card.dart:94`). Tiles stay 4 columns, they only get wider.

## 4. Sun arc — geometry and how it stays readable at 375 px

View box 320 × 200, scaled to the arc box width (`AspectRatio(320/200)`, max width 360). At 375 px the card content is 311 → scale 0.97, so 12-unit labels render ≈ 11.7 px (caption1).

| Element | Geometry (view units) | Style (tokens) |
|---|---|---|
| Horizon | y 156, x 4–316 | `stroke1`, 1.5 |
| Day dome | half ellipse, centre (160, 156), rx 136, ry 120 | elapsed: `iconSun` 3; remaining: `stroke1` 2, dash 4/4. After sunset: all dashed |
| Night arc | half ellipse below the horizon, same rx, **ry 24**, sunset (right) → next sunrise (left) | before/after: `stroke2` 1.5 dash 2/4; elapsed part at night: `brand120` 2.5 |
| Sunrise / sunset points | dome ends | ring r 4, `bg1` fill, `fg3` edge. No time labels (times are tiles) |
| 東 / 西 | caption2 fg3 just above the horizon at the ends | hidden when the pill covers that end |
| 過中天 mark | tick + ring r 3 at the apex; label row y 0–16: 「過中天 11:39 · 最高 47°」 | label row is reserved: nothing else is drawn there |
| Pill (now) | 66 × 30, r 15, centre = sun position; glyph 20 (`WeatherGlyphIcon`) + elevation 「33°」 / 「−61°」 body1 semibold | day: `bg1` fill, `iconSun` edge; night: `stroke1` edge, `fg2` text. A dot r 5 marks the exact position under the pill |

Position: day = `arcFraction` along the dome; night = `arcFraction` along the night arc (`arch-solar.md` §4.2). Today the sun data covers today + tomorrow only; the night arc before sunrise needs yesterday's sunset, so it depends on arch-solar §3.1 extending the fetch to [昨天, 今天, 明天]. Without that, before-sunrise has no start point and must show the sun error (no approximated value). Elevation = `solarElevationDegrees` rounded (`arch-solar.md` §3.2); CWA gives only the transit altitude.

Readability rules (verified in the "four moments" strip of the mockup):
1. **One moving object.** Glyph and elevation are one pill, so there is no label-placement logic: no leader lines that cross the arc, no flipping sides.
2. **Clamp.** The pill centre is clamped to x ∈ [41, 279]. Near sunrise / sunset the pill stops inside the box and a 1-unit leash line joins it to the sun dot (16:58 example).
3. **Reserved top row** for the 過中天 label; at the apex the pill top is at y 21, below the label row (11:39 example).
4. **Temperature inside the dome only where the dome is tall.** Temperature block ≈ 95 units high, ≤ 160 units wide at its weather line; the pill passes over it only on the outer edge (8:30 and 14:10 examples keep ≥ 6 units clear).
5. Night arc depth 24 keeps the whole sky at 200 units (≈ 194 px at 375): the card does not grow at night.
6. Semantics: one label for the whole arc: 「太陽位置：現在仰角 33 度，白天；過中天 11:39，最高仰角 47 度；目前天氣多雲短暫雨」 (painter is excluded from semantics, like `sun_card.dart:50-58`).

Night glyph: `WeatherGlyphIcon` gets a `night` flag (phase ≠ daytime). Buckets `sun` → moon, `partly` → moon-partly; others unchanged. Reason: a sun glyph on the night arc reads as wrong. This adds two icons to `weatherGlyphStyle` (`weather_glyph_icon.dart`), nothing else.

## 5. Tiles

`MetricGrid(columns: 4)`: today the grid is 2 columns or all-in-one-row (`data_display.dart:141-171`). Add an optional `columns` parameter (fixed count); default behaviour unchanged for other callers.

`MetricTile(dense: true)`: label (caption1 fg3) above value (body1Strong fg1 tabular), no icon, padding s8, on-hero style (bg1 + stroke3). Reason: at 375 px a tile is (311 − 3·8) / 4 = 71.75 wide, 55.75 inside. The current tile (icon 20 + s8 + s12 padding) leaves 19 px for text, so it cannot hold 「降雨機率」 (48 px). Dense mode is a variant of the existing tile, not a new component.

| Tile | Value | Source |
|---|---|---|
| 體感 | `tempText(slot.apparentTemperature)` | F-D0047 slot covering now |
| 濕度 | `${humidity}%` | O-A0003-001 |
| 風向 | 「東北3級」: `observedWindLabel` + Beaufort scale from `windSpeed` | O-A0003-001. New pure `beaufortScale(double mps)` in `home_logic.dart` (CWA table 0–17). 「東北 4 m/s」 does not fit 55 px; 級 is how CWA states wind in its own text (see 天氣建議). m/s goes into the tile's semantics label |
| 降雨機率 | `percentText(slot.pop)`; `rainFg` semibold when ≥ `rainLowThresholdPercent`, fg3 regular below | slot |
| 曙光 / 日出 / 日落 / 暮光 | `clockText(SunNow.day.civilDawn / sunrise / sunset / civilDusk)` | A-B0062-001, today's date. At night the tiles keep today's times; tomorrow's sunrise is in the sun note |

Missing value → 「—」 (existing `tempText` / `percentText` behaviour).

## 6. Notes — `NoteCallout` (new, justified)

`lib/core/widgets/status.dart`: `NoteCallout({required IconData icon, required String text})`. Row(icon 20, s8, `Expanded(Text body1)`), padding h s12 v s8, radius small, `rainBg` / `rainFg` — exactly today's `HeroCard._summary` (`hero_card.dart:114-129`). Both notes use this one style; only the icon differs (天氣建議: umbrella; sun note: sun by day, moon at night).

Why new: contract item 3 makes the sun line "a note at the same level as 天氣建議". Same level = same widget. Today's 天氣建議 is a private method; making it shared is the minimum. `SettingsNote` (`settings_parts.dart:83`) is a caption1 footnote without a container, a different role, so it is not reused.

## 7. 7 日預報 / 72 小時 — decision: keep separate, 7 日 first

Not merged. The two cards carry different levels of information:
1. Granularity: 7 日 = one row per day (low–high range, 12-hour PoP, one glyph). 72 小時 = 3-hour slots with a temperature curve, 體感 line, PoP bars and wind. A merged card must hide one level behind a tap.
2. Horizon: days 3–6 have no hourly data, so a merged card would have two kinds of rows.
3. Two datasets, two issue times, independent failures (frame D: 72 小時 fails while 7 日 shows). One merged card would need two error states inside one card.
4. Evidence and full analysis: `arch-forecast.md` §1–2 (Option A). This design uses Option A unchanged.

Order change only: `_CardFlow` (`weather_screen.dart:214-255`) becomes `[now, weekly, forecast]`; on ≥ 3 grid columns the second row is weekly (2 parts) | forecast (3 parts), weekly on the left (reading order). Both cards are unchanged inside.

## 8. 警特報 — bottom of the page, shared with the 警特報 page

`WarningsSection(county, now)` from `arch-warnings.md` §3 (new `features/hazard/warnings/warnings_section.dart`), reused unchanged: `WarningsHero`, `WarningCard`, `WarningLevelStyle`, `groupWarnings`, `groupsForCounty`.

| Part | Widget |
|---|---|
| Header | `SectionHeader(title: '警特報', trailing: 「更新於 08:30」 caption1 fg3)` |
| Scope | `AppChip` 「我的縣市 臺北市」 (default on home) / 「全部 2」 |
| Summary | `WarningsHero` (county variant; empty variant 「臺中市目前無警特報」 with foot 「其他縣市有 2 項警特報，切換到「全部」查看。」) |
| List | `SectionHeader(county, 「1 項」)` + `WarningCard` grid, first card open |

States (frames A, B, C, D): active → hero + cards; none → success hero; loading → `AppCard.loading(hero: true)`; error → `StatusBanner` 「無法取得警特報」 + 「這不代表目前沒有警特報。」 + 重試, never the empty hero.

Tab question (keep the 警特報 tab or remove it, `arch-warnings.md` §2): this design works either way because the section is the same widget. The mockup's bottom bar still shows 5 tabs; with Option B it shows 4 and nothing else on this page changes.

## 9. Page states

| State | Rendering | Frame |
|---|---|---|
| Loading | pull pill 「載入天氣資料…」; now card skeleton keeps the arc box (320:200) + 2 tile rows + 2 note bars; 7 日 / 72 小時 skeletons at their data heights (424 / 456, unchanged); warnings hero skeleton | C |
| Observation failed | `AppCard.error('無法取得目前天氣')` replaces the now card (`arch-solar.md` §5) | — (same banner as 72 小時 in D) |
| Sun data failed, observation OK | no arc, no sun tiles, no sun note; temperature row in flat form (display temp + 64 glyph, like today's hero); one inline `StatusBanner(error)` 「無法取得日出日落資料」 with the message and 重試; comfort tiles and 天氣建議 stay | D |
| Forecast / warnings failed | each card / section shows its own error and retry | D |
| No API key | **one** `ApiKeyNotice` for the page + `EmptyState` 「天氣資料需要授權碼」 | E |
| No place / permission denied | `_NoPlaceGuide` (`weather_screen.dart:370`), unchanged | F |
| Night | dome dashed, glyph pill on the night arc, negative elevation, moon icons | B |
| Day | elapsed dome in `iconSun`, pill on the dome | A |

**Differs from the plans:** `arch-solar.md` §5 and `arch-warnings.md` §4 keep one `ApiKeyNotice` per card. All five datasets use the same token, so a missing token produces 4–5 identical red banners. Proposal: `WeatherScreen` checks `WeatherState` + warnings for any `apiKeyIssue` first and renders a single notice (frame E). This is one `switch` in the screen, no new widget.

## 10. Adaptive

| Columns (`AppGrid.columnsFor`) | Arrangement |
|---|---|
| 1 (phone) | now → 7 日 → 72 小時 → 警特報 |
| 2 | now (full) → 7 日 (full) → 72 小時 (full) → 警特報 (full) |
| ≥ 3 (G, 1280) | now (full, wide interior) → 7 日 (2) \| 72 小時 (3) → 警特報 (full, cards in `AppGrid` columns) |

The equal-height pair (`_EqualHeightPair`, `weather_screen.dart:259-324`) is no longer needed (hero and sun are one card) and is deleted.

## 11. New or changed components (summary)

| Item | Kind | Why |
|---|---|---|
| `NowCard` + `SunArc` painter | new feature widget, replaces 2 cards | contract item 1 |
| `MetricGrid.columns`, `MetricTile.dense` | parameters on existing widgets | 8 tiles in a fixed 4×2 at 311 px |
| `NoteCallout` | new shared widget (moves `HeroCard._summary`, one style) | contract item 3: same level = same widget |
| `WeatherGlyphIcon.night` + moon / moon-partly icons | parameter + 2 icons | glyph rides the night arc |
| `beaufortScale` | pure function | wind fits a 55 px tile |
| Jump badge | existing `AppBadge` + `InkWell` | optional; keeps an active warning visible at the top without a second block |

## 12. Open items

- Jump badge in the eyebrow: keep or drop (contract item 5 says the warnings block moves to the bottom; the badge is one line, not a block).
- Wind as Beaufort 級 vs m/s: 72 小時 chart still shows m/s (`forecast_72h_card.dart:489`). If the user wants one unit everywhere, change the chart too.
- Single page-level `ApiKeyNotice` (§9) differs from both architecture plans.
- Tiles show today's sun times at night; an alternative is to switch row 2 to tomorrow after sunset (adds a 「明天」 label).
