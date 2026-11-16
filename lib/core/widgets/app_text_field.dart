import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum AppTextFieldVariant { filled, search }

/// Labelled M3 filled text field (top corners 4, bottom indicator);
/// [AppTextFieldVariant.search] = M3 search bar (full radius, s16 horizontal padding).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.variant = AppTextFieldVariant.filled,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.readOnly = false,
    this.autofocus = false,
    this.obscureText = false,
    this.errorText,
    this.helperText,
    this.helperColor,
    this.onTap,
    this.onChanged,
    this.controller,
  });

  final AppTextFieldVariant variant;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool readOnly;
  final bool autofocus;
  final bool obscureText;
  final String? errorText;
  final String? helperText;
  final Color? helperColor;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  bool get _isSearch => variant == AppTextFieldVariant.search;

  InputBorder _border(Color color, double width) => _isSearch
      ? OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide(color: color, width: width),
        )
      : UnderlineInputBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.extraSmall)),
          borderSide: BorderSide(color: color, width: width),
        );

  static const _iconBox = BoxConstraints.tightFor(width: AppSize.touch, height: AppSize.control);

  @override
  Widget build(BuildContext context) {
    final head = label;
    final help = helperText;
    final icon = prefixIcon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.s8,
      children: [
        if (head != null) Text(head, style: AppType.body1Strong.copyWith(color: AppPalette.foreground1)),
        TextField(
          controller: controller,
          readOnly: readOnly,
          autofocus: autofocus,
          obscureText: obscureText,
          onTap: onTap,
          onChanged: onChanged,
          style: AppType.body1.copyWith(color: AppPalette.foreground1),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: _isSearch ? AppPalette.background1 : AppPalette.background4,
            hintText: hint,
            hintStyle: AppType.body1.copyWith(color: AppPalette.foreground3),
            errorText: errorText,
            errorStyle: AppType.caption1.copyWith(color: AppPalette.dangerForeground),
            prefixIcon: icon == null ? null : Icon(icon, size: AppSize.icon20, color: AppPalette.foreground3),
            suffixIcon: suffix,
            prefixIconConstraints: _iconBox,
            suffixIconConstraints: _iconBox,
            constraints: const BoxConstraints(minHeight: AppSize.control),
            contentPadding: _isSearch
                ? const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s12)
                : const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s12),
            enabledBorder: _border(AppPalette.strokeAccessible, AppStroke.thin),
            disabledBorder: _border(AppPalette.strokeAccessible, AppStroke.thin),
            focusedBorder: _border(AppPalette.brandStroke, AppStroke.thick),
            errorBorder: _border(AppPalette.dangerForeground, AppStroke.thick),
            focusedErrorBorder: _border(AppPalette.dangerForeground, AppStroke.thick),
          ),
        ),
        if (help != null && errorText == null)
          Text(help, style: AppType.caption1.copyWith(color: helperColor ?? AppPalette.foreground3)),
      ],
    );
  }
}
