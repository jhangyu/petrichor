# Adaptive layout system

One layout system for every tab, every window. Layout decisions come from the
window's **size class** and the **available width**, never from the aspect
ratio. No per-ratio variants, no shrinking (`Transform.scale`, `FittedBox`,
text-scaler overrides are forbidden for page content).

Code: `lib/core/layout/adaptive.dart` (helpers + grid), tokens in
`lib/core/theme/app_tokens.dart` (`AppBreakpoint`, `AppLayout`), shell in
`lib/app_shell.dart`, page frame in `lib/core/widgets/page_scaffold.dart`.

## 1. Size classes

Computed from the whole window (`MediaQuery.sizeOf`), logical px.

| Width class | Range | Navigation | Page margin |
|---|---|---|---|
| `compact` | < 600 | bottom `NavigationBar` | 16 |
| `medium` | 600 – 839 | left `NavigationRail` (80 wide) | 24 |
| `expanded` | 840 – 1199 | left `NavigationRail` | 32 |
| `large` | ≥ 1200 | left `NavigationRail` | 32 |

| Height class | Range | Typical windows |
|---|---|---|
| `compact` | < 480 | 720x360 (18:9 @720p 2x), 640x360, phones sideways |
| `medium` | 480 – 899 | 960x540, 1280x720, most laptop windows |
| `expanded` | ≥ 900 | 1920x1080 @1x, tall portrait windows |

Thresholds live only in `AppBreakpoint` (`medium 600`, `expanded 840`,
`large 1200`, `heightMedium 480`, `heightExpanded 900`). Screens never compare a
size with a number; they read `WindowSizeClass`.

The rail is scrollable, so 5 labelled destinations work in a 360-high window.

## 2. Page grid

`AppPageScaffold` lays its `children` out in an `AppGrid` inside the page margin:

- **Column count** = how many columns of at least `AppLayout.gridMinColumn`
  (340) fit the content width, clamped to 1 … `AppLayout.gridMaxColumns` (6),
  and never more than the cells need (sum of spans, a full-row cell counts 1).
  So 2 cards on a wide window → 2 half-width cards, not 2 narrow cards + gap.
- **Gap** = `AppLayout.gridGap` (16) between columns and rows.
- **Flow**: cells go left → right in `children` order. A cell that does not fit
  the rest of the row starts a new row. Cells in a row are top-aligned and keep
  their own height (no row stretching, no masonry). Put cards of similar height
  next to each other.
- **Span**: a plain child spans 1 column. `AppGridItem(span: n, …)` spans `n`
  (clamped to the column count). `AppGridItem.full(…)` always takes the whole row.
- Cells fill their column width. The **page** has no max width; the grid fills
  the window edge to edge (minus margin and rail).
- **Reading width**: cards fill their cell; only running text blocks inside a
  card are capped at `AppLayout.readingWidth` (640). Charts, maps, tables and
  tile rows fill the card.

Column counts that follow (content width = window − rail 80 − 2 × margin):

| Window (logical) | Nav | Content width | Columns (≥ 6 cells) |
|---|---|---|---|
| 360x720 | bar | 328 | 1 |
| 720x360 | rail | 592 | 1 |
| 960x540 | rail | 816 | 2 |
| 1280x720 | rail | 1136 | 3 |
| 1920x1080 | rail | 1776 | 5 |
| ≥ 2264 wide | rail | ≥ 2120 | 6 |

## 3. Public API

Import:

```dart
import 'package:cwb_flutter/core/layout/adaptive.dart'; // or relative '../../core/layout/adaptive.dart'
```

### `AppPageScaffold` (unchanged signature)

```dart
AppPageScaffold({
  required AppPageHeader header,
  required List<Widget> children, // grid cells, in reading order
  SourceLine? source,
  Future<void> Function()? onRefresh,
})
```

### `AppGridItem` — span control for a grid cell

```dart
const AppGridItem({required int span, required Widget child}) // span >= 1
const AppGridItem.full({required Widget child})                // whole row
```

### `AppGrid` — the grid itself (used by the scaffold; use it directly for in-card tile grids)

```dart
const AppGrid({
  required List<Widget> children,
  double minColumnWidth = AppLayout.gridMinColumn, // pass a smaller value for tiles
  int maxColumns = AppLayout.gridMaxColumns,
})
static int columnsFor(double width, {required int spanUnits, double minColumnWidth, int maxColumns})
```

Needs a bounded width (inside a card, a cell, or the scaffold — always true).

### `WindowSizeClass` — the only way to branch on window size

```dart
WindowSizeClass.of(context)        // whole window
  .width   // WindowWidthClass.compact | medium | expanded | large
  .height  // WindowHeightClass.compact | medium | expanded
  .usesRail
  .pageMargin
```

### Tokens

`AppBreakpoint.{medium, expanded, large, heightMedium, heightExpanded}`,
`AppLayout.{gridMinColumn, gridMaxColumns, gridGap, readingWidth}`.

### Usage

```dart
return AppPageScaffold(
  header: AppPageHeader(title: '天氣'),
  source: const SourceLine(datasetIds: ['O-A0003-001']),
  children: [
    if (banner != null) AppGridItem.full(child: banner), // banners, notices: whole row
    AppGridItem(span: 2, child: heroCard),               // wide hero on ≥2 columns
    nowCard,                                             // 1 column each
    rainCard,
    AppGridItem.full(child: weeklyCard),                 // wide table/chart
  ],
);
```

In-card tile grid (e.g. stations, forecast tiles):

```dart
AppCard(title: '測站', child: AppGrid(minColumnWidth: 160, children: tiles))
```

Long text block inside a card:

```dart
ConstrainedBox(
  constraints: const BoxConstraints(maxWidth: AppLayout.readingWidth),
  child: Text(description),
)
```

Height-aware sizing (e.g. a map that should fit a short landscape window):

```dart
final size = WindowSizeClass.of(context);
final mapHeight = switch (size.height) {
  WindowHeightClass.compact => /* a token or a fraction of MediaQuery.sizeOf(context).height */,
  _ => /* … */,
};
```

## 4. Rules for screen designers

1. Compose only `AppPageScaffold` + `AppGridItem` + `AppGrid` + `WindowSizeClass`.
   No `LayoutBuilder` breakpoint math, no numeric width literals compared to
   sizes in `lib/features/**`, no aspect-ratio checks.
2. Decide per child: 1 column (default), `span: n`, or `.full`. Banners, error /
   empty states that replace the whole page, and wide charts/maps/tables are
   `.full`.
3. A cell must lay out at any width ≥ 296 (compact 328 minus card padding) and
   stay readable when 2–3× wider: let rows `Expanded`, wrap chips, cap long
   text with `readingWidth`. Never set a fixed card width.
4. Fixed heights only for things that have an intrinsic height (charts, maps);
   derive them from tokens or the height class, not from width.
5. Keep children in reading order; the grid reflows them top-to-bottom on
   1 column and left-to-right on more.
