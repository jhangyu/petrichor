import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Light-only Material theme built from [AppPalette] / [AppType] tokens.
abstract final class AppTheme {
  /// Token font stack minus the Segoe/Noto web fonts: the base family is the
  /// platform default (SF on Apple, Segoe on Windows, Roboto on Android);
  /// these system families supply Traditional Chinese glyphs offline.
  static const _cjkFallback = ['PingFang TC', 'Microsoft JhengHei', 'Noto Sans CJK TC'];

  static ThemeData get light {
    final textColor = AppType.body1.copyWith(color: AppPalette.foreground1);
    return ThemeData(
      brightness: Brightness.light,
      fontFamilyFallback: _cjkFallback,
      scaffoldBackgroundColor: AppPalette.background3,
      colorScheme: const ColorScheme.light(
        primary: AppPalette.brandBackground,
        onPrimary: AppPalette.foregroundOnBrand,
        primaryContainer: AppPalette.brandBackgroundSubtle,
        onPrimaryContainer: AppPalette.brandForegroundStrong,
        secondary: AppPalette.brandBackground,
        onSecondary: AppPalette.foregroundOnBrand,
        surface: AppPalette.background1,
        onSurface: AppPalette.foreground1,
        onSurfaceVariant: AppPalette.foreground2,
        outline: AppPalette.stroke1,
        outlineVariant: AppPalette.stroke2,
        error: AppPalette.dangerForeground,
        onError: AppPalette.foregroundOnSolid,
        surfaceTint: AppPalette.background1,
      ),
      textTheme: TextTheme(
        bodySmall: AppType.caption1.copyWith(color: AppPalette.foreground1),
        bodyMedium: textColor,
        bodyLarge: AppType.body2.copyWith(color: AppPalette.foreground1),
        labelLarge: AppType.body1Strong.copyWith(color: AppPalette.foreground1),
        titleMedium: AppType.subtitle2.copyWith(color: AppPalette.foreground1),
        titleLarge: AppType.subtitle1.copyWith(color: AppPalette.foreground1),
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
        fillColor: AppPalette.background4,
        border: UnderlineInputBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.extraSmall))),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSize.bottomNavigationBar,
        backgroundColor: AppPalette.background1,
        surfaceTintColor: AppPalette.background1,
        elevation: 0,
        indicatorColor: AppPalette.brandBackgroundSubtle,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppType.caption1.copyWith(color: AppPalette.brandForegroundStrong, fontWeight: FontWeight.w600)
              : AppType.caption1.copyWith(color: AppPalette.foreground3),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: AppSize.icon24,
            color: states.contains(WidgetState.selected) ? AppPalette.brandForegroundStrong : AppPalette.foreground3,
          ),
        ),
      ),
    );
  }
}
