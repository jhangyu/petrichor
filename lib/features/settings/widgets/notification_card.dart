import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/stored_setting.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choices.dart';
import '../../../core/widgets/data_display.dart';
import '../../../core/widgets/status.dart';
import '../../../data/models/place.dart';
import '../../location/place_provider.dart';
import '../notification_settings.dart';

/// 通知設定 group (settings only: nothing is delivered yet).
class NotificationSettingsCard extends ConsumerStatefulWidget {
  const NotificationSettingsCard({super.key});

  @override
  ConsumerState<NotificationSettingsCard> createState() => _NotificationSettingsCardState();
}

String _clock(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

class _NotificationSettingsCardState extends ConsumerState<NotificationSettingsCard> {
  /// Set when a picked time equals the other edge; the previous value is kept.
  String? _quietError;

  Future<void> _pickTime(QuietEdge edge, int current, int other) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null || !mounted) return;
    final minute = picked.hour * 60 + picked.minute;
    if (minute == other) {
      final (start, end) = edge == QuietEdge.start ? (minute, other) : (other, minute);
      setState(() => _quietError = '開始與結束時間相同，靜音時段無效。實際：${_clock(start)} 至 ${_clock(end)}');
      return;
    }
    setState(() => _quietError = null);
    await ref.read(quietMinuteProvider(edge).notifier).set(minute);
  }

  /// Overwrites every unreadable scalar setting with its default (explicit user action).
  Future<void> _resetScalars() async {
    for (final toggle in NotifyToggle.values) {
      if (ref.read(notifyToggleProvider(toggle)).hasError) {
        await ref.read(notifyToggleProvider(toggle).notifier).set(false);
      }
    }
    for (final edge in QuietEdge.values) {
      if (ref.read(quietMinuteProvider(edge)).hasError) {
        final defaults = ref.read(quietMinuteProvider(edge).notifier).defaultValue;
        await ref.read(quietMinuteProvider(edge).notifier).set(defaults);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final toggles = {for (final t in NotifyToggle.values) t: ref.watch(notifyToggleProvider(t))};
    final edges = {for (final e in QuietEdge.values) e: ref.watch(quietMinuteProvider(e))};
    final scalars = [...toggles.values, ...edges.values];
    final masterOn = toggles[NotifyToggle.master]!.value ?? false;

    final Widget body;
    if (scalars.any((s) => s.hasError)) {
      final causes = scalars.where((s) => s.hasError).map((s) => '${s.error}').toSet().join('\n');
      body = AppList(children: [
        _Block(children: [
          StatusBanner(
            tone: StatusTone.error,
            title: '無法讀取通知設定',
            text: causes,
            actions: [AppButton(label: '重設為預設值', small: true, onPressed: _resetScalars)],
          ),
        ]),
      ]);
    } else if (scalars.any((s) => !s.hasValue)) {
      body = const AppCard.loading(skeletonHeight: AppSize.touch * 3);
    } else {
      body = AppList(children: _rows(toggles, edges, masterOn));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s12,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          child: SectionHeader(
            title: '通知設定',
            trailing: Text(masterOn ? '偏好已儲存' : '已關閉', style: AppType.caption1.copyWith(color: AppPalette.fg3)),
          ),
        ),
        body,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpace.s16),
          child: _Note(icon: Icons.info_outline, text: '目前只儲存通知偏好，App 尚未發送任何通知。'),
        ),
      ],
    );
  }

  List<Widget> _rows(
    Map<NotifyToggle, AsyncValue<bool>> toggles,
    Map<QuietEdge, AsyncValue<int>> edges,
    bool masterOn,
  ) {
    final rainOn = toggles[NotifyToggle.rain]!.requireValue;
    final quietOn = toggles[NotifyToggle.quiet]!.requireValue;
    final start = edges[QuietEdge.start]!.requireValue;
    final end = edges[QuietEdge.end]!.requireValue;
    final crosses = start > end;
    final window = '${_clock(start)} 至 ${crosses ? '隔日 ' : ''}${_clock(end)}';

    return [
      _SwitchRow(
        icon: Icons.notifications_outlined,
        title: '通知',
        subtitle: masterOn ? '總開關：關閉時下列設定保留但不套用' : '已關閉：下列設定保留但不套用',
        value: masterOn,
        brand: masterOn,
        onChanged: (v) => ref.read(notifyToggleProvider(NotifyToggle.master).notifier).set(v),
      ),
      const _GroupLabel('分區警特報通知'),
      ..._placeRows(masterOn),
      const _GroupLabel('其他'),
      _SwitchRow(
        icon: Icons.umbrella_outlined,
        title: '降雨提醒',
        subtitle: '目前地點未來 1 小時可能降雨時',
        value: rainOn,
        enabled: masterOn,
        onChanged: (v) => ref.read(notifyToggleProvider(NotifyToggle.rain).notifier).set(v),
      ),
      _SwitchRow(
        icon: Icons.bedtime_outlined,
        title: '靜音時段',
        subtitle: quietOn ? (crosses ? '$window · 跨午夜' : window) : '未開啟',
        value: quietOn,
        enabled: masterOn,
        onChanged: (v) => ref.read(notifyToggleProvider(NotifyToggle.quiet).notifier).set(v),
      ),
      if (quietOn) ...[
        _TimeRow(
          title: '開始',
          minute: start,
          enabled: masterOn,
          onTap: () => _pickTime(QuietEdge.start, start, end),
        ),
        _TimeRow(
          title: '結束',
          minute: end,
          nextDay: crosses,
          enabled: masterOn,
          onTap: () => _pickTime(QuietEdge.end, end, start),
        ),
        if (_quietError case final error?)
          _Block(children: [StatusBanner(tone: StatusTone.error, title: error)]),
        _QuietHoursBar(start: start, end: end, label: '靜音時段：$window'),
      ],
    ];
  }

  List<Widget> _placeRows(bool masterOn) {
    final saved = ref.watch(savedPlacesProvider);
    final areas = ref.watch(warningAreasProvider);
    const none = AppListRow(enabled: false, primary: '尚無儲存的地點', secondary: '先在「儲存的地點」新增');

    final error = saved.error ?? areas.error;
    if (error != null) {
      if (error is StoredSettingException) {
        return [
          _Block(children: [
            StatusBanner(
              tone: StatusTone.error,
              title: '無法讀取分區警特報設定',
              text: '$error',
              actions: [
                AppButton(
                  label: '重設分區警特報',
                  small: true,
                  // setPlace overwrites the whole corrupt set; the place is switched off.
                  onPressed: () => ref
                      .read(warningAreasProvider.notifier)
                      .setPlace(saved.requireValue.first, false),
                ),
              ],
            ),
          ]),
        ];
      }
      return [_Block(children: [StatusBanner(tone: StatusTone.error, title: '無法讀取已儲存的地點', text: '$error')])];
    }
    final places = saved.value;
    final on = areas.value;
    if (places == null || on == null) return const [AppListRow(enabled: false, primary: '讀取中…')];
    if (places.isEmpty) return const [none];
    return [
      for (final Place p in places)
        _SwitchRow(
          icon: Icons.warning_amber_outlined,
          title: '${p.county} ${p.town}',
          subtitle: '依${p.county}的警特報',
          value: on.contains(p.areaKey),
          enabled: masterOn,
          onChanged: (v) => ref.read(warningAreasProvider.notifier).setPlace(p, v),
        ),
    ];
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
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
      leading: _Tint(icon: icon, brand: brand),
      primary: title,
      secondary: subtitle,
      enabled: enabled,
      onTap: () => onChanged(!value),
      trailing: AppSwitch(value: value, semanticLabel: title, onChanged: enabled ? onChanged : null),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
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
      label: '靜音$title時間 ${nextDay ? '隔日 ' : ''}${_clock(minute)}',
      button: true,
      excludeSemantics: true,
      child: AppListRow(
        leading: const _Tint(icon: Icons.schedule),
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
                Text(_clock(minute),
                    style: AppType.body1Strong.copyWith(
                      color: enabled ? AppPalette.fg1 : AppPalette.fgDisabled,
                      fontFeatures: AppType.tabular,
                    )),
              ],
            ),
            const Icon(Icons.chevron_right, size: AppSize.icon20, color: AppPalette.fg3),
          ],
        ),
      ),
    );
  }
}

