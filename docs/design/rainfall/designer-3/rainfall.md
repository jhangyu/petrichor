# 雨量 page — Designer 3 v2：地圖並排、累積雨量合併

Mockup: `rainfall.html` (same folder; v1 kept as `rainfall.v1.html` / `rainfall.v1.md`). Contract: `docs/logs/rainfall-page-contract.md` (decisions 2–6). Brief: `docs/design/rainfall/brief.md`.
Layout rules: `docs/design/adaptive/hazard.md`, `docs/design/adaptive/system.md`. Tokens: `lib/core/theme/app_tokens.dart`.

## 1. Design idea

- Four cards in the contract order, shown directly (no tabs): 最近測站, 未來1hr預測, 累積雨量, 測站今日累積雨量. The page is a plain `AppGrid` (`lib/core/layout/adaptive.dart:81`) of `AppGridItem` cells (`adaptive.dart:59`) in DOM order.
- Design 3's idea is kept with two map cards instead of three: on wide windows 未來1hr預測 and 累積雨量 sit side by side with equal-height maps and linked cameras. On phone they stack and both maps start locked.
- 累積雨量 is one card: window selector → map → frame time + playback → legend → 播放設定. Hourly and daily cards, and calendar-day accumulation, are gone.
- Each card owns its own data state; one failed source never blanks the page.

## 2. Layout per width

```
[ if (noKey) AppGridItem.full(ApiKeyNotice) ]               // frame F: only this
[ if (noPlace) AppGridItem.full(permission banner) ]
AppGridItem.full(NearestStationCard)                        // 1
AppGridItem(span: 1, ForecastMapCard)                       // 2
AppGridItem(span: columns >= 3 ? 2 : 1, AccumulationCard)   // 3
AppGridItem.full(StationListCard)                           // 4
```

| Window | Content width | Columns | Row 2 |
|---|---|---|---|
| Phone 375 (frames A–H) | 343 | 1 | 預測 → 累積雨量 stacked, maps 1:1 |
| 1024 (frame J) | 912 | 2 | 預測 · 累積雨量, 1 column each, maps 5:6; the accumulation card stacks its parts vertically |
| 1280 (frame I) | 1168 | 3 | 預測 (1 column) · 累積雨量 (2 columns, `AppTwoPane`: map left, playback / legend / settings right); both maps are the same size so the linked cameras line up |

`AppGrid.columnsFor` (`adaptive.dart:99`) uses `AppLayout.gridMinColumn` (340, `app_tokens.dart:249`); the span of the accumulation card comes from that same call, never from a width literal. Cards never scroll internally; the page scrolls.

## 3. Card-by-card spec

| # | Card | Widget (file) | Change |
|---|---|---|---|
| 1 | 最近測站 | `ObservationHeroCard` (`lib/features/hazard/rainfall/observation_view.dart:17`) on `AppCard` (`lib/core/widgets/app_card.dart:15`); metrics `MetricGrid` (`lib/core/widgets/data_display.dart:141`); badge `RainLevelBadge` (`lib/features/hazard/rainfall/level_style.dart:18`); thresholds `rainfall_logic.dart` | Same as v1: distance in the meta line, past 1 h / 3 h tiles, 「距大雨 N mm」 on wide; three-column strip on a wide full row. 1 h / 3 h need fields `RainStation` may not expose: if absent, hide the tiles, never show fake zeros. |
| 2 | 未來1hr預測 | `ForecastMapCard` (`forecast_view.dart:113`) on `RadarMapView` (`lib/features/radar/widgets/radar_map_view.dart:190`); `_ForecastLegend` (`forecast_view.dart:195`); value row from `ForecastHeroCard` (`forecast_view.dart:35`) | Same as v1: hero value folded under the map as the 「此處」 row; 4-bucket legend; no playback. On wide it owns the 「同步地圖」 toggle (`i-link` in the mockup). |
| 3 | 累積雨量 | **New** `AccumulationCard` (`lib/features/hazard/rainfall/accumulation_card.dart`, new) over `AppCard`, `RadarMapView`, existing playback pieces (§4) | Replaces `RainfallMapCard` (`observation_view.dart:166`, JPG based; delete it with its tests). Body order: 時距選擇器, map, time row + playback, 17-colour legend, 播放設定. |
| 4 | 測站今日累積雨量 | `StationListCard` (`lib/features/hazard/rainfall/station_list.dart:20`), rows `AppList` (`data_display.dart:177`), county chips `AppChip` (`lib/core/widgets/choices.dart:9`) | Unchanged. |

