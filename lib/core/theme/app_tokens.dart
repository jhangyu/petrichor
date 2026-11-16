import 'package:flutter/material.dart';

/// Fluent 2 light design tokens, mirrored from
/// `docs/design/tokens-fluent2-light.css` (single source of truth).
/// This is the only file in `lib/` allowed to contain colour literals.

/// `--color-*` tokens.
abstract final class AppPalette {
  // Neutral backgrounds
  static const background1 = Color(0xFFFFFFFF);
  static const background2 = Color(0xFFFAFAFA);
  static const background3 = Color(0xFFF5F5F5);
  static const background4 = Color(0xFFF0F0F0);
  static const background6 = Color(0xFFE6E6E6);
  static const backgroundHover = Color(0xFFF5F5F5);
  static const backgroundPressed = Color(0xFFE0E0E0);
  static const backgroundDisabled = Color(0xFFF0F0F0);
  static const backgroundOverlay = Color(0xEBFFFFFF); // rgba(255,255,255,0.92)
  static const transparent = Color(0x00000000);

  // Neutral foregrounds
  static const foreground1 = Color(0xFF242424);
  static const foreground2 = Color(0xFF424242);
  static const foreground3 = Color(0xFF616161);
  static const foreground4 = Color(0xFF707070);
  static const foregroundDisabled = Color(0xFFBDBDBD);
  static const foregroundOnBrand = Color(0xFFFFFFFF);
  static const foregroundOnSolid = Color(0xFFFFFFFF);

  // Neutral strokes
  static const stroke1 = Color(0xFFD1D1D1);
  static const stroke2 = Color(0xFFE0E0E0);
  static const stroke3 = Color(0xFFF0F0F0);
  static const strokeAccessible = Color(0xFF616161);
  static const strokeDisabled = Color(0xFFE0E0E0);

  // Brand ramp (communication blue)
  static const brand40 = Color(0xFF0C3B5E);
  static const brand60 = Color(0xFF0F548C);
  static const brand70 = Color(0xFF115EA3);
  static const brand80 = Color(0xFF0F6CBD);
  static const brand90 = Color(0xFF2886DE);
  static const brand120 = Color(0xFF77B7F7);
  static const brand140 = Color(0xFFB4D6FA);
  static const brand150 = Color(0xFFCFE4FA);
  static const brand160 = Color(0xFFEBF3FC);

  // Brand semantic aliases
  static const brandBackground = brand80;
  static const brandBackgroundHover = brand70;
  static const brandBackgroundPressed = brand40;
  static const brandBackgroundSubtle = brand160;
  static const brandForeground = brand80;
  static const brandForegroundStrong = brand60;
  static const brandStroke = brand80;
  static const brandStrokeSubtle = brand140;

  // Status
  static const successBackground = Color(0xFFF1FAF1);
  static const successForeground = Color(0xFF0E700E);
  static const successStroke = Color(0xFF9FD89F);

  static const warningBackground = Color(0xFFFFF9F5);
  static const warningForeground = Color(0xFFBC4B09);
  static const warningStroke = Color(0xFFFDCFB4);
  static const warningSolid = Color(0xFFF7630C);

  static const dangerBackground = Color(0xFFFDF3F4);
  static const dangerForeground = Color(0xFFB10E1C);
  static const dangerStroke = Color(0xFFEEACB2);
  static const dangerSolid = Color(0xFFC50F1F);

  static const infoBackground = brand160;
  static const infoForeground = brand60;
  static const infoStroke = brand140;
  static const infoSolid = brand80;

  // Weather semantics: temperature
  static const temperatureCold = Color(0xFF0F548C);
  static const temperatureHot = Color(0xFFC50F1F);
  static const temperatureBarCold = Color(0xFF62ABF5); // <= 15°C
  static const temperatureBarMild = Color(0xFF5EC75A); // 16–22°C
  static const temperatureBarWarm = Color(0xFFF7A33C); // 23–28°C
  static const temperatureBarHot = Color(0xFFE8474F); // >= 29°C

  // Rain probability / rainfall amounts
  static const rainForeground = Color(0xFF115EA3);
  static const rainBackground = Color(0xFFEBF3FC);
  static const rainBar = Color(0xFF479EF5);
  static const rainBarTrack = Color(0xFFE6EEF7);

  // Weather condition icon tints (icons only, never body text)
  static const iconSun = Color(0xFFE8A300);
  static const iconCloud = Color(0xFF8A8A8A);
  static const iconRain = Color(0xFF2886DE);
  static const iconThunder = Color(0xFF8764B8);
  static const iconFog = Color(0xFFA0A0A0);

