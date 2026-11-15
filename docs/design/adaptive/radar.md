# Radar tab — adaptive layout

Code: `lib/features/radar/radar_screen.dart`, `widgets/playback_card.dart`. Foundation API and tokens: `system.md`. Map internals (`radar_map_view.dart`, `content_scaled_layer.dart`, `basemap_theme.dart`, `radar_webp_image.dart`) are not touched.

## Constraint

`RadarMapView` builds `AspectRatio(5/6)`. Under tight constraints `AspectRatio` takes the given box and ignores its ratio, so the screen bounds the map by wrapping it in a `SizedBox`; no ratio constant is read.

## Layout rule

`RadarScreen.build` reads `WindowSizeClass` and its own `LayoutBuilder` width (the area beside the rail). Side by side when

`size.usesRail && !size.isShortHeight && AppTwoPane.fits(width − 2 × size.pageMargin)`

| Case | Arrangement |
|---|---|
| Side by side (rail, not short, two panes fit) | `AppPageScaffold.fill` with `AppTwoPane`. Main pane: hero card (source chips, banner, map, legend) in its own `SingleChildScrollView`; the map box is `SizedBox(height: max(AppLayout.paneMinWidth, paneHeight − _heroChromeHeight))`, width from the pane. Side pane (`paneSideShare`, 320–480): place banner, playback card, 資料來源 line, in its own `SingleChildScrollView`. No page scroll. |
| Everything else (compact width, short height, medium window too narrow for two panes) | Scrolling `AppPageScaffold` grid: place banner `AppGridItem.full`, hero card, playback card, 資料來源 `AppGridItem.full`. Map keeps its natural 5/6, centred and capped at `AppLayout.paneMaxWidth` (480). A short window scrolls as one page. |

Loading, error and loaded frames share the same path (`_RadarView.hero` is a builder taking the map height; `null` = natural aspect).

## Playback card

- `_Controls` row gap is `AppSpace.s8` (8 px minimum between touch targets).
- `_Settings` fields (回看範圍, 播放速度, 重複播放) sit in `AppGrid(minColumnWidth: AppLayout.paneMinWidth)`: one column in a narrow pane, side by side once the card is wide enough for two.
- Timeline stays a horizontal scroller; touch targets stay `AppSize.touch`.

## Map box size by window (logical)

| Window | Mode | Map box |
|---|---|---|
| 1280×720 (rail, content 1136) | side by side | main-pane width × (pane height − `_heroChromeHeight`) |
| 360×720, 540×960 | grid | natural 5/6, ≤ 480 wide |
| 720×360 (short) | grid, page scrolls | natural 5/6, ≤ 480 wide |

`_heroChromeHeight` = card padding + source chips + legend + gaps, built from `AppSpace` / `AppSize` tokens in `radar_screen.dart`.

## Verified

Matrix harness (map stubbed, so the map box itself is unmeasured): 72 sizes, A4 0 errors, A5 0 fails.
