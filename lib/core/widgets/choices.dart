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
    final fg = selected ? AppPalette.brandForegroundStrong : AppPalette.foreground1;
    final glyph = icon;
    return Material(
      color: selected ? AppPalette.brandBackgroundSubtle : AppPalette.background1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
        side: BorderSide(
          color: selected ? AppPalette.brandStroke : AppPalette.stroke1,
          width: AppStroke.thin,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppPalette.backgroundHover,
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

/// `.segmented.segmented--block`: full-width single-choice switcher, used for
/// view tabs (雨量 觀測／未來 1 小時) and playback settings instead of underline tabs.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
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
        color: AppPalette.background4,
        borderRadius: BorderRadius.circular(AppRadius.full),
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
            color: active ? AppPalette.background1 : AppPalette.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: active ? AppShadows.s2 : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.body1.copyWith(
              color: active ? AppPalette.foreground1 : AppPalette.foreground2,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Themed Material [Switch]; null [onChanged] = disabled.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged, required this.semanticLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      toggled: value,
      child: Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppPalette.foregroundDisabled;
          return states.contains(WidgetState.selected) ? AppPalette.foregroundOnBrand : AppPalette.strokeAccessible;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppPalette.backgroundDisabled;
          return states.contains(WidgetState.selected) ? AppPalette.brandBackground : AppPalette.background4;
        }),
        trackOutlineWidth: const WidgetStatePropertyAll(AppStroke.thick),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppPalette.transparent;
          return states.contains(WidgetState.disabled) ? AppPalette.foregroundDisabled : AppPalette.strokeAccessible;
        }),
      ),
    );
  }
}