  // CWA rain-warning levels: 1 大雨, 2 豪雨, 3 大豪雨, 4 超大豪雨
  static const alert1Background = Color(0xFFFFFAD6);
  static const alert1Foreground = Color(0xFF6B5D00);
  static const alert1Stroke = Color(0xFFF2D94E);
  static const alert1Solid = Color(0xFFFDE300);
  static const alert2Background = warningBackground;
  static const alert2Foreground = warningForeground;
  static const alert2Stroke = warningStroke;
  static const alert2Solid = warningSolid;
  static const alert3Background = dangerBackground;
  static const alert3Foreground = dangerForeground;
  static const alert3Stroke = dangerStroke;
  static const alert3Solid = dangerSolid;
  static const alert4Background = Color(0xFFF7F4FB);
  static const alert4Foreground = Color(0xFF5C2E91);
  static const alert4Stroke = Color(0xFFC6B1DE);
  static const alert4Solid = Color(0xFF5C2E91);

  // DATA-VIZ EXCEPTION (contract acceptance 8): CWA radar reflectivity scale,
  // exactly the colours CWA draws, so legend, timeline bars and the radar
  // overlay agree. Index = dBZ (0–65). Source: legend bar of the website frame
  // CV1_3600_202611142230 (column 3453, rows 2507–3571): 66 equal 16-row
  // steps, 65 dBZ at the top down to 0 at the bottom; the website station
  // images use the same 66 colours. The radar processor keys echo pixels by
  // these colours (radarEchoPalette), so they must stay CWA's values.
  // Legends must always label numbers.
  static const dbzScale = <Color>[
    Color(0xFF00FFFF), Color(0xFF00ECFF), Color(0xFF00DAFF), Color(0xFF00C8FF), Color(0xFF00B6FF), Color(0xFF00A3FF), // 0–5 dBZ
    Color(0xFF0091FF), Color(0xFF007FFF), Color(0xFF006DFF), Color(0xFF005BFF), Color(0xFF0048FF), Color(0xFF0036FF), // 6–11 dBZ
    Color(0xFF0024FF), Color(0xFF0012FF), Color(0xFF0000FF), Color(0xFF00FF00), Color(0xFF00F400), Color(0xFF00E900), // 12–17 dBZ
    Color(0xFF00DE00), Color(0xFF00D300), Color(0xFF00C800), Color(0xFF00BE00), Color(0xFF00B400), Color(0xFF00AA00), // 18–23 dBZ
    Color(0xFF00A000), Color(0xFF009600), Color(0xFF33AB00), Color(0xFF66C000), Color(0xFF99D500), Color(0xFFCCEA00), // 24–29 dBZ
    Color(0xFFFFFF00), Color(0xFFFFF400), Color(0xFFFFE900), Color(0xFFFFDE00), Color(0xFFFFD300), Color(0xFFFFC800), // 30–35 dBZ
    Color(0xFFFFB800), Color(0xFFFFA800), Color(0xFFFF9800), Color(0xFFFF8800), Color(0xFFFF7800), Color(0xFFFF6000), // 36–41 dBZ
    Color(0xFFFF4800), Color(0xFFFF3000), Color(0xFFFF1800), Color(0xFFFF0000), Color(0xFFF40000), Color(0xFFE90000), // 42–47 dBZ
    Color(0xFFDE0000), Color(0xFFD30000), Color(0xFFC80000), Color(0xFFBE0000), Color(0xFFB40000), Color(0xFFAA0000), // 48–53 dBZ
    Color(0xFFA00000), Color(0xFF960000), Color(0xFFAB0033), Color(0xFFC00066), Color(0xFFD50099), Color(0xFFEA00CC), // 54–59 dBZ
    Color(0xFFFF00FF), Color(0xFFEA00FF), Color(0xFFD500FF), Color(0xFFC000FF), Color(0xFFAB00FF), Color(0xFF9600FF), // 60–65 dBZ
  ];

  // DATA-VIZ EXCEPTION: CWA daily accumulated rainfall map (O-A0040-002) scale,
  // sampled from the legend bar of the CWA image. Low → high, 17 bands:
  // <1, 1–2, 2–6, 6–10, 10–15, 15–20, 20–30, 30–40, 40–50, 50–70, 70–90,
  // 90–110, 110–130, 130–150, 150–200, 200–300, ≥300 mm. Legends must label numbers.
  static const rainfallMapScale = [
    Color(0xFFCACACA),
    Color(0xFF9EFDFF),
    Color(0xFF01D2FD),
    Color(0xFF00A5FE),
    Color(0xFF0177FD),
    Color(0xFF27A31C),
    Color(0xFF02F930),
    Color(0xFFFEFD31),
    Color(0xFFFFD328),
    Color(0xFFFFA71F),
    Color(0xFFFF2B06),
    Color(0xFFDA2304),
    Color(0xFFAA1802),
    Color(0xFFAA21A3),
    Color(0xFFDC2DD2),
    Color(0xFFFF38FB),
    Color(0xFFFFD6FD),
  ];
}

/// `--space-*` tokens (4px grid).
abstract final class AppSpace {
  static const double s0 = 0;
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
}

/// Material 3 shape scale (`--shape-*`).
abstract final class AppRadius {
  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double extraLarge = 28;
  static const double full = 9999;
}

/// `--stroke-*` widths.
abstract final class AppStroke {
  static const double thin = 1;
  static const double thick = 2;
  static const double thicker = 3;
}

