# 雨量 page — Designer 3：寬螢幕優先的自適應格線

Mockup: `rainfall.html` (same folder). Contract: `docs/logs/rainfall-page-contract.md`. Brief: `docs/design/rainfall/brief.md`.
Layout rules: `docs/design/adaptive/hazard.md`, `docs/design/adaptive/system.md`. Tokens: `lib/core/theme/app_tokens.dart`.

## 1. Design idea

- The five cards stay in the contract order and show directly (no tabs, no segmented control). The page is a plain `AppGrid` (`lib/core/layout/adaptive.dart:81`) whose cells are the five cards in DOM order, so a phone reads them top to bottom and a wide window re-flows the same cells.
- The three map cards are designed as **one comparison row**: 未來 1 小時預測, 小時累積, 日累積 sit side by side with equal width, so the eye compares "what will fall / what fell in 1 h / what fell today" without scrolling. Their cameras are linked by default on wide windows (pan or zoom one map, the other two follow).
- 最近測站 and 測站今日累積雨量 are full-row cells: the first becomes a horizontal strip on wide windows (number left, metrics middle, threshold bar right); the second uses its existing in-card grid (3 columns on wide).
- Each card owns its own data source state, so one failed source never blanks the page (frame C).

## 2. Layout per width

Cells passed to `AppPageScaffold.children` (`lib/core/widgets/page_scaffold.dart:17`):

```
[ if (noKey) AppGridItem.full(ApiKeyNotice) ,                // frame D: only this, no cards
  if (noPlace) AppGridItem.full(permission banner),
  AppGridItem.full(NearestStationCard),                      // 1
  AppGridItem(span: 1, ForecastMapCard),                     // 2
  AppGridItem(span: 1, HourlyRainMapCard),                   // 3
  AppGridItem(span: 1, DailyRainMapCard),                    // 4
  AppGridItem.full(StationListCard) ]                        // 5
```

`AppGrid.columnsFor` (`adaptive.dart:99`) uses `AppLayout.gridMinColumn` 340 (`app_tokens.dart:245`), so the column count follows the content width, never a ratio or width literal:

| Window | Content width | Columns | Row 1 | Row 2 | Row 3 | Row 4 |
|---|---|---|---|---|---|---|
| Phone 375 | 343 | 1 | 最近測站 | 預測 → 小時 → 日 (stacked, map 1:1) | — | 測站列表 |
| 1024 (frame H) | 912 | 2 | 最近測站 (full) | 預測 · 小時 | 日累積 (full, `AppTwoPane`: map left, legend + playback right) | 測站列表 (2 cols) |
| 1280 (frame G) | 1168 | 3 | 最近測站 (full strip) | 預測 · 小時 · 日 (map 5:6) | 測站列表 (3 cols) | — |

At 2 columns the 日累積 cell must be a full row (`AppGridItem.full`) so the third map is not orphaned. The screen picks the span from the same `columnsFor` call used by the grid: `columns == 2 → daily span = full`, otherwise span 1. Cards never scroll internally; the page scrolls (no `.fill` scaffold), same as `hazard.md` §2.

## 3. Card-by-card spec

| # | Card | Widget (file) | Change |
|---|---|---|---|
| 1 | 最近測站 | `ObservationHeroCard` (`lib/features/hazard/rainfall/observation_view.dart:17`) on `AppCard` (`lib/core/widgets/app_card.dart:15`); metrics `MetricGrid`/`MetricTile` (`lib/core/widgets/data_display.dart:138`); warning level `RainLevelBadge` (`lib/features/hazard/rainfall/level_style.dart:18`); threshold bar `_ThresholdBar` (`observation_view.dart:92`); thresholds `lib/features/hazard/rainfall/rainfall_logic.dart` | Keep the content. Add distance (km) to the meta line and past 1 h / 3 h as two `MetricTile`s (plus 「距大雨 N mm」 on wide). On a wide full-row cell the hero lays out as three columns with a `LayoutBuilder` on the card width (`cardWideWidth`), same pattern as `StationListCard`. |
| 2 | 未來 1hr 預測 | `ForecastMapCard` (`forecast_view.dart:113`) wrapping `RadarMapView` (`lib/features/radar/widgets/radar_map_view.dart:190`); value row = existing `ForecastHeroCard` content (`forecast_view.dart:35`) folded under the map; legend `_ForecastLegend` (`forecast_view.dart:195`); issue time in `AppCard.meta` and the map chip | Merge hero value into the map card as one 「此處」 row so each card = one question. No playback (single grid). 4-bucket legend unchanged (1–5 / 5–10 / 10–20 / ≥ 20 mm). |
| 3 | 小時累積雨量 | New thin `HourlyRainMapCard` (in `lib/features/hazard/rainfall/`), body = `RadarMapView` + compact playback + legend + observation time | Same shape as `RainfallMapCard` (`observation_view.dart:166`); overlay = past 1 h accumulation (contract layer 1). 30-minute frames driven by `PlaybackFrames` (`lib/features/radar/widgets/playback_card.dart:15`) and the existing radar playback state (`lib/features/radar/radar_playback.dart`). |
| 4 | 日累積雨量 | New thin `DailyRainMapCard` (same folder), same body as #3 | Replaces the JPG-based `RainfallMapCard`. Legend = 17 bands from `AppPalette.rainfallMapScale` (`app_tokens.dart:151`) drawn as a bar with numbers under 6 anchor values (<1, 10, 40, 90, 150, ≥300 mm). Frames from 00:00 to now, every 30 min. |
| 5 | 測站今日累積雨量 | `StationListCard` (`lib/features/hazard/rainfall/station_list.dart:20`), rows `AppList`/`AppListRow` (`data_display.dart:174`), county chips `AppChip` (`lib/core/widgets/choices.dart:9`) | Unchanged behaviour (in-card grid, collapsed 6 × columns, 「顯示全部」). Add the small per-row bar (`_LevelBar`, `station_list.dart:232`, already exists) — kept. |

