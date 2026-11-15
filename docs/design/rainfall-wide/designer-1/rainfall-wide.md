# 雨量 wide layout — proposal 1 (designer-1)

Mock: `rainfall-wide.html` (A: normal 1280 px, B: states). Contract: `docs/logs/rainfall-wide-layout-contract.md` (user decision: sizes follow the radar page).
Idea: each map section is the radar's wide layout, copied value for value: `AppTwoPane(main: map card, side: control card)`. Sections stacked one per row. The page stays the only scroller.

## 1. Radar values reused (all cited)
| Value | Radar | Rainfall wide |
|---|---|---|
| Wide test | `radar_screen.dart:164-166`: `usesRail && !isShortHeight && AppTwoPane.fits(w - 2*pageMargin)` = width ≥ 600, height ≥ 480, content ≥ 2×320+16 = 656 (`adaptive.dart:161`, `app_tokens.dart:239,242,270`) | same; extract as one function in `adaptive.dart`, both pages call it. Rainfall now tests only `fits(box.maxWidth)` (`rainfall_screen.dart:262`) |
| Side width | content × 0.4, clamp 320–480 (`adaptive.dart:167-168`, `app_tokens.dart:270-272`) | same (`AppTwoPane` itself) |
| Gap map ↔ side | 16 (`adaptive.dart:172`, `gridGap` `app_tokens.dart:251`) | same |
| Page margin | 32 at width ≥ 840 (`app_tokens.dart:256`); top 8, bottom 0 (`page_scaffold.dart:56`) | same (rainfall already uses `AppPageScaffold`, margin 32; bottom `foot` 24 `page_scaffold.dart:46`) |
| Card padding / gap | L16 T16 R16 B20, gap 16 (`app_card.dart:101`) | same (plain `AppCard`) |
| Map card contents | hero card: banner, map, legend, gap 16 (`radar_screen.dart:416-443`) | map card: banner, map, legend, note |
| Side contents | `PlaybackCard` (title 動畫播放, meta, `PlaybackBody`) (`playback_card.dart:92`) | accum: window chips + `PlaybackBody`, in a card titled 動畫播放 |
| Map width | main pane = content − side − 16 | same. At 1280: content 1152, side 460.8, main 675.2, map 643.2 |
| Map height | `max(AppLayout.paneMinWidth, pane.maxHeight - _heroChromeHeight)` (`radar_screen.dart:183`); chrome = card padding + header + legend + gaps (`radar_screen.dart:50-51`) | `max(320, viewportHeight - _mapCardChromeHeight)` with the same recipe (card padding 16+20, header, legend+note, gaps, page header). Page scrolls, so the pane height is the window height minus the page header and top margin 8. Mock: 640 px for a 900 px window |
| Map aspect | not used when height is given (tight `SizedBox`) | same; `aspectRatio` default 5/6 is ignored |

## 2. Card order
最近測站 (or no-place card) → **累積雨量** row → **未來 1hr 預測** row → 測站今日累積雨量 → threshold hint. Only the two map sections change.

## 3. Where every control goes
Each row = left map card + right control card.
| Item | Wide placement |
|---|---|
| Title + meta (累積雨量, 過去 N 小時 · 張數 / 預報時段) | header of the left map card |
| Time chip, locate FAB | on the map (unchanged) |
| Error / stale banner + retry | left card, above the map (radar puts banners there, `radar_screen.dart:432`) |
| Legend (`RainLegend`) | left card, under the map (as radar `radar_screen.dart:441`) |
| Footnote | left card, last |
| 累積時距 chips | right card 動畫播放, first |
| Time row, prev/play/next, timeline, 播放設定 (fps, repeat) | right card, `PlaybackBody` |
| 此處 row (forecast) | right card 此處預估 (forecast has no playback; no place → no right card, right pane empty) |

Right column can be shorter than the map; top-aligned, blank below (same as radar's side).
Code shape: `RainMapCard` splits into `mapCard` (title, meta, banner, map, legend, note) and `controlCard`; wide = `AppTwoPane(main: mapCard, side: controlCard)`, narrow = today's single column in today's order. `_MapRow` becomes a plain `Column` of two sections, keeps the `RadarCameraLink`.

### States
- Accum loading: map muted + spinner chip; right card has chips + `PlaybackBody(loading)`.
- Accum failure / stale: banner above map, map muted `無累積雨量資料`.
- Web unavailable (`accum_card.dart:88`), settings unreadable (`:97`), forecast `AppCard.error`, skeleton cards: no map exists → one full-width card, no split.
- No place: forecast has no pin and no right card. No token: `ApiKeyNotice` as today.
- Station cards and `_thresholdHint`: unchanged, full width.

## 4. Wheel
| Region | Wheel |
|---|---|
| Map | zoom (`InteractiveFlag.all`, `radar_map_view.dart:378`) |
| Map chip / FAB, map card header/legend, control card, blank space, gaps | page scrolls |
| Playback timeline (horizontal scroller, `playback_card.dart:304`) | page scrolls for vertical wheel |

Flutter mechanism: the right card must be a plain `Column` — no `SingleChildScrollView`/`ListView`/`Scrollbar`/`Listener`. Radar wraps its side pane in `SingleChildScrollView` (`radar_screen.dart:186`) only because it is a fixed-height `fill` page; rainfall lives in the scrolling page grid (`AppPageScaffold` children), so it must not copy that. Do not wrap the map in a `Listener`.

## 5. Shared widget
Radar has no map+controls widget, only inline `AppTwoPane` + the wide test. Shared = `AppTwoPane` + extracted predicate + the map-height recipe (extract `_heroChromeHeight`-style helper if both need it). No rainfall-only layout widget.

## Uncertainties
- `_mapCardChromeHeight` and the page-header height constant need real-window measuring.
- Vertical wheel over the timeline strip passes through per Flutter scroll code; not tested.
- Keeping the shared camera link for the stacked maps is an assumption (otherwise `RainMapView` needs an explicit interactive flag; `cameraLink == null` now means square + locked).
