# 天氣 tab — Designer 4：資訊層級

Mockup: `home.html` (same folder). Contract: `docs/logs/home-page-contract.md`. Brief: `docs/design/home/brief.md`.
Inputs read: `lib/features/weather/**`, `lib/features/hazard/warnings*`, `lib/core/widgets/**`, `lib/core/theme/app_tokens.dart`, `docs/design/adaptive/weather.md`, and the plans `arch-solar.md`, `arch-forecast.md`, `arch-warnings.md`, `code-warnings.md`.

## 1. Design idea

The page answers three questions in order: **what is it like now → what is coming → is anything dangerous**. Each question is one block; inside a block, items are grouped by meaning, not by data source.

The merged 「現在」 card has four layers, top to bottom:

1. **Sky** — the sun arc with the current weather glyph riding the sun's position. One glance gives the condition and the time of day.
2. **Temperature** — display-size temperature, condition text, today's high/low.
3. **Two labelled tile groups** — 「體感與環境」 (體感 / 濕度 / 風 / 降雨機率) and 「太陽」 (曙光 / 日出 / 日落 / 暮光, in time order). The group label carries the meaning, so tiles stay short. The 太陽 label also carries the day length (「白晝 10 小時 51 分」), which keeps that value from the old SunCard without a ninth tile.
4. **One callout list** — 天氣建議 and 日照 (the sun-status line) as two rows of one bordered list. Both are sentences, so they read as notes, not as numbers.

Hierarchy inside the 太陽 group: the **next** sun event is highlighted (brand-subtle tile, label 「日落 · 下一個」); passed events have a muted value (fg3). After sunset the 日出 tile shows **tomorrow's** sunrise, labelled 「明天日出」 (resolves `arch-solar.md` §8 item 2).

## 2. Page order and shell

| # | Block | Widget | Change |
|---|---|---|---|
| — | App bar | `AppPageHeader` (`page_scaffold.dart:107`) | unchanged (`weather_screen.dart:50-64`) |
| — | Pull hint / loading pill | `_PullHint` (`weather_screen.dart:327`) | unchanged |
| 1 | 現在 | new `NowCard` (replaces `HeroCard` + `SunCard`) | §3 |
| 2 | 7 日預報 | `WeeklyCard` (`weekly_card.dart:16`) | unchanged; moved before 72h |
| 3 | 未來 72 小時預報 | `Forecast72hCard` (`forecast_72h_card.dart:18`) | unchanged; separate card (§6) |
| 4 | 特警報 | `WarningsSection` (`arch-warnings.md` §3) | moved from top banner to bottom; §7 |
| — | Source line | `SourceLine` (`page_scaffold.dart:208`) | adds W-C0033-001/002 whenever warnings are `Success` (also the empty hero) |

The top warning banner (`weather_screen.dart:141`, `:163-208`) is deleted.

## 3. 現在 card (NowCard) — widget map

Frame: `AppCard(hero: true)` (`app_card.dart:15`). Data: `current` (O-A0003-001), current forecast slot (F-D0047-061, for 體感 / 降雨機率 / 天氣建議), `sun` (A-B0062-001), computed elevation (`arch-solar.md` §3.2).

