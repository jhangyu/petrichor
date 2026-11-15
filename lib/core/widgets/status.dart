import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'buttons.dart';

/// `.status-banner--*` tones.
enum StatusTone { loading, error, empty, permission, alert1, alert3 }

/// `.status-banner`: icon + title + optional text + optional actions row.
/// [StatusTone.loading] shows a [AppSpinner] instead of [icon].
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.tone,
    required this.title,
    this.text,
    this.icon,
    this.actions = const [],
  });

  final StatusTone tone;
  final String title;
  final String? text;

  /// Leading icon; defaults per tone (error → error_outline, …).
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final (bg, stroke, iconColor, defaultIcon) = switch (tone) {
      StatusTone.loading => (AppPalette.infoBg, AppPalette.infoStroke, AppPalette.infoFg, Icons.sync),
      StatusTone.error => (AppPalette.dangerBg, AppPalette.dangerStroke, AppPalette.dangerFg, Icons.error_outline),
      StatusTone.empty => (AppPalette.bg2, AppPalette.stroke2, AppPalette.fg3, Icons.cloud_off_outlined),
      StatusTone.permission =>
        (AppPalette.warningBg, AppPalette.warningStroke, AppPalette.warningFg, Icons.location_disabled_outlined),
      StatusTone.alert1 => (AppPalette.alert1Bg, AppPalette.alert1Stroke, AppPalette.alert1Fg, Icons.warning_amber),
      StatusTone.alert3 => (AppPalette.alert3Bg, AppPalette.alert3Stroke, AppPalette.alert3Fg, Icons.warning_amber),
    };
    final body = text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: stroke, width: AppStroke.thin),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tone == StatusTone.loading
              ? const AppSpinner()
              : Icon(icon ?? defaultIcon, size: AppSize.icon20, color: iconColor),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpace.s4,
              children: [
                Text(title, style: AppType.body1Strong.copyWith(color: AppPalette.fg1)),
                if (body != null) Text(body, style: AppType.body1.copyWith(color: AppPalette.fg2)),
                if (actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s4),
                    child: Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8, children: actions),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `.empty-state`: centred icon (48) + title + optional text + actions.
/// [error] tints the icon danger (`.empty-state__icon--error`).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.text,
    this.icon = Icons.cloud_off_outlined,
    this.error = false,
    this.actions = const [],
  });

  final String title;
  final String? text;
  final IconData icon;
  final bool error;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final body = text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24, vertical: AppSpace.s40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpace.s12,
        children: [
          Icon(icon, size: AppSize.icon48, color: error ? AppPalette.dangerFg : AppPalette.fg3),
          Text(title, textAlign: TextAlign.center, style: AppType.subtitle2.copyWith(color: AppPalette.fg1)),
          if (body != null)
            Text(body, textAlign: TextAlign.center, style: AppType.body1.copyWith(color: AppPalette.fg2)),
          if (actions.isNotEmpty)
            Wrap(alignment: WrapAlignment.center, spacing: AppSpace.s8, runSpacing: AppSpace.s8, children: actions),
        ],
      ),
    );
  }
}

/// `.spinner` (20, brand on brand-150 track).
class AppSpinner extends StatelessWidget {
  const AppSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: AppSize.spinner,
      child: CircularProgressIndicator(
        strokeWidth: AppStroke.thick,
        color: AppPalette.brandBg,
        backgroundColor: AppPalette.brand150,
      ),
    );
  }
}

/// `.skeleton` block (bg-6). Size it like the content it stands in for so
/// the layout does not jump when data arrives. [circle] = `.skeleton--circle`.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, required this.height, this.circle = false});

  final double? width;
  final double height;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppPalette.bg6,
        borderRadius: BorderRadius.circular(circle ? AppRadius.full : AppRadius.extraSmall),
      ),
    );
  }
}

/// Standard retry action used in error banners / empty states (「重試」).
class RetryButton extends StatelessWidget {
  const RetryButton({super.key, required this.onPressed, this.primary = false});

  final VoidCallback onPressed;

  /// Primary button (full-page error) vs small secondary (in a banner).
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: '重試',
      icon: Icons.refresh,
      onPressed: onPressed,
      variant: primary ? AppButtonVariant.primary : AppButtonVariant.secondary,
      small: !primary,
    );
  }
}