/// `--size-*` tokens.
abstract final class AppSize {
  static const double touch = 44;
  static const double control = 44;
  static const double controlSmall = 32;
  static const double listRowOneLine = 56;
  static const double listRowTwoLine = 64;
  static const double appBar = 56;
  static const double bottomNavigationBar = 64;
  static const double icon16 = 16;
  static const double icon20 = 20;
  static const double icon24 = 24;
  static const double icon32 = 32;
  static const double icon48 = 48;
  static const double icon64 = 64;
  static const double sliderTrack = 4;
  static const double sliderThumb = 20;
  static const double legendBar = 8;
  static const double spinner = 20;
  static const double dot = 8;
}

/// Window size-class thresholds (logical px, lower bound of each class).
/// Width: Material 3 window size classes. Height: compact < 480 catches short
/// landscape windows (720x360 at 2x). Read through `WindowSizeClass`, never
/// compare sizes against these directly in screens.
abstract final class AppBreakpoint {
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;
  static const double heightMedium = 480;
  static const double heightExpanded = 900;
}

/// Fluid page grid (`AppGrid`) and reading width.
abstract final class AppLayout {
  /// Narrowest page column: the phone card width the cards were designed at.
  static const double gridMinColumn = 340;
  static const int gridMaxColumns = 6;
  static const double gridGap = AppSpace.s16;

  /// Left/right page margin per width class (compact / medium / expanded+).
  static const double pageMarginCompact = AppSpace.s16;
  static const double pageMarginMedium = AppSpace.s24;
  static const double pageMarginExpanded = AppSpace.s32;

  /// Max width of a running-text block, banner text or button group's
  /// container inside a card. Cards fill their cell; only these are capped.
  static const double readingWidth = 640;

  /// Card content width from which a card may switch to its wide interior
  /// (metrics in one row, settings side by side, list + detail).
  static const double cardWideWidth = 520;

  /// `AppTwoPane` side pane: width = available × [paneSideShare], clamped to
  /// [paneMinWidth]…[paneMaxWidth]. [paneMinWidth] is also the smallest map
  /// box side and the min cell width of multi-column lists; [paneMaxWidth]
  /// caps a map that keeps its natural aspect ratio.
  static const double paneMinWidth = 320;
  static const double paneMaxWidth = 480;
  static const double paneSideShare = 0.4;
}

/// `--shadow-*` tokens (Fluent elevation, light theme).
abstract final class AppShadows {
  static const _ambient = Color(0x1F000000); // rgba(0,0,0,0.12)
  static const _key = Color(0x24000000); // rgba(0,0,0,0.14)

  static const s2 = [
    BoxShadow(color: _ambient, blurRadius: 2),
    BoxShadow(color: _key, offset: Offset(0, 1), blurRadius: 2),
  ];
  static const s4 = [
    BoxShadow(color: _ambient, blurRadius: 2),
    BoxShadow(color: _key, offset: Offset(0, 2), blurRadius: 4),
  ];
  static const s8 = [
    BoxShadow(color: _ambient, blurRadius: 2),
    BoxShadow(color: _key, offset: Offset(0, 4), blurRadius: 8),
  ];
}

/// `--duration-*` and `--curve-*` tokens.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 200);
  static const decelerateMiddle = Cubic(0, 0, 0, 1);
  static const easyEase = Cubic(0.33, 0, 0.67, 1);
}

/// Fluent type ramp (`--type-*`). Colour is not set; it comes from the
/// ambient [DefaultTextStyle] / theme (foreground1) unless a widget overrides it.
abstract final class AppType {
  static const _regular = FontWeight.w400;
  static const _semibold = FontWeight.w600;
  static const _even = TextLeadingDistribution.even;

  static const caption2 = TextStyle(fontSize: 10, height: 14 / 10, fontWeight: _regular, leadingDistribution: _even);
  static const caption1 = TextStyle(fontSize: 12, height: 16 / 12, fontWeight: _regular, leadingDistribution: _even);
  static const body1 = TextStyle(fontSize: 14, height: 20 / 14, fontWeight: _regular, leadingDistribution: _even);
  static const body1Strong = TextStyle(fontSize: 14, height: 20 / 14, fontWeight: _semibold, leadingDistribution: _even);
  static const body2 = TextStyle(fontSize: 16, height: 22 / 16, fontWeight: _regular, leadingDistribution: _even);
  static const subtitle2 = TextStyle(fontSize: 16, height: 22 / 16, fontWeight: _semibold, leadingDistribution: _even);
  static const subtitle1 = TextStyle(fontSize: 20, height: 28 / 20, fontWeight: _semibold, leadingDistribution: _even);

  /// Current temperature. CSS letter-spacing -0.02em at 68px.
  static const display =
      TextStyle(fontSize: 68, height: 92 / 68, fontWeight: _semibold, letterSpacing: -1.36, leadingDistribution: _even);

  /// `font-variant-numeric: tabular-nums`; apply via `style.copyWith(fontFeatures: AppType.tabular)`.
  static const tabular = [FontFeature.tabularFigures()];
}
