# Adaptive layout system

One layout system for every tab, every window. Layout decisions come from the
window's **size class** and the **available width**, never from the aspect
ratio. No per-ratio variants, no shrinking (`Transform.scale`, `FittedBox`,
text-scaler overrides are forbidden for page content).

Code: `lib/core/layout/adaptive.dart` (size classes, grid, two panes), tokens in
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
- **Reading width**: cards fill their cell; only running text, banner text and
  button groups inside a card are capped at `AppLayout.readingWidth` (640).
  Charts, tables and tile rows fill the card. A map that keeps its natural
  aspect ratio is capped at `AppLayout.paneMaxWidth` (480).
- **No equal-height rows** (see §5).

Column counts that follow (content width = window − rail 80 − 2 × margin):

| Window (logical) | Nav | Content width | Columns (≥ 6 cells) |
|---|---|---|---|
| 360x720 | bar | 328 | 1 |
| 720x360 | rail | 592 | 1 |
| 960x540 | rail | 816 | 2 |
| 1280x720 | rail | 1136 | 3 |
| 1920x1080 | rail | 1776 | 5 |
| ≥ 2264 wide | rail | ≥ 2120 | 6 |

## 3. Page modes

| Mode | Use | Scroll |
|---|---|---|
| `AppPageScaffold(children: …)` | every page by default | the page scrolls; children are grid cells |
| `AppPageScaffold.fill(body: …)` | a page whose panes must fit the viewport (radar side by side) | no page scroll; `body` gets tight width and bounded height and its panes scroll themselves |

Rule: use `.fill` only when the window is not short
(`!WindowSizeClass.of(context).isShortHeight`) and the panes fit
(`AppTwoPane.fits(width)`). Otherwise use the scrolling grid. A short window
always scrolls as one page: no nested scroll areas.

## 4. Public API

Import `package:petrichor/core/layout/adaptive.dart` (or the relative path).
Tokens come from `app_tokens.dart`.

### `WindowSizeClass`: the only way to branch on window size

```dart
final size = WindowSizeClass.of(context); // whole window
size.width          // WindowWidthClass.compact | medium | expanded | large
size.height         // WindowHeightClass.compact | medium | expanded
size.isShortHeight  // height == compact (< 480): no viewport-bounded panes
size.usesRail
size.pageMargin
```

### `AppPageScaffold`

```dart
AppPageScaffold({                 // unchanged signature
  required AppPageHeader header,
  required List<Widget> children, // grid cells, in reading order
  SourceLine? source,
  Future<void> Function()? onRefresh,
})
AppPageScaffold.fill({
  required AppPageHeader header,
  required Widget body,           // bounded box inside the page margin
  SourceLine? source,             // pinned under the body
})
```

### `AppGridItem`: span of one cell

```dart
const AppGridItem({required int span, required Widget child}) // span >= 1, clamped to the column count
const AppGridItem.full({required Widget child})                // whole row
```

A plain child spans 1 column.

### `AppGrid`: the grid (the scaffold uses it; use it directly for in-card grids)

```dart
const AppGrid({
  required List<Widget> children,
  double minColumnWidth = AppLayout.gridMinColumn,
  int maxColumns = AppLayout.gridMaxColumns,
})
static int columnsFor(double width, {required int spanUnits, double minColumnWidth, int maxColumns})
```

The grid needs a bounded width. This is always true in a card, a cell or the
scaffold. Use `columnsFor` when the code itself needs the count (e.g.
"collapsed rows = columns × 6"), inside a `LayoutBuilder` on the card.

### `AppTwoPane`: main pane + side pane

```dart
const AppTwoPane({required Widget main, required Widget side, bool sideFirst = false})
static bool fits(double width) // width >= 2 × paneMinWidth + gap (656)
```

- The side pane width is available width × `paneSideShare` (0.4), clamped to
  320…480. The main pane takes the rest.
- Under a bounded height (`.fill` body) both panes are stretched to the full
  height and scroll themselves.
- Inside the scrolling grid (put it in an `AppGridItem.full`) both panes are
  top-aligned and scroll with the page.
- Call `fits` on the width you have, from the body's or cell's `LayoutBuilder`,
  before building it. Below that width, stack the panes as grid cells.

### `MetricGrid` (data_display.dart, signature unchanged)

The column count now follows its own width: 2 columns, or every tile in one row
when the grid is at least `AppLayout.cardWideWidth` (520) wide. Callers change
nothing.

### Tokens

