import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/choices.dart';
import '../../../core/widgets/data_display.dart';
import '../notification_settings.dart';
import 'settings_group.dart';

class NotifySwitchRow extends StatelessWidget {
  const NotifySwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.brand = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final bool brand;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      leading: SettingsTint(icon: icon, brand: brand),
      primary: title,
      secondary: subtitle,
      enabled: enabled,
      onTap: () => onChanged(!value),
      trailing: AppSwitch(value: value, semanticLabel: title, onChanged: enabled ? onChanged : null),
    );
  }
}

class QuietTimeRow extends StatelessWidget {
  const QuietTimeRow({
    super.key,
    required this.title,
    required this.minute,
    required this.enabled,
    required this.onTap,
    this.nextDay = false,
  });

  final String title;
  final int minute;
  final bool enabled;
  final bool nextDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '靜音$title時間 ${nextDay ? '隔日 ' : ''}${clockOfMinute(minute)}',
      button: true,
      excludeSemantics: true,
      child: AppListRow(
        leading: const SettingsTint(icon: Icons.schedule),
        primary: title,
        enabled: enabled,
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpace.s8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpace.s4,
              children: [
                if (nextDay) const AppBadge(label: '隔日'),
                Text(clockOfMinute(minute),
                    style: AppType.body1Strong.copyWith(
                      color: enabled ? AppPalette.foreground1 : AppPalette.foregroundDisabled,
                      fontFeatures: AppType.tabular,
                    )),
              ],
            ),
            const Icon(Icons.chevron_right, size: AppSize.icon20, color: AppPalette.foreground3),
          ],
        ),
      ),
    );
  }
}

/// 24 h strip: ticks 0/6/12/18/24, segment(s) in brand colour. Starts on the 60 text column.
class QuietHoursBar extends StatelessWidget {
  const QuietHoursBar({super.key, required this.start, required this.end, required this.label});

  final int start;
  final int end;
  final String label;

  static const _textColumn = AppSpace.s16 + AppSize.controlSmall + AppSpace.s12;
  static const _ticks = [0, 6, 12, 18, 24];

  @override
  Widget build(BuildContext context) {
    final segments = start < end ? [(start, end)] : [(0, end), (start, minutesPerDay)];
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_textColumn, AppSpace.s16, AppSpace.s16, AppSpace.s16),
        child: Column(
          spacing: AppSpace.s4,
          children: [
            LayoutBuilder(
              builder: (context, c) => SizedBox(
                height: AppSize.dot,
                width: c.maxWidth,
                child: Stack(children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: AppPalette.background4,
                      borderRadius: BorderRadius.all(Radius.circular(AppRadius.full)),
                    ),
                  ),
                  for (final (from, to) in segments)
                    Positioned(
                      left: c.maxWidth * from / minutesPerDay,
                      width: c.maxWidth * (to - from) / minutesPerDay,
                      top: 0,
                      bottom: 0,
                      child: const ColoredBox(color: AppPalette.brandBackground),
                    ),
                ]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final t in _ticks) Text('$t', style: AppType.caption1.copyWith(color: AppPalette.foreground3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sub-label band (32 high, text centred).
class NotifyGroupLabel extends StatelessWidget {
  const NotifyGroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppPalette.background2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
        child: Text(text, style: AppType.caption1.copyWith(color: AppPalette.foreground3, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