Page shell: `AppPageScaffold` + `AppPageHeader` (`page_scaffold.dart:107`, title 「雨量」, subtitle 「臺北市 信義區 · 觀測 14:00」), source line via `SourceLine` (`page_scaffold.dart:208`). The threshold hint (大雨 80 / 豪雨 200 / 大豪雨 350 / 超大豪雨 500 mm) stays as the last full-row cell.

Remove: the `_RainView` enum and `AppSegmented` switcher in `lib/features/hazard/rainfall_screen.dart:25,45`.

## 4. States

| State | Where | Widget |
|---|---|---|
| Loading | Whole page: one `StatusBanner(loading)` then per-card `Skeleton` (`lib/core/widgets/status.dart:134`); map cards reserve their final aspect ratio so nothing jumps; playback row disabled | `StatusBanner` (`status.dart:11`), `Skeleton` |
| Error | **Per card**, inside the card: `StatusBanner(error)` + `RetryButton` (`status.dart:155`); map cards keep the muted base map and show the banner over it, siblings stay live (frame C) | `StatusBanner`, `RetryButton` |
| No API key | Replaces all cards with one `ApiKeyNotice` (`lib/core/widgets/api_key_notice.dart:11`, 「前往設定」) plus an `EmptyState` (`status.dart:78`) | `ApiKeyNotice`, `EmptyState` |
| No place / location denied | Permission `StatusBanner` on top (existing `_noPlaceBanner` in `rainfall_screen.dart`); 最近測站 shows a hint; forecast card hides the 「此處」 row; locate FAB disabled; the national maps and station list still render (they do not need a place) | `StatusBanner(permission)`, `AppButton` |
| No rain (all 0) | Cards say so in words (「目前測站沒有降雨」, chip 「過去 1 小時全臺無降雨」); maps stay on screen with the base map; playback still works | map chip (`_MapChip`, `radar_map_view.dart:398`) |

## 5. New components (justified)

1. **`CompactPlayback`** — an inline time row + prev / play / next + slider + 播放設定 button, for a map card. The existing `PlaybackCard` (`playback_card.dart:86`) is a full card with its own `AppCard`, `_Timeline` and `_Settings`; three of them (two on this page) would triple the vertical height. Proposal: extract `_TimeRow`, `_Controls`, `_Timeline` (`playback_card.dart:129,163,237`) into the body of a card-less `PlaybackBody`, then `PlaybackCard = AppCard + PlaybackBody + settings` and `CompactPlayback = PlaybackBody` (settings behind the options button, in a bottom sheet). One implementation, two shells; no duplicate playback logic.
2. **`RadarMapView` parameters** — `aspectRatio` (default 5:6 stays for the radar page; 1:1 on phone cards, 5:6 on wide columns), `interactive` (see §6) and an optional shared `MapController` (see §6). All additive; the radar page is unaffected.
3. **`HourlyRainMapCard` / `DailyRainMapCard`** — two thin cards over one private `AccumulationMapCard` (title, meta, map, `CompactPlayback`, legend). They differ only in source, frame list and legend. Not a new family of widgets.

No new colour, spacing or radius tokens. The mockup approximates the rain colour scales with `--dbz-*` tokens only because the real scale lives in Dart (`AppPalette.rainfallMapScale`).

## 6. Keeping three maps light, and the scroll / gesture conflict

Weight:
- **One tile source, one cache.** All three maps use the same OSM vector tiles; the tile cache is shared, so extra maps cost only the overlay image.
- **Lazy mount.** A map card builds its `RadarMapView` only when within one viewport of the scroll position and disposes it beyond two (phone: normally 1–2 live maps). Outside that range the card shows a `Skeleton` of the same size. On wide windows all three are on screen and live.
- **Overlay frames decode on demand.** Only the current frame plus the next `radarPreDecodeCount` frames are decoded (existing `RadarMapView.upcoming`, `radar_map_view.dart`); frames of the other two cards are not fetched until that card's playback is used. First paint shows only the latest frame.
- **Camera link (wide only).** One shared `MapController`/camera state drives all three maps, so one gesture moves three views of the same area (cheap: no extra fetch). A 「同步地圖」 toggle in card 2's header turns it off; default on at ≥ 2 columns, off on phone (one column, maps not visible together).
- Playback stays per card (two independent time axes: 1 h and the day). No shared cursor.

Scrolling with maps inside:
- **Phone:** each map starts **locked** (`interactive: false`): touches pass through to the page scroll, so a thumb on a map never traps the page. A lock button at the map's top-right unlocks pan / pinch for that map (`i-lock` in the mockup); it re-locks when the card scrolls out of view or on a second tap. The locate FAB still works while locked.
- **Wide (mouse / trackpad):** maps are interactive by default; wheel zoom needs Ctrl / ⌘ + wheel (plain wheel scrolls the page), drag pans. Touch-screen wide devices use the same lock button.
- Map height is bounded (1:1 on phone, 5:6 on columns), so a map can never fill the whole viewport; there is always page area to scroll from.

## 7. Open points for the owner

- 日累積 at 2 columns is a full-row `AppTwoPane`; if the owner prefers a strict 3-up row only at ≥ 1052 content width and a stacked column below it, drop that rule.
- Distance and past 1 h / 3 h on 最近測站 need fields the current `RainStation` model may not expose; if absent, show only 今日累積 and hide the two tiles (do not fake zeros).
- Frame lists for 小時累積 and 日累積 depend on the history research in the contract; with no history the card shows a single frame and a disabled playback row (state shown in frame B).
