import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum AppTextFieldVariant { outlined, search }

/// Labelled M3 outlined text field; [AppTextFieldVariant.search] = M3 search
/// bar (full radius, s16 horizontal padding).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.variant = AppTextFieldVariant.outlined,
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

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(variant == AppTextFieldVariant.search ? AppRadius.full : AppRadius.extraSmall),
    borderSide: BorderSide(color: color, width: width),
  );

  @override
  Widget build(BuildContext context) {
    final head = label;
    final help = helperText;
    final icon = prefixIcon;
    final isSearch = variant == AppTextFieldVariant.search;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.s4,
      children: [
        if (head != null) Text(head, style: AppType.body1Strong.copyWith(color: AppPalette.fg1)),
        TextField(
          controller: controller,
          readOnly: readOnly,
          autofocus: autofocus,
          obscureText: obscureText,
          onTap: onTap,
          onChanged: onChanged,
          style: AppType.body1.copyWith(color: AppPalette.fg1),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppPalette.bg1,
            hintText: hint,
            hintStyle: AppType.body1.copyWith(color: AppPalette.fg3),
            errorText: errorText,
            errorStyle: AppType.caption1.copyWith(color: AppPalette.dangerFg),
            prefixIcon: icon == null ? null : Icon(icon, size: AppSize.icon20, color: AppPalette.fg3),
            suffixIcon: suffix,
            constraints: const BoxConstraints(minHeight: AppSize.control),
            contentPadding: isSearch
                ? const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s12)
                : null,
            enabledBorder: _border(AppPalette.strokeAccessible, AppStroke.thin),
            disabledBorder: _border(AppPalette.strokeAccessible, AppStroke.thin),
            focusedBorder: _border(AppPalette.brandStroke, AppStroke.thick),
            errorBorder: _border(AppPalette.dangerFg, AppStroke.thick),
            focusedErrorBorder: _border(AppPalette.dangerFg, AppStroke.thick),
          ),
        ),
        if (help != null && errorText == null)
          Text(help, style: AppType.caption1.copyWith(color: helperColor ?? AppPalette.fg3)),
      ],
    );
  }
}
