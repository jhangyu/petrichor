# 地點 tab — adaptive layout

File: `lib/features/place/location_screen.dart`. Layout only; no provider changes. Built on `system.md` (`AppPageScaffold`, `AppGridItem`, `AppGrid`, `AppTwoPane`, `WindowSizeClass`, `AppLayout` tokens). No width literals in the file.

## Rules

1. Every frame is a scrolling `AppPageScaffold` grid. Banners, intro cards, empty states and whole-width lists are `AppGridItem.full`; other cards are 1-column cells.
2. Text and button groups inside a cell are capped at `AppLayout.readingWidth` (640); cards fill their cell.
3. Only the picker has a bespoke arrangement. It decides from the width it is given (`LayoutBuilder` + `AppTwoPane.fits`), not from the window.
4. Short-height windows scroll as one page. No pane has its own scroll: the county pane is a `Wrap`, never a bounded list.

## Main frames

| Frame | Cells |
|---|---|
| `_SelectedView` | cell 1 = hero + search (one `Column`), cell 2 = `_MyPlaces`. One column when the content width fits one column, otherwise side by side |
| `_ExplainerView` | intro card (full) · benefit list · `_ActionsCell` |
| `_DeniedForeverView` | intro card (full) · steps card · `_ActionsCell` · `_MyPlaces` (full, only when places are saved) |
| `_DeniedView`, `_FailedView` | banner (full) · `_MyPlaces` or empty state (full) |
| `_LocatingView` | banner (full) · hero skeleton · list skeleton |
| `_CorruptView` | banner (full) |

`_ActionsCell`: action buttons plus note in one cell, capped at `readingWidth` and top-centered. `_IntroCard` text is capped at `readingWidth`.

## Picker (`_PickerView`)

Search is a full row capped at `readingWidth`. Below it one full-row cell holds a `LayoutBuilder`:

| Available width | Arrangement |
|---|---|
| `AppTwoPane.fits(width)` | `AppTwoPane(sideFirst: true)`: counties on the left (side pane, `paneSideShare` clamped 320–480), towns + buttons on the right. Towns render as an `AppGrid(minColumnWidth: AppLayout.paneMinimumWidth)` of `_RowTile` tiles when that width also fits, else the single-column `AppList` |
| narrower | stacked: counties, towns, buttons |

Counties: compact window width = horizontal-scroll chips with the "左右滑動" hint; medium and wider = `Wrap` chips (`AppSpace.s8` spacing, no hint). A query that matches no county keeps every chip. Save / 設為目前地點: two `Expanded` buttons in a row capped at `readingWidth`, aligned end.

`choices.dart` and `data_display.dart` are unchanged (`AppList` is single-column; `_RowTile` is a local rounded wrapper for grid rows).

## Touch and tokens

Chips and rows keep their existing minimum heights; wrap and grid gaps use `AppSpace.s8` / `AppLayout.gridGap`. Breakpoints and widths come only from `WindowSizeClass` and `AppLayout`.

## Not changed

Data and providers, copy, colors, the `_picking` navigation model, other tabs.