/// 24 h strip: ticks 0/6/12/18/24, segment(s) in brand colour. Starts on the 60 text column.
class _QuietHoursBar extends StatelessWidget {
  const _QuietHoursBar({required this.start, required this.end, required this.label});

  final int start;
  final int end;
  final String label;

  static const _textColumn = AppSpace.s16 + AppSize.controlSm + AppSpace.s12;
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
                      color: AppPalette.bg4,
                      borderRadius: BorderRadius.all(Radius.circular(AppRadius.full)),
                    ),
                  ),
                  for (final (from, to) in segments)
                    Positioned(
                      left: c.maxWidth * from / minutesPerDay,
                      width: c.maxWidth * (to - from) / minutesPerDay,
                      top: 0,
                      bottom: 0,
                      child: const ColoredBox(color: AppPalette.brandBg),
                    ),
                ]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final t in _ticks) Text('$t', style: AppType.caption1.copyWith(color: AppPalette.fg3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Padded block inside a group: padding s16, items s16 apart.
class _Block extends StatelessWidget {
  const _Block({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: AppSpace.s16, children: children),
    );
  }
}

/// Sub-label band (32 high, text centred).
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppPalette.bg2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
        child: Text(text, style: AppType.caption1.copyWith(color: AppPalette.fg3, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _Tint extends StatelessWidget {
  const _Tint({required this.icon, this.brand = false});

  final IconData icon;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSize.icon32,
      height: AppSize.icon32,
      decoration: BoxDecoration(color: brand ? AppPalette.brandBgSubtle : AppPalette.bg3, shape: BoxShape.circle),
      child: Icon(icon, size: AppSize.icon20, color: brand ? AppPalette.brandFg : AppPalette.fg2),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.s8,
      children: [
        Icon(icon, size: AppSize.icon16, color: AppPalette.fg3),
        Expanded(child: Text(text, style: AppType.caption1.copyWith(color: AppPalette.fg3))),
      ],
    );
  }
}