| Token | Value | Meaning |
|---|---|---|
| `AppBreakpoint.medium / expanded / large` | 600 / 840 / 1200 | width classes |
| `AppBreakpoint.heightMedium / heightExpanded` | 480 / 900 | height classes |
| `AppLayout.gridMinColumn` | 340 | narrowest page column (= min card width) |
| `AppLayout.gridMaxColumns` | 6 | max page columns |
| `AppLayout.gridGap` | 16 | grid and pane gap |
| `AppLayout.pageMarginCompact / Medium / Expanded` | 16 / 24 / 32 | page side margin per width class (`WindowSizeClass.pageMargin`) |
| `AppLayout.readingWidth` | 640 | max width of text blocks, banner text, button groups |
| `AppLayout.cardWideWidth` | 520 | card content width from which a card uses its wide interior |
| `AppLayout.paneMinWidth` | 320 | min side pane, min map box side, min cell width of multi-column lists |
| `AppLayout.paneMaxWidth` | 480 | max side pane; cap for a natural-aspect map |
| `AppLayout.paneSideShare` | 0.4 | side pane share of the width |

### Recipes

Page with spans:

```dart
return AppPageScaffold(
  header: AppPageHeader(title: '天氣'),
  source: const SourceLine(datasetIds: ['O-A0003-001']),
  children: [
    if (banner != null) AppGridItem.full(child: banner), // banners, notices: whole row
    heroCard,                                            // 1 column each
    sunCard,
    AppGridItem.full(child: forecastCard),               // wide chart/table
  ],
);
```

Card wide interior. Decide from the card's own width, not the window:

```dart
LayoutBuilder(builder: (context, c) => c.maxWidth >= AppLayout.cardWideWidth ? wide : narrow)
```

Multi-column list rows (towns, stations):

```dart
AppGrid(minColumnWidth: AppLayout.paneMinWidth, children: rows)
```

Viewport-filling two panes (radar):

```dart
final size = WindowSizeClass.of(context);
// size.width != WindowWidthClass.compact && !size.isShortHeight, plus AppTwoPane.fits(width) from a LayoutBuilder
AppPageScaffold.fill(
  header: header,
  source: source,
  body: AppTwoPane(main: mapCard, side: SingleChildScrollView(child: playbackCard)),
)
```

`.fill` gives `body` a bounded height, so the map card can size its map with
its own `LayoutBuilder` + `SizedBox` (tight box).

Text block or button group cap:

```dart
ConstrainedBox(constraints: const BoxConstraints(maxWidth: AppLayout.readingWidth), child: …)
```

## 5. Decisions on screen-spec requests

Rule: the foundation provides only what at least two screens use. Anything a
single screen needs is composed in that screen from the API above.

| Request (spec) | Decision |
|---|---|
| Non-scrolling body with bounded constraints (radar §6) | **Added**: `AppPageScaffold.fill` |
| Per-child span, full row vs one cell (all) | **Exists**: `AppGridItem` / `.full` |
| Reading width / per-card max width (location, weather, hazard) | **Exists**: `AppLayout.readingWidth`. Applies to text, banners and button groups inside a card, not to whole cards. |
| Size-class helper + short-height flag (all) | **Added**: `WindowSizeClass.isShortHeight` |
| Pane widths / two-pane helper (radar, hazard §6.3, location) | **Added**: `AppTwoPane` + `paneMinWidth / paneMaxWidth / paneSideShare` |
| Card wide-interior threshold (weather hero/sun, radar playback, hazard list + detail) | **Added**: `AppLayout.cardWideWidth` (520) |
| `MetricGrid` columns by width (weather, hazard) | **Added**: automatic, no new parameter |
| Map card cap (hazard `mapCardMaxWidth`) | **Mapped** to `AppLayout.paneMaxWidth` (480). The radar map min box side is `AppLayout.paneMinWidth`. |
| Radar `radarMapHeightShare`, flex 3:2 | **Cut**. The two-pane split is `paneSideShare` (0.4, i.e. 3:2). The stacked-map height share is a radar-local named constant: it is a fraction of height, not a width breakpoint. |
| Radar `radarControlsWide` (560) | **Mapped** to `cardWideWidth`. In side-by-side mode the controls pane is ≤ 480, so the playback card is single-column there. It goes wide only when stacked at full width. |
| Location button max width | **Mapped**: put the button row in `ConstrainedBox(maxWidth: readingWidth)` aligned end, or in its own grid cell. No new token. |
| Equal-height grid rows (weather) | **Cut**. Weather is the only user. Stretching needs intrinsic-height layout, which throws on cards that contain a `LayoutBuilder` (72 h chart, `MetricGrid`). Rows are top-aligned; put cards of similar height side by side. |
| Masonry / independent columns (hazard warnings §6.1b) | **Cut**. Hazard is the only user. The row grid does not stretch neighbours: expanding a card only pushes the following rows down. If hazard wants independent columns, it builds `n = AppGrid.columnsFor(width, spanUnits: cards.length)` `Column`s with item i in column i % n, inside a `LayoutBuilder`. |
| 12-unit expanded grid, `half` spans (weather) | **Cut**. The column count is fluid. Use `span: n` or `.full`. A 2-cell row already gives halves. |
| `AppList` multi-column (location) | **Cut** from `AppList`, whose dividers assume one column. Use `AppGrid(minColumnWidth: paneMinWidth, children: rows)` inside the card. |
| `AppChip` wrap (location, hazard) | **Exists**: `Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8)` as documented on `AppChip`. No change to `choices.dart`. |
| Shared drag-scroll behaviour for the 72 h chart (weather) | **Cut** (parking lot). Not needed when the chart fits. |

