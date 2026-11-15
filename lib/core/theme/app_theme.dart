import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Light-only Material theme built from [AppPalette] / [AppType] tokens.
abstract final class AppTheme {
  /// Token font stack minus the Segoe/Noto web fonts: the base family is the
  /// platform default (SF on Apple, Segoe on Windows, Roboto on Android);
  /// these system families supply Traditional Chinese glyphs offline.
  static const _cjkFallback = ['PingFang TC', 'Microsoft JhengHei', 'Noto Sans CJK TC'];

  static ThemeData get light {
    final textColor = AppType.body1.copyWith(color: AppPalette.fg1);
    return ThemeData(
      brightness: Brightness.light,
      fontFamilyFallback: _cjkFallback,
      scaffoldBackgroundColor: AppPalette.bg3,
      colorScheme: const ColorScheme.light(
        primary: AppPalette.brandBg,
        onPrimary: AppPalette.fgOnBrand,
        primaryContainer: AppPalette.brandBgSubtle,
        onPrimaryContainer: AppPalette.brandFgStrong,
        secondary: AppPalette.brandBg,
        onSecondary: AppPalette.fgOnBrand,
        surface: AppPalette.bg1,
        onSurface: AppPalette.fg1,
        onSurfaceVariant: AppPalette.fg2,
        outline: AppPalette.stroke1,
        outlineVariant: AppPalette.stroke2,
        error: AppPalette.dangerFg,
        onError: AppPalette.fgOnSolid,
        surfaceTint: AppPalette.bg1,
      ),
      textTheme: TextTheme(
        bodySmall: AppType.caption1.copyWith(color: AppPalette.fg1),
        bodyMedium: textColor,
        bodyLarge: AppType.body2.copyWith(color: AppPalette.fg1),
        labelLarge: AppType.body1Strong.copyWith(color: AppPalette.fg1),
        titleMedium: AppType.subtitle2.copyWith(color: AppPalette.fg1),
        titleLarge: AppType.subtitle1.copyWith(color: AppPalette.fg1),
      ),
      dividerColor: AppPalette.stroke2,
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.extraLarge))),
      ),
      timePickerTheme: const TimePickerThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.extraLarge))),
        hourMinuteShape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.small))),
      ),
      snackBarTheme: const SnackBarThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.extraSmall))),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.bg4,
        border: UnderlineInputBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.extraSmall))),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSize.bottomNav,
        backgroundColor: AppPalette.bg1,
        surfaceTintColor: AppPalette.bg1,
        elevation: 0,
        indicatorColor: AppPalette.brandBgSubtle,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppType.caption1.copyWith(color: AppPalette.brandFgStrong, fontWeight: FontWeight.w600)
              : AppType.caption1.copyWith(color: AppPalette.fg3),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: AppSize.icon24,
            color: states.contains(WidgetState.selected) ? AppPalette.brandFgStrong : AppPalette.fg3,
          ),
        ),
      ),
    );
  }
}
