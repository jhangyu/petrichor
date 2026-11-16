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
    final (background, backgroundHover, backgroundPressed, foreground, stroke) = switch (variant) {
      AppButtonVariant.primary => (
          AppPalette.brandBackground,
          AppPalette.brandBackgroundHover,
          AppPalette.brandBackgroundPressed,
          AppPalette.foregroundOnBrand,
          AppPalette.brandBackground,
        ),
      AppButtonVariant.secondary => (
          AppPalette.background1,
          AppPalette.backgroundHover,
          AppPalette.backgroundPressed,
          AppPalette.foreground1,
          AppPalette.stroke1,
        ),
      AppButtonVariant.subtle => (
          AppPalette.transparent,
          AppPalette.backgroundHover,
          AppPalette.backgroundPressed,
          AppPalette.foreground2,
          AppPalette.transparent,
        ),
    };
    final disabledBackground =
        variant == AppButtonVariant.subtle ? background : AppPalette.backgroundDisabled;
    final disabledStroke =
        variant == AppButtonVariant.subtle ? stroke : AppPalette.strokeDisabled;
    final textStyle = (small ? AppType.caption1 : AppType.body1).copyWith(fontWeight: FontWeight.w600);
    final height = small ? AppSize.controlSmall : AppSize.control;
    final glyph = icon;
    final textSidePad = small ? AppSpace.s16 : AppSpace.s24;
    final iconSidePad = small ? AppSpace.s12 : AppSpace.s16;

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(block ? double.infinity : AppSize.touch, height)),
      padding: WidgetStatePropertyAll(
        EdgeInsetsDirectional.only(
          start: glyph != null ? iconSidePad : textSidePad,
          end: textSidePad,
        ),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.full))),
      ),
      textStyle: WidgetStatePropertyAll(textStyle),
      elevation: const WidgetStatePropertyAll(0),
      overlayColor: WidgetStatePropertyAll(AppPalette.transparent),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? AppPalette.foregroundDisabled : foreground,
      ),
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return disabledBackground;
        if (s.contains(WidgetState.pressed)) return backgroundPressed;
        if (s.contains(WidgetState.hovered)) return backgroundHover;
        return background;
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
      color: AppPalette.foreground2,
      disabledColor: AppPalette.foregroundDisabled,
      hoverColor: AppPalette.backgroundHover,
      highlightColor: AppPalette.backgroundPressed,
      constraints: const BoxConstraints.tightFor(width: AppSize.touch, height: AppSize.touch),
      padding: EdgeInsets.zero,
    );
  }
}