| Part | Widget | Notes |
|---|---|---|
| Head row | `Row[Text(caption1 fg3), ?AppBadge]` | 「即時觀測 14:10 · 臺北測站 1.2 km」. The station name and distance come from `CurrentWeather.stationName / distanceKm` (`weather_models.dart:8,15`). Optional badge, see §7.3. |
| Sun arc | `_SunArcPainter` (`sun_card.dart:158`), reworked | §4. Weather glyph = `WeatherGlyphIcon` (`weather_glyph_icon.dart:19`) in a `Positioned` over the `CustomPaint`, at the painter's sun point. |
| Temperature | `Text(AppType.display)` + condition `subtitle1` + `_hilo` (`hero_card.dart:67-68`) | unchanged styles from `HeroCard`; the 64-px glyph beside the temperature is removed (the glyph is on the arc now). |
| Tile group | page-local `_TileGroup(label, meta?, tiles)` = `Column(spacing: s8, [Row(label caption1 semibold fg2, meta caption1 fg3), MetricGrid])` | `MetricGrid` (`data_display.dart:141`) unchanged: 2 columns, 4 in a row from `AppLayout.cardWideWidth`. |
| Comfort tiles | `MetricTile(onHero: true)` × 4 (`data_display.dart:90`) | same values and icons as `hero_card.dart:84-107`. |
| Sun tiles | `MetricTile(onHero: true)` × 4 | icons: dawn / sunrise / sunset / dusk. Values `clockText(...)`. New optional `MetricTile.tone` (§8): `next` = brand-subtle bg + brand-fg-strong label; `past` = fg3 value. |
| Callout list | page-local `_Callouts(items)` | `Container(bg1, stroke3 border, radius small)` + rows `Row(icon20, Column[label caption1 semibold fg3, text body1 fg1])`, divider stroke3. Rows: 天氣建議 (umbrella, rainFg) = `slot.description` verbatim (today `HeroCard._summary` strip, `hero_card.dart:114-129`; rain tint dropped so both notes share one neutral style); 日照 (schedule, brandFg) = sun-status line (`sunNowLine`, `home_logic.dart:145-155`, moves into the new model per `arch-solar.md`). |

Spacing: card gap s16 (AppCard); arc → temperature s8; group label → grid s8; group → group s16; callout row padding s12.

Phone (375): card content width 311 → tiles 2 × 2 per group (151 each), arc 311 × 144.
Wide (card content ≥ 520): temperature block left, arc right (`Row` of two `Expanded`, like `SunCard._card` LayoutBuilder); each group 4 tiles in one row.

## 4. Sun arc at 375 px — readability rules

- View box 320 × 148 (was 288 × 112): horizon at y 108, ellipse rx 124 / ry 84, 24 px headroom for the transit label, 40 px below the horizon for the night position. Scaled to the card width, capped at 360 (`_arcMaxWidth`, `sun_card.dart:30`). At 375 the scale is 0.97, so geometry stays as drawn.
- **Labels are painted unscaled** (`paintLabel` after `canvas.restore`, positions transformed by the scale): caption1 12 px at every width. Only **two** labels on the arc: 「過中天 11:38」 above the transit point and 「仰角 33°」 beside the glyph. All other times moved to the tiles, which removes today's 5-label crowding.
- Elevation label side: outside the arc, on the side away from the transit (right of the glyph when the sun is past transit, left before it). When the sun is within ±0.12 day-fraction of the transit, the two labels merge into one above the glyph: 「過中天 11:38 · 仰角 47°」.
- Glyph: 24 px icon on a 34 px white disc with a 2 px sun-colour ring (on the arc the ring separates the glyph from the solid path). Path: solid sun colour from sunrise to now, dashed stroke-1 for the rest; twilight dashes below each end as today.
- Night (`phase != daytime`): the whole day path is dashed; a bg-4 band (60 %) fills below the horizon; the glyph moves along a short dashed return curve under the horizon from sunset (right) to sunrise (left) by night fraction (sunset → next sunrise); label 「仰角 −62°」 to its left. Before sunrise the same rule applies from the previous sunset. The glyph is never drawn above the horizon at night.
- Observation failed but sun data OK: plain sun dot (as today, `sun_card.dart:236`) instead of a glyph; arc stays.
- Semantics: one label on the arc, e.g. 「太陽位置：目前仰角 33 度，過中天 11:38，現在多雲時晴」. Times are in the tiles' own semantics.
- Values: elevation computed (`arch-solar.md` §4.1); 過中天 time from CWA. The transit altitude (`transitAltitudeDegrees`) only appears in the merged label near transit.

## 5. States (frames in home.html)

