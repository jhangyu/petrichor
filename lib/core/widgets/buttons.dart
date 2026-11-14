import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// `.btn--primary` / `.btn--secondary` / `.btn--subtle`.
enum AppButtonVariant { primary, secondary, subtle }

/// `.btn` (44 high) or `.btn--sm` (32 high, caption1). [block] = `.btn--block`
/// (full width). Null [onPressed] = disabled.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.secondary,
    this.icon,
    this.small = false,
    this.block = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool small;
  final bool block;

  @override
  Widget build(BuildContext context) {
    final (bg, bgHover, bgPressed, fg, stroke) = switch (variant) {
      AppButtonVariant.primary => (
          AppPalette.brandBg,
          AppPalette.brandBgHover,
          AppPalette.brandBgPressed,
          AppPalette.fgOnBrand,
          AppPalette.brandBg,
        ),
      AppButtonVariant.secondary => (
          AppPalette.bg1,
          AppPalette.bgHover,
          AppPalette.bgPressed,
          AppPalette.fg1,
          AppPalette.stroke1,
        ),
      AppButtonVariant.subtle => (
          AppPalette.transparent,
          AppPalette.bgHover,
          AppPalette.bgPressed,
          AppPalette.fg2,
          AppPalette.transparent,
        ),
    };
    final disabledBg =
        variant == AppButtonVariant.subtle ? bg : AppPalette.bgDisabled;
    final disabledStroke =
        variant == AppButtonVariant.subtle ? stroke : AppPalette.strokeDisabled;
    final textStyle = (small ? AppType.caption1 : AppType.body1).copyWith(fontWeight: FontWeight.w600);
    final height = small ? AppSize.controlSm : AppSize.control;
    final glyph = icon;

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(block ? double.infinity : AppSize.touch, height)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: small ? AppSpace.s12 : AppSpace.s16),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm))),
      ),
      textStyle: WidgetStatePropertyAll(textStyle),
      elevation: const WidgetStatePropertyAll(0),
      overlayColor: WidgetStatePropertyAll(AppPalette.transparent),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? AppPalette.fgDisabled : fg,
      ),
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return disabledBg;
        if (s.contains(WidgetState.pressed)) return bgPressed;
        if (s.contains(WidgetState.hovered)) return bgHover;
        return bg;
      }),
      side: WidgetStateProperty.resolveWith(
        (s) => BorderSide(
          color: s.contains(WidgetState.disabled) ? disabledStroke : stroke,
          width: AppStroke.thin,
        ),
      ),
    );

    return TextButton(
      style: style,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            Icon(glyph, size: small ? AppSize.icon16 : AppSize.icon20),
            const SizedBox(width: AppSpace.s8),
          ],
          Text(label),
        ],
      ),
    );
  }
}

/// Subtle 44×44 circular icon button (`.btn--subtle.btn--icon`). [tooltip] is
/// the accessible label (aria-label in the mockups). Null [onPressed] = disabled.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: AppSize.icon24),
      tooltip: tooltip,
      onPressed: onPressed,
      color: AppPalette.fg2,
      disabledColor: AppPalette.fgDisabled,
      hoverColor: AppPalette.bgHover,
      highlightColor: AppPalette.bgPressed,
      constraints: const BoxConstraints.tightFor(width: AppSize.touch, height: AppSize.touch),
      padding: EdgeInsets.zero,
    );
  }
}