Page shell: `AppPageScaffold` (`lib/core/widgets/page_scaffold.dart:17`) + `AppPageHeader` (`:107`) + `SourceLine` (`:208`). Remove the `_RainView` enum and the segmented switcher in `lib/features/hazard/rainfall_screen.dart:24`.

## 4. 累積雨量 card

### 4.1 Window selector — nine numeric chips, wrapped, label 「累積時距（小時）」

Options: 1 / 2 / 3 / 4 / 6 / 12 / 24 / 48 / 168 (decision 2). Widget: `AppChip` (`choices.dart:9`) inside a `Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8)` (`.chip-group`), exactly how the radar playback card lists 回看範圍 (`playback_card.dart:431-443`); the only differences are bare numbers and the unit moved into the field label.

Why this control:
- Fits 375 px: the card content is 311 px; a numeric chip is ~44 px (touch size), so the nine chips wrap into two rows (about 6 + 3). All nine are visible at once; nothing is hidden behind scrolling.
- `AppSegmented` (`choices.dart:68`) cannot hold nine segments at 311 px: the radar tab already limits it to five bare numbers (`playback_card.dart:447`).
- A dropdown or bottom sheet hides the options and costs two taps per change; users flip windows often to compare (3 h vs 24 h).
- A horizontal scroll row would hide 48 and 168 off-screen on phone.
- Wide: the same chips fit on one row.
Selecting a window is available even while loading or in error (it does not depend on data); it restarts the load for the new window.

### 4.2 Map, legend, frame time
- Map: `RadarMapView` with `overlayImages` = the accumulation grid coloured by `AppPalette.rainfallMapScale` (`app_tokens.dart:155`, 17 colours), no baked-in background. Chip on the map: 「過去 N 小時累積 · HH:mm」.
- Legend: 17-colour bar with six numbers under it (<1, 10, 40, 90, 150, ≥300 mm), title 「N 小時累積 mm」, as the scale comment in `app_tokens.dart` requires numbers. The mockup approximates colours with `--dbz-*` tokens only because the real scale lives in Dart.
- Frame time: time row 「11/15 14:00 · 第 k / n 張 · 每 10 分鐘」 (reuses `_TimeRow` text format, `playback_card.dart:129`). Frame count n = window × 6 + 1 (1 h = 7 frames, 168 h = 1009). Which frames to actually download, and the playback span, come from the strategy document (contract acceptance 1); the design only shows the 10-minute step.

### 4.3 Playback and where the settings live
Playback follows the radar tab (decision 4):
- Time row, prev / play / next, slider: from `PlaybackCard` pieces `_TimeRow`, `_Controls` (`playback_card.dart:129,163`), driven by `PlaybackFrames` (`playback_card.dart:15`) and `lib/features/radar/radar_playback.dart`.
- **播放設定** is the same collapsible panel as the radar tab (`_Settings`, `playback_card.dart:365`), placed directly under the slider inside the 累積雨量 card (frame B shows it open; others show it collapsed with the summary 「4 fps · 重複」). Contents, same as radar:
  - 播放速度（fps）: `AppSegmented<int>` over `radarFpsOptions` = 2 / 4 / 8 / 12 / 24 (`radar_playback.dart:5`), bare numbers.
  - 重複播放: `AppSwitch` (`choices.dart:142`) with the hint 「播放結束後等待 3 秒再重播」 (`radarRepeatPause`, `radar_playback.dart:30`).
  - 回看範圍 is left out: the window selector above the map replaces it.
- Persistence: `RadarFps` / `RadarRepeat` (`lib/features/radar/radar_provider.dart:52,68`) are keyed by `RadarGroup`; rainfall needs its own group value (new, see §6) so its settings are stored separately from the radar tab but behave identically.
- Wide (frame I): the right pane of the card holds time row, playback, legend, settings; the map is on the left.

## 5. States

