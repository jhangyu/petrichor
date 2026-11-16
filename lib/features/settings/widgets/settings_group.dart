import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/taiwan_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status.dart';
import '../../../data/models/place.dart';

/// 「臺北市 中正區」
String placeLabel(Place p) => '${p.county} ${p.town}';

/// 「07:00」 for a minute of day.
String clockTextOfMinuteOfDay(int minute) =>
    '${twoDigits(minute ~/ Duration.minutesPerHour)}:${twoDigits(minute % Duration.minutesPerHour)}';

/// Error banner for unreadable stored data, with at most one small recovery button.
StatusBanner settingsErrorBanner({
  required String title,
  required String text,
  String? actionLabel,
  VoidCallback? onAction,
  AppButtonVariant variant = AppButtonVariant.secondary,
}) =>
    StatusBanner(
      tone: StatusTone.error,
      title: title,
      text: text,
      actions: [
        if (actionLabel != null) AppButton(label: actionLabel, variant: variant, small: true, onPressed: onAction),
      ],
    );

/// One settings group (spec §4): section title + meta above [body], optional [note] below.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, this.meta, required this.body, this.note});

  final String title;
  final String? meta;
  final Widget body;
  final Widget? note;

  @override
  Widget build(BuildContext context) {
    final metaText = meta;
    final footnote = note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s12,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          child: SectionHeader(
            title: title,
            trailing: metaText == null ? null : Text(metaText, style: AppType.caption1.copyWith(color: AppPalette.foreground3)),
          ),
        ),
        body,
        if (footnote != null) Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16), child: footnote),
      ],
    );
  }
}

/// `.list-row__leading--tint` (32 circle); [brand] = `--brand`. Pass [child] to replace the icon.
class SettingsTint extends StatelessWidget {
  const SettingsTint({super.key, this.icon, this.child, this.brand = false})
      : assert((icon == null) != (child == null), 'pass exactly one of icon or child');

  final IconData? icon;
  final Widget? child;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final glyph = icon;
    return Container(
      width: AppSize.controlSmall,
      height: AppSize.controlSmall,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: brand ? AppPalette.brandBackgroundSubtle : AppPalette.background3, shape: BoxShape.circle),
      child: glyph == null ? child : Icon(glyph, size: AppSize.icon20, color: brand ? AppPalette.brandForeground : AppPalette.foreground2),
    );
  }
}

/// Padded block inside a group (spec §4 `_Block`): s16 padding, items s16 apart.
class SettingsBlock extends StatelessWidget {
  const SettingsBlock({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: AppSpace.s16, children: children),
    );
  }
}

/// Footnote: small icon + caption, first line centred on the icon.
class SettingsNote extends StatelessWidget {
  const SettingsNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.s8,
      children: [
        SizedBox(height: AppSize.icon16, child: Center(child: Icon(icon, size: AppSize.icon16, color: AppPalette.foreground3))),
        Expanded(child: Text(text, style: AppType.caption1.copyWith(color: AppPalette.foreground3))),
      ],
    );
  }
}
