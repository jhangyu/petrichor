# Adaptive spec — hazard (雨量 + 警特報)

Built in `lib/features/hazard/**` (layout only) on the foundation in `system.md`. Decisions come from the grid cell / card width and `WindowSizeClass`, never from ratios. No width literals in `lib/features/hazard`.

## 1. 警特報 (`warnings_screen.dart`)

| Part | Rule |
|---|---|
| Hero, chips | Plain grid cells (1 column each; side by side when the page has ≥ 2 columns). |
| Section header, banners, empty and error states | `AppGridItem.full`. |
| Warning cards | One full-row cell holding a `LayoutBuilder`. Column count = `AppGrid.columnsFor(width, spanUnits: cards)`; item i goes to column i % n (independent `Column`s, so expanding a card only grows its own column, and the highest levels share the top row). |
| Card identity | `ValueKey((name, start, end))` stays on `WarningCard`; `initiallyOpen: i == 0`. |
| Loading | Banner full-row, skeletons are plain cells. |

Width per card comes from the grid (min column `AppLayout.gridMinimumColumnWidth`), so bulletin text in `warning_card.dart` stays near the 65–75 characters-per-line guide.

## 2. 雨量 (`rainfall_screen.dart`)

| Part | Rule |
|---|---|
| Switcher | `AppGridItem.full`, left-aligned, capped at `AppLayout.readingWidth`. |
| Observation body | One full-row cell → `_panes(hero, map, list)`. |
| Forecast body | Same helper with hero and map. |
| No-place, place error, initial loading | Full-row cells. |
| Threshold hint | Full-row cell, shown on success only. |

`_panes` (`LayoutBuilder` on the cell width):
- `AppTwoPane.fits(width)` and a map present → `AppTwoPane(mainPane: hero + list, sidePane: map)`. Both panes are top-aligned and scroll with the page.
- Otherwise → stacked in reading order hero, map, list.
- The map card is always wrapped in `ConstrainedBox(maxWidth: AppLayout.paneMaximumWidth)` aligned top-centre (the radar map is a fixed 5:6, so the card cannot grow wider).
- Skeleton and error cards use the same slots as the real cards, so nothing jumps.

Short windows use the same scrolling layout: no `.fill`, no pane with its own scroll.

## 3. Station list (`rainfall/station_list_card.dart`)

`LayoutBuilder` on the card width:
- `columns = AppGrid.columnsFor(width, spanUnits: rows, minColumnWidth: AppLayout.paneMinimumWidth)`.
- columns > 1 → rows in an `AppGrid` (padded `s16`); columns = 1 → the original stacked rows.
- Collapsed row count = `columns × _collapsedRowCount` (6); the 「顯示全部」 button shows when rows exceed it.
- Card width ≥ `AppLayout.cardWideWidth` → county chips in a `Wrap`; otherwise the horizontal chip scroller (the only horizontal scroll, compact cards only).
- The county rail (list+detail) in the earlier draft is dropped: the foundation rulings cut multi-column `AppList`, and a wrapped chip row plus the in-card grid covers wide cards.

## 4. Unchanged by design
- Hero cards (`ObservationHeroCard`, `ForecastHeroCard`, `WarningsHero`) fill their cell; their `MetricGrid` switches columns by its own width.
- Providers, copy, colours, touch sizes (`AppSize.touch`).
