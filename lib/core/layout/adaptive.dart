import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_tokens.dart';

/// Window width classes ([AppBreakpoint] widths, Material 3 window size classes).
enum WindowWidthClass { compact, medium, expanded, large }

/// Window height classes ([AppBreakpoint] heights). [compact] covers short
/// landscape windows (e.g. 720x360 logical) and phones held sideways.
enum WindowHeightClass { compact, medium, expanded }

/// Width and height class of the current window. The only place layout code
/// may turn a size into a layout decision; screens never compare raw sizes
/// against numbers.
@immutable
class WindowSizeClass {
  const WindowSizeClass({required this.width, required this.height});

  factory WindowSizeClass.fromSize(Size size) => WindowSizeClass(
        width: switch (size.width) {
          < AppBreakpoint.medium => WindowWidthClass.compact,
          < AppBreakpoint.expanded => WindowWidthClass.medium,
          < AppBreakpoint.large => WindowWidthClass.expanded,
          _ => WindowWidthClass.large,
        },
        height: switch (size.height) {
          < AppBreakpoint.heightMedium => WindowHeightClass.compact,
          < AppBreakpoint.heightExpanded => WindowHeightClass.medium,
          _ => WindowHeightClass.expanded,
        },
      );

  /// Classes of the whole window (`MediaQuery.sizeOf`), not of the parent box.
  static WindowSizeClass of(BuildContext context) => WindowSizeClass.fromSize(MediaQuery.sizeOf(context));

  final WindowWidthClass width;
  final WindowHeightClass height;

  /// Side navigation (rail) instead of the bottom bar.
  bool get usesRail => width != WindowWidthClass.compact;

  /// Left/right page margin around the card grid.
  double get pageMargin => switch (width) {
        WindowWidthClass.compact => AppSpace.s16,
        WindowWidthClass.medium => AppSpace.s24,
        WindowWidthClass.expanded || WindowWidthClass.large => AppSpace.s32,
      };
}

/// Places [child] in an [AppGrid] cell spanning [span] columns, or the whole
/// row with [AppGridItem.full]. Children of an [AppGrid] that are not an
/// [AppGridItem] span one column.
class AppGridItem extends StatelessWidget {
  const AppGridItem({super.key, required this.span, required this.child}) : assert(span >= 1);

  const AppGridItem.full({super.key, required this.child}) : span = fullRow;

  /// [span] value meaning "the whole row, whatever the column count".
  static const fullRow = 0;

  /// Columns covered; clamped to the grid's column count. [fullRow] = whole row.
  final int span;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Fluid column grid that fills its width. Column count = how many columns of
/// at least [minColumnWidth] fit (1…[maxColumns]), never more than the cells
/// need, so a page with two cards shows two wide cards, not two narrow ones and
/// an empty gap. Cells flow left to right in [children] order; a cell that does
/// not fit the rest of a row starts the next row. Cells in a row are top-aligned
/// and keep their own height.
class AppGrid extends StatelessWidget {
  const AppGrid({
    super.key,
    required this.children,
    this.minColumnWidth = AppLayout.gridMinColumn,
    this.maxColumns = AppLayout.gridMaxColumns,
  });

  final List<Widget> children;

  /// Narrowest column; pass a smaller value for in-card tile grids.
  final double minColumnWidth;
  final int maxColumns;

  static const _gap = AppLayout.gridGap;

  /// Columns an [AppGrid] of [width] uses for cells needing [spanUnits]
  /// columns in total (a full-row cell counts 1).
  static int columnsFor(
    double width, {
    required int spanUnits,
    double minColumnWidth = AppLayout.gridMinColumn,
    int maxColumns = AppLayout.gridMaxColumns,
  }) {
    final fit = ((width + _gap) / (minColumnWidth + _gap)).floor();
    return math.max(1, math.min(math.min(fit, maxColumns), spanUnits));
  }

  static int _spanOf(Widget child) => child is AppGridItem ? child.span : 1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final units = children.fold(0, (sum, c) => sum + math.max(1, _spanOf(c)));
        final columns = columnsFor(width, spanUnits: units, minColumnWidth: minColumnWidth, maxColumns: maxColumns);
        final columnWidth = (width - (columns - 1) * _gap) / columns;
        double cellWidth(int span) => span * columnWidth + (span - 1) * _gap;

        final rows = <Widget>[];
        var row = <Widget>[];
        var used = 0;
        void flush() {
          if (row.isEmpty) return;
          rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: _gap, children: row));
          row = [];
          used = 0;
        }

        for (final child in children) {
          final raw = _spanOf(child);
          final span = raw == AppGridItem.fullRow ? columns : math.min(raw, columns);
          if (used + span > columns) flush();
          row.add(SizedBox(width: cellWidth(span), child: child));
          used += span;
        }
        flush();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: _gap, children: rows);
      },
    );
  }
}