| Frame | State | Rendering |
|---|---|---|
| A | Daytime, active warnings | full page; next tile 日落; badge 「特警報 2」 in the now-card head |
| B | Night, no warnings in county | glyph below horizon; 日出 tile → 明天日出 (next); WarningsSection empty hero, chips 我的縣市 0 / 全部 2 |
| C | Loading | `AppCard.loading(hero: true)` with skeleton blocks of the data height; 7 日 / 72h loading cards; WarningsSection hero skeleton (today home shows nothing while warnings load) |
| D | Partial failure | observation failed, sun OK → arc (sun dot) + inline `StatusBanner(error)` in place of temperature and comfort tiles + 太陽 group + 日照 note; 72h `AppCard.error`; warnings `StatusBanner(error)` with 「這不代表目前沒有警特報」 |
| E | No API key | **one** `ApiKeyNotice` (`api_key_notice.dart:11`) for the whole page + `EmptyState`; no per-card notices |
| F | No place / location denied | `_NoPlaceGuide` (`weather_screen.dart:370`) only; no WarningsSection (no county) |
| G | Explored merged forecast | not adopted (§6) |
| W | Wide 1280 | §9 |

Divergences from `arch-solar.md` §5 (for the merge step):
- D: arch-solar replaces the whole card with `AppCard.error` when the observation fails. I keep the sun part: its data is valid and independent (separate dataset, separate Result), so dropping it hides good data. Precedence then becomes: both failed → `AppCard.error`; one failed → inline error block for that half.
- E: arch-solar keeps a per-card `ApiKeyNotice`. Every dataset uses the same token (`Failure.apiKeyIssue`, `weather_repository.dart:71-73`), so five identical notices say nothing new. `WeatherScreen` shows one notice when any `Result` is `Failure(apiKeyIssue)` and builds no cards. Same point is in `arch-warnings.md` §7 parking lot.

## 6. 7 日 vs 72 小時 — decision: keep separate

Contract item 4 allows a merge only if both carry the same level of information. They do not:

1. **Granularity** — 7 日 = one row per day (max/min, day 降雨機率, one glyph; `weather_models.dart:145-158`). 72 小時 = 3-hour slots with temperature curve, 體感 curve, 降雨機率 per slot and wind (`forecast_72h_card.dart:5-7`, `weather_models.dart:109-128`).
2. **Horizon** — 72 h covers today…後天 (+ part of day 4); days 4–7 have no hourly data. A merged card has two kinds of rows: frame G shows 週三 with 「沒有逐時資料，無法展開」.
3. **Different products, can disagree** — the day row (F-D0047-063 max/min) and its expanded hours (F-D0047-061) come from two datasets with two issue times and independent failures (`weather_provider.dart:67-73`). Inside one row this shows up as a contradiction.
4. **The chart is the value of the 72 h card** — a day selector shows one day of 8 slots; the cross-midnight trend (the cold front on 11/16 06:00) and the 體感/wind rows disappear. Frame G shows how little of it fits in a row.

I explored the direction's idea (frame G: tap a day row → 3-hour strip) and rejected it for these reasons. Outcome: `WeeklyCard` second, `Forecast72hCard` third, both unchanged. This matches `arch-forecast.md` §2 option A.

## 7. 特警報 — WarningsSection at the bottom

### 7.1 Component and data path
One shared widget, `WarningsSection(county, now)` (`arch-warnings.md` §3, option B): the former 警特報 tab body moves into the bottom of 天氣; the tab, `WarningsScreen` and the home banner are deleted. One provider (`activeWarningsProvider`, `hazard_provider.dart:11`), one clock (`weatherClockProvider`), one place gate (`WeatherScreen`). Bottom navigation has 4 tabs in every frame (天氣 / 雷達 / 雨量 / 設定).

| Part | Widget |
|---|---|
| Header | `SectionHeader(title: '特警報 · 臺北市', trailing: '更新於 14:05')` (`app_card.dart:176`) |
| Summary | `WarningsHero` (`warnings_hero.dart:11`) county label; empty variant = success style |
| Scope | `AppChip` × 2 (`choices.dart:9`): 「我的縣市 臺北市 N」 (default) / 「全部 M」 |
| List | `WarningCard` (`warning_card.dart:15`), first open; `AppGrid.columnsFor` columns from the section width |
| 查看雨量 | in `WarningCard` → `AppTab.rainfall` (unchanged) |

