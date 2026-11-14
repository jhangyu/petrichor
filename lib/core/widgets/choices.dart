import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// `.chip` (single/multi choice). Group chips with
/// `Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8)` (`.chip-group`) or a
/// horizontal `SingleChildScrollView` + `Row(spacing: AppSpace.s8)`
/// (`.chip-group--scroll`).
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppPalette.brandFgStrong : AppPalette.fg1;
    final glyph = icon;
    return Material(
      color: selected ? AppPalette.brandBgSubtle : AppPalette.bg1,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppPalette.brandStroke : AppPalette.stroke1,
          width: AppStroke.thin,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppPalette.bgHover,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.controlSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpace.s4,
              children: [
                if (glyph != null) Icon(glyph, size: AppSize.icon16, color: fg),
                Text(
                  label,
                  style: AppType.body1.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.segmented.segmented--block`: full-width single-choice switcher. Team A
/// uses this for view tabs (雨量 觀測／未來 1 小時) and playback settings
/// instead of underline tabs.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  /// (value, label) pairs in display order.
  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.s4),
      decoration: BoxDecoration(
        color: AppPalette.bg4,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        spacing: AppSpace.s4,
        children: [
          for (final (value, label) in segments)
            Expanded(child: _Segment(label: label, active: value == selected, onTap: () => onChanged(value))),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.easyEase,
          constraints: const BoxConstraints(minHeight: AppSize.controlSm),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
          decoration: BoxDecoration(
            color: active ? AppPalette.bg1 : AppPalette.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: active ? AppShadows.s2 : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.body1.copyWith(
              color: active ? AppPalette.fg1 : AppPalette.fg2,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