| State | Where | Widget |
|---|---|---|
| Loading | Page: one `StatusBanner(loading)` + per-card `Skeleton`. The 累積雨量 card keeps its selector live, shows the muted map with a spinner chip, and a disabled playback row (frame C) | `StatusBanner` (`lib/core/widgets/status.dart:11`), `Skeleton` (`:134`) |
| Progressive loading (frame D) | First load of a long window (e.g. 24 h): the latest frame shows first; a loading banner has a progress bar 「已載入 38 / 145 張」 with an estimated time left; already-loaded frames can be played, playback at the loading edge shows 「緩衝中…」 (the radar card's `buffering` state, `playback_card.dart:154`); pending frame cells stay dimmed, failed ones red (radar `_TimelineFrame`, `playback_card.dart:298`) | `StatusBanner(loading)` + **new** `LoadProgressBar` (§6) |
| Error | Per card: `StatusBanner(error)` + `RetryButton` (`status.dart:155`); the accumulation map stays muted under the banner; partial failure (frame E, 6 frames missing) = `StatusBanner(permission)` with retry, playback skips the gaps | `StatusBanner`, `RetryButton` |
| No API key | Replaces all cards with one `ApiKeyNotice` (`lib/core/widgets/api_key_notice.dart:11`) + `EmptyState` (`status.dart:78`) | `ApiKeyNotice`, `EmptyState` |
| No place / location denied | Permission banner on top (`_noPlaceBanner`, `rainfall_screen.dart:55`); 最近測站 shows a hint; forecast hides the 「此處」 row and disables the locate FAB. 累積雨量 and the station list render normally (national data) | `StatusBanner(permission)` |
| No rain | Words, not an empty map: map chip 「過去 N 小時全臺無降雨」, cards say 0 mm; base map stays; selector and playback still work | map chip (`_MapChip`, `radar_map_view.dart:398`) |

## 6. New components (justified)

1. **`AccumulationCard`** (new, `lib/features/hazard/rainfall/accumulation_card.dart`): the one card of §4. It composes existing widgets; it replaces `RainfallMapCard` and the hourly / daily cards of v1.
2. **`PlaybackBody`** (new, extracted from `playback_card.dart`): the card-less time row + controls + slider + `_Settings`. `PlaybackCard` becomes `AppCard + PlaybackBody + opacity slot`, the accumulation card uses `PlaybackBody` directly. One playback implementation, two shells; no duplicated settings code.
3. **`LoadProgressBar`** (new, small): 4 px track (`AppSize.sliderTrack`) + brand fill + 「已載入 n / total 張」 text, for progressive loading. The radar tab loads ~144 frames quietly; a 168 h accumulation can take long enough that visible progress is needed.
4. **`RadarGroup.rainfall`** (new enum value in `radar_playback.dart:19`): separate defaults (fps 8) and storage for the rainfall page's fps / repeat, so no new setting classes are needed.
5. **`RadarMapView` parameters** (additive): `aspectRatio`, `interactive` (locked start) and an optional shared `MapController` for the camera link. The radar page is unaffected.

No new colour, spacing or radius tokens.

## 7. Keeping two maps light; scroll vs gesture

- One OSM tile source and cache for both maps; the second map costs only its overlay image.
- Lazy mount: a map card builds its `RadarMapView` within one viewport of the scroll position and disposes it beyond two. On wide windows both are visible and live.
- Frames decode on demand: only the current frame plus `radarPreDecodeCount` upcoming (`RadarMapView.upcoming`); the accumulation card fetches nothing beyond the latest frame until the user plays or scrubs, then follows the fetch strategy of the contract.
- Camera link (wide only): one shared camera drives both maps; the 「同步地圖」 toggle in the forecast card header turns it off; default on at ≥ 2 columns, off on phone.
- Phone: both maps start locked (`interactive: false`); the lock button at the top right unlocks pan / pinch for that map, re-locks when it scrolls away. Wide: drag pans, wheel zoom needs Ctrl / ⌘. Map height is bounded (1:1 phone, 5:6 wide), so a page scroll area always exists.

## 8. Open points

- Playback span per window (how many of the 1009 frames of 168 h are really fetched and played) and the progress / time-left numbers depend on the strategy document; the mockup shows 38 / 145 and 「約剩 20 秒」 as examples only.
- Progressive loading order (newest first) is a design assumption the fetch strategy must confirm.
- 最近測站 1 h / 3 h and distance fields: see §3 row 1.
- Frame-width literals in the mockup (375 / 1024 / 1280 px) are presentation-only document frames inherited from v1.
