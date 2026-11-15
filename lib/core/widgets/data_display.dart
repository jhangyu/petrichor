import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// `.badge--*` tones. alert1–4 = CWA rain-warning levels 大雨 → 超大豪雨.
enum BadgeTone { neutral, rain, brand, success, danger, warning, alert1, alert2, alert3, alert4 }

/// `.badge`: small pill (min height 20, caption1 semibold, tabular nums).
class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, this.tone = BadgeTone.neutral, this.icon});

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, stroke) = switch (tone) {
      BadgeTone.neutral => (AppPalette.bg4, AppPalette.fg2, AppPalette.transparent),
      BadgeTone.rain => (AppPalette.rainBg, AppPalette.rainFg, AppPalette.transparent),
      BadgeTone.brand => (AppPalette.brandBg, AppPalette.fgOnBrand, AppPalette.transparent),
      BadgeTone.success => (AppPalette.successBg, AppPalette.successFg, AppPalette.successStroke),
      BadgeTone.danger => (AppPalette.dangerBg, AppPalette.dangerFg, AppPalette.dangerStroke),
      BadgeTone.warning => (AppPalette.warningBg, AppPalette.warningFg, AppPalette.warningStroke),
      BadgeTone.alert1 => (AppPalette.alert1Bg, AppPalette.alert1Fg, AppPalette.alert1Stroke),
      BadgeTone.alert2 => (AppPalette.alert2Bg, AppPalette.alert2Fg, AppPalette.alert2Stroke),
      BadgeTone.alert3 => (AppPalette.alert3Bg, AppPalette.alert3Fg, AppPalette.alert3Stroke),
      BadgeTone.alert4 => (AppPalette.alert4Bg, AppPalette.alert4Fg, AppPalette.alert4Stroke),
    };
    final glyph = icon;
    return Container(
      constraints: const BoxConstraints(minHeight: AppSize.icon20),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: stroke, width: AppStroke.thin),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpace.s4,
        children: [
          if (glyph != null) Icon(glyph, size: AppSize.icon16, color: fg),
          Text(
            label,
            maxLines: 1,
            style: AppType.caption1.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontFeatures: AppType.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// `.level-dot--N`: 8px dot for warning level 1–4; null = neutral (fg3).
class LevelDot extends StatelessWidget {
  const LevelDot({super.key, this.level})
      : assert(level == null || (level >= 1 && level <= 4), 'level must be 1–4 or null');

  final int? level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      1 => AppPalette.alert1Solid,
      2 => AppPalette.alert2Solid,
      3 => AppPalette.alert3Solid,
      4 => AppPalette.alert4Solid,
      _ => AppPalette.fg3,
    };
    return Container(
      width: AppSize.dot,
      height: AppSize.dot,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        // Yellow needs an edge to stay visible on white (`.level-dot--1`).
        border: level == 1 ? Border.all(color: AppPalette.alert1Fg, width: AppStroke.thin) : null,
      ),
    );
  }
}

/// `.metric`: label + value tile. [onHero] = `.hero .metric` (bg-1 with
/// stroke-3 edge instead of bg-2).
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onHero = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final glyph = icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s8),
      decoration: BoxDecoration(
        color: onHero ? AppPalette.bg1 : AppPalette.bg2,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: onHero ? Border.all(color: AppPalette.stroke3, width: AppStroke.thin) : null,
      ),
      child: Row(
        spacing: AppSpace.s8,
        children: [
          if (glyph != null) Icon(glyph, size: AppSize.icon20, color: AppPalette.fg2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.caption1.copyWith(color: AppPalette.fg3)),
                Text(
                  value,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body1Strong.copyWith(color: AppPalette.fg1, fontFeatures: AppType.tabular),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `.metric-grid`: equal columns, gap 8; rows stretch to the taller tile.
/// Two columns, or every tile in one row once the grid is at least
/// [AppLayout.cardWideWidth] wide.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.children});

  final List<MetricTile> children;

  static const _narrowColumns = 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= AppLayout.cardWideWidth ? children.length : _narrowColumns;
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          final row = children.sublist(i, (i + columns).clamp(0, children.length));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpace.s8,
                children: [
                  for (var c = 0; c < columns; c++)
                    Expanded(child: c < row.length ? row[c] : const SizedBox.shrink()),
                ],
              ),
            ),
          );
        }
        return Column(spacing: AppSpace.s8, children: rows);
      },
    );
  }
}

/// `.list`: white rounded group (shadow-2) of [AppListRow]s with faint
/// separators between rows.
class AppList extends StatelessWidget {
  const AppList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppPalette.bg1,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: AppShadows.s2,
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: AppStroke.thin, thickness: AppStroke.thin, color: AppPalette.stroke3),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// `.list-row`: leading / primary + secondary / trailing. [selected] =
/// `.list-row--selected`; null [onTap] = static row; [enabled] false =
/// `.list-row--disabled`.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.primary,
    this.secondary,
    this.leading,
    this.trailing,
    this.selected = false,
    this.enabled = true,
    this.flushTrailing = false,
    this.onTap,
  });

  final String primary;
  final String? secondary;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final bool enabled;

  /// End padding s4 instead of s16 so a trailing [AppIconButton] glyph lines
  /// up with the other trailing glyphs.
  final bool flushTrailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lead = leading;
    final end = trailing;
    final sub = secondary;
    final primaryColor = !enabled
        ? AppPalette.fgDisabled
        : selected
            ? AppPalette.brandFgStrong
            : AppPalette.fg1;
    return Material(
      color: selected ? AppPalette.brandBgSubtle : AppPalette.bg1,
      child: InkWell(
        onTap: enabled ? onTap : null,
        hoverColor: AppPalette.bgHover,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: sub == null ? AppSize.listRowOneLine : AppSize.listRowTwoLine),
          child: Padding(
            padding: flushTrailing
                ? const EdgeInsets.fromLTRB(AppSpace.s16, AppSpace.s8, AppSpace.s4, AppSpace.s8)
                : const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: AppSpace.s12,
              children: [
                ?lead,
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(primary, style: AppType.body1Strong.copyWith(color: primaryColor)),
                      if (sub != null) Text(sub, style: AppType.caption1.copyWith(color: AppPalette.fg3)),
                    ],
                  ),
                ),
                if (end != null)
                  DefaultTextStyle.merge(
                    style: AppType.body1.copyWith(color: AppPalette.fg2, fontFeatures: AppType.tabular),
                    child: end,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