### Answers to hazard §6

1. (a) Per-child full span: yes, `AppGridItem.full`. (b) Masonry: no, see the
   table above. The grid is row-aligned but top-aligned, so neighbours are not
   stretched.
2. `cardMinWidth` → `AppLayout.gridMinColumn` (340), or `paneMinWidth` (320)
   for in-card list cells. `cardMaxWidth` → `AppLayout.readingWidth` (640), for
   text. `mapCardMaxWidth` → `AppLayout.paneMaxWidth` (480). The short-height
   flag is `WindowSizeClass.of(context).isShortHeight`.
3. Two panes: use `AppTwoPane`, shared with radar and location.

### Answers to weather "Open"

1. `MetricGrid` (data_display.dart) is foundation-owned. Its columns now follow
   width automatically: 4 in one row at ≥ 520, else 2. Forcing one row on short
   height is not supported: at compact width that is 4 tiles of ~70 px.
2. Span: `AppGridItem`. Equal height: cut (above). Reading width:
   `AppLayout.readingWidth`. Variant selection: by **card content width** vs
   `AppLayout.cardWideWidth`, via the card's own `LayoutBuilder` (a half-width
   cell at expanded and a full cell at medium are the same width, as weather
   noted).

### Guidance check (ui-ux-pro-max:design-system)

The skill uses three layers: primitive → semantic → component.
- `AppSpace` is the primitive spacing scale.
- `AppBreakpoint` and `AppLayout` are semantic layout tokens.
- Screen-local named constants (chart px/h, sun-arc max width) are the component layer.
- Every layout value is on the 4 px grid.

Naming:
- `AppBreakpoint` names each class by its lower bound (`medium`, `expanded`,
  `large`, `heightMedium`, `heightExpanded`).
- `AppLayout` names say the purpose (`gridMinColumn`, `readingWidth`,
  `paneMinWidth`, ...), which is the skill's semantic-naming rule.
- No renames.

What it changed (commit d0ecb76, made before the freeze on 57196f2): the change
only adds tokens, and every value stays the same.
- The page margins were primitives picked inside `WindowSizeClass`. They are
  now semantic aliases of `AppSpace` in `AppLayout`
  (`pageMarginCompact/Medium/Expanded`).
- `gridGap` already aliased `AppSpace.s16`.

What it did not change:
- The width values (340, 520, 320, 480, 640) have no shared primitive scale,
  so no extra primitive layer was added for them.

## 6. Rules for screen designers

1. Compose only `AppPageScaffold(.fill)`, `AppGridItem`, `AppGrid`,
   `AppTwoPane`, `WindowSizeClass` and the `AppLayout` tokens. No numeric
   width/height literals compared to sizes in `lib/features/**`, and no
   aspect-ratio checks.
2. Decide per child: 1 column (default), `span: n`, or `.full`. Banners, error /
   empty states that replace the whole page, and wide charts/tables are `.full`.
   Loading skeletons use the same spans as the cards they stand in for.
3. A cell must lay out at any width ≥ 296 (compact 328 minus card padding) and
   stay readable when 2–3× wider: let rows `Expanded`, wrap chips, cap long
   text with `readingWidth`, and switch to a wide interior at `cardWideWidth`.
   Never set a fixed card width.
4. Fixed heights only for things that have an intrinsic height (charts, maps).
   Derive them from tokens or the height class, not from width.
5. Short windows (`isShortHeight`) scroll as one page: no `.fill`, no pane with
   its own scroll.
6. Keep children in reading order. The grid reflows them top to bottom on one
   column and left to right on more.
