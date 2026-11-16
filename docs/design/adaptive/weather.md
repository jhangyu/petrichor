# 天氣 tab — adaptive layout

Scope: `lib/features/weather/**`. Built on the foundation in `system.md` (size classes, `AppGrid`, `AppGridItem`, `AppLayout` tokens). Decisions come from available width, never ratios; nothing is scaled down. The page scrolls vertically in every window.

## Layout

`weather_screen.dart` puts the four data cards in one full-row cell (`_CardFlow`). `_CardFlow` asks `AppGrid.columnsFor(width, spanUnits: 4)` for the column count and arranges the cards in reading order:

| Columns | Arrangement |
|---|---|
| 1 | hero, sun, 72h, weekly stacked |
| 2 | hero \| sun, then 72h full width, then weekly full width |
| 3 or more | hero \| sun, then 72h (3 parts) \| weekly (2 parts) |

Rows are top-aligned; cards keep their own height (no equal-height stretching, `system.md` §5).

Cells outside the flow are `AppGridItem.full`: the loading pill and the warning entry. The idle 「下拉即可重新整理」 hint shows only at compact width (touch); the loading pill shows at every width. No-place / error frames are a single child (one full row).

## Cards

- **Hero** (`hero_card.dart`): unchanged. Its `MetricGrid` goes 4-in-a-row by itself from `AppLayout.cardWideWidth`, so there is no separate wide hero variant.
- **Sun** (`sun_card.dart`): the arc is capped at `_arcMaxWidth` (360) and centered. When the card content is at least `AppLayout.cardWideWidth`, the arc sits left and the time rows, now line and tomorrow line sit right; below that, they stack.
- **72h** (`hourly_forecast_card.dart`): the chart cell width feeds `_ChartGeometry`. Px per hour = available / hours, clamped to `_minPixelsPerHour` (16) … `_maxPixelsPerHour` (32). The same 72 hours always show; wider cards widen the spacing. If the chart fits it is centered with no scroll view and no 「左右滑動看 72 小時」 hint; otherwise it scrolls horizontally (compact). Bar width is two thirds of a 3-hour slot. Chart height and row Y positions stay fixed (text rows). The chart `Semantics` label carries a max / min / rain summary and mentions scrolling only when it scrolls.
- **Weekly** (`weekly_card.dart`): unchanged; the range bar `Expanded` absorbs extra width.

## Short height

No special case. The page scrolls as one page (no `.fill`); wide hero/sun interiors depend on card width only.

## Tokens

Named constants in the weather files: `_arcMaxWidth`, `_minPixelsPerHour`, `_maxPixelsPerHour`, `_fitTolerance`, `_forecastFlex`, `_weeklyFlex`, `_cardCount`. Thresholds come only from `AppLayout` / `AppGrid`.

## Cut from the round 1 spec
- Equal-height rows, 12-unit spans: cut by `system.md` §5.
- Hero wide variant, forced 4×1 metrics on short height: `MetricGrid` is automatic; short height not supported.
- Skeleton heights per variant: unchanged (loading cards keep the compact heights).
- Drag-scroll behaviour for the chart: parking lot.
