import 'dart:math' as math;

import 'package:flutter/rendering.dart';
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
  const WindowSizeClass({required this.widthClass, required this.heightClass});

  factory WindowSizeClass.fromSize(Size size) => WindowSizeClass(
        widthClass: switch (size.width) {
          < AppBreakpoint.medium => WindowWidthClass.compact,
          < AppBreakpoint.expanded => WindowWidthClass.medium,
          < AppBreakpoint.large => WindowWidthClass.expanded,
          _ => WindowWidthClass.large,
        },
        heightClass: switch (size.height) {
          < AppBreakpoint.heightMedium => WindowHeightClass.compact,
          < AppBreakpoint.heightExpanded => WindowHeightClass.medium,
          _ => WindowHeightClass.expanded,
        },
      );

  /// Classes of the whole window (`MediaQuery.sizeOf`), not of the parent box.
  static WindowSizeClass of(BuildContext context) => WindowSizeClass.fromSize(MediaQuery.sizeOf(context));

  final WindowWidthClass widthClass;
  final WindowHeightClass heightClass;

  /// Short window (height class compact): no viewport-bounded panes, let
  /// the page scroll.
  bool get isShortHeight => heightClass == WindowHeightClass.compact;

  /// Phone-width window (width class compact).
  bool get isCompactWidth => widthClass == WindowWidthClass.compact;

  /// Side navigation (rail) instead of the bottom bar.
  bool get usesNavigationRail => widthClass != WindowWidthClass.compact;

  /// Left/right page margin around the card grid.
  double get pageMargin => switch (widthClass) {
        WindowWidthClass.compact => AppLayout.pageMarginCompact,
        WindowWidthClass.medium => AppLayout.pageMarginMedium,
        WindowWidthClass.expanded || WindowWidthClass.large => AppLayout.pageMarginExpanded,
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
    this.minColumnWidth = AppLayout.gridMinimumColumnWidth,
    this.maxColumns = AppLayout.gridMaximumColumns,
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
    double minColumnWidth = AppLayout.gridMinimumColumnWidth,
    int maxColumns = AppLayout.gridMaximumColumns,
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

/// Main pane + side pane in one row, gap 16. Side pane width =
/// available × [AppLayout.paneSideShare], clamped to
/// [AppLayout.paneMinimumWidth]…[AppLayout.paneMaximumWidth]; the main pane takes the
/// rest. Under a bounded height (`AppPageScaffold.fill` body) both panes get
/// the full height and must scroll themselves; inside the scrolling page grid
/// they are top-aligned and keep their own height, or share the taller one
/// with [matchHeight]. Check [fits] first.
class AppTwoPane extends StatelessWidget {
  const AppTwoPane({
    super.key,
    required this.main,
    required this.side,
    this.sideFirst = false,
    this.matchHeight = false,
  });

  final Widget main;
  final Widget side;

  /// Side pane on the left (e.g. a county list before its towns).
  final bool sideFirst;

  /// Under an unbounded height, both panes take the taller pane's height (a
  /// card row with aligned edges).
  final bool matchHeight;

  /// Whether [width] holds two panes of at least [AppLayout.paneMinimumWidth].
  static bool fits(double width) => width >= 2 * AppLayout.paneMinimumWidth + AppLayout.gridGap;

  /// Whether a map+controls split fits: side navigation, not a short window,
  /// and [width] (the content width, page margin removed) [fits] two panes.
  static bool fitsWindow(BuildContext context, double width) {
    final size = WindowSizeClass.of(context);
    return size.usesNavigationRail && !size.isShortHeight && fits(width);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideWidth = (constraints.maxWidth * AppLayout.paneSideShare)
            .clamp(AppLayout.paneMinimumWidth, AppLayout.paneMaximumWidth);
        if (matchHeight && !constraints.hasBoundedHeight) {
          final mainWidth = constraints.maxWidth - sideWidth - AppLayout.gridGap;
          final panes = [SizedBox(width: mainWidth, child: main), SizedBox(width: sideWidth, child: side)];
          return _MatchHeightRow(children: sideFirst ? panes.reversed.toList() : panes);
        }
        final panes = [Expanded(child: main), SizedBox(width: sideWidth, child: side)];
        return Row(
          crossAxisAlignment: constraints.hasBoundedHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
          spacing: AppLayout.gridGap,
          children: sideFirst ? panes.reversed.toList() : panes,
        );
      },
    );
  }
}

/// Fixed-width children in a row, gap [AppLayout.gridGap], all as tall as the
/// tallest: each is laid out at its own height, then the shorter ones again at
/// the tallest height. Unlike IntrinsicHeight it works with LayoutBuilder content.
class _MatchHeightRow extends MultiChildRenderObjectWidget {
  const _MatchHeightRow({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMatchHeightRow();
}

class _MatchHeightRowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMatchHeightRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MatchHeightRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MatchHeightRowParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MatchHeightRowParentData) child.parentData = _MatchHeightRowParentData();
  }

  @override
  void performLayout() {
    final loose = BoxConstraints(maxWidth: constraints.maxWidth);
    var height = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      child.layout(loose, parentUsesSize: true);
      height = math.max(height, child.size.height);
    }
    var x = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (child.size.height < height) child.layout(loose.tighten(height: height), parentUsesSize: true);
      (child.parentData! as _MatchHeightRowParentData).offset = Offset(x, 0);
      x += child.size.width + AppLayout.gridGap;
    }
    size = constraints.constrain(Size(math.max(0, x - AppLayout.gridGap), height));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