### 7.2 States
Loading → hero skeleton; error → `StatusBanner(error)` + 「這不代表目前沒有警特報」 + 重試; API key → covered by the page-level notice (§5 E); empty county with warnings elsewhere → empty hero, foot 「其他縣市有 2 項，切換到「全部」查看 · 最近檢查 21:35」 (frame B); empty everywhere → empty hero, foot 「最近檢查 HH:mm」.

### 7.3 Top-of-page cue (needs a user decision)
Frames A and W put a small `AppBadge(tone: alert-N, icon: warning)` 「特警報 2」 in the now-card head when the county has active warnings; tap scrolls to the section (`Scrollable.ensureVisible`). It renders no warning content, only a count and a link, so it is not a second implementation. Reason: on a phone the section sits about 3 screens down; a 大豪雨 warning should not depend on scrolling. `arch-warnings.md` §7 adds no cue. If the user wants strict 「bottom only」, delete the badge; nothing else changes.

## 8. New or changed components (justification)

| Component | Kind | Why |
|---|---|---|
| `NowCard` | new, replaces `HeroCard` + `SunCard` | contract item 1. Both old files are deleted. |
| `_TileGroup` | private to `NowCard` | the direction's grouping; a label row + existing `MetricGrid`. Not shared: no other screen groups tiles. |
| `_Callouts` | private to `NowCard` | two sentence notes in one list. `AppList`/`AppListRow` do not fit: they are shadowed white groups with a bold one-line primary; these rows are caption label + wrapping body text on the hero background. Replaces `HeroCard._summary` and the sun now-line row. |
| `MetricTile.tone` | new optional enum param `{normal, next, past}` on the shared tile | marks the next / passed sun events. Default `normal` keeps every existing caller unchanged. If rejected, drop it; tiles still read correctly in time order. |
| Arc painter | reworked `_SunArcPainter` | glyph position, elevation label, night return curve, unscaled labels (§4). |
| Page-level `ApiKeyNotice` | logic in `WeatherScreen` | §5 E. |
| `WarningsSection` | new shared, from `WarningsScreen` | contract item 5; `arch-warnings.md`. |

No new tokens. All colours: `brand-160` hero gradient, `icon-sun`, `icon-cloud`, `stroke-1/2/3`, `bg-4`, `brand-bg-subtle`, `brand-stroke-subtle`, `rain-fg`, alert / success / info sets — all exist in `app_tokens.dart`.

## 9. Wide layout (≥ 1024)

`_CardFlow` (`weather_screen.dart:214`) changes to:

| Columns (`AppGrid.columnsFor(width, spanUnits: 2)`) | Arrangement |
|---|---|
| 1 | now, 7 日, 72 h, warnings stacked |
| 2 | `_EqualHeightPair[now, 7 日]` (`weather_screen.dart:259`, reused), then 72 h full width (chart fits, no scroll), then WarningsSection full width (cards 2 columns) |

At 1280 (rail 80, content ≈ 1160): now card and 7 日 ≈ 572 each; now-card content ≈ 540 ≥ `cardWideWidth` → temperature beside arc, 4 tiles per row. The 7 日 card is shorter than the now card and gets bottom space from the equal-height pair (accepted; same rule as today's hero | sun pair).

## 10. Uncertain / for the lead

1. §7.3 badge cue vs contract 「bottom」 — user decision.
2. §5 D/E diverge from `arch-solar.md` §5; the merge step must pick one precedence.
3. `MetricTile.tone` touches a shared widget; optional.
4. Night glyph uses the day weather glyph (no moon icon exists in `weatherGlyphStyle`, `weather_glyph_icon.dart:7`); a night variant was not added.
5. Sample data is realistic but invented (Taipei 2026-11-15: transit 11:38 from the fixture date range; elevation 33° at 14:10 and −62° at 21:40 computed by hand, ±1°).
