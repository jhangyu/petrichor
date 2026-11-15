import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/stored_setting.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/data_display.dart';
import '../../../core/widgets/status.dart';
import '../../../data/models/place.dart';
import '../../location/place_provider.dart';
import '../notification_settings.dart';
import 'notification_parts.dart';
import 'settings_parts.dart';

/// 通知設定 group (settings only: nothing is delivered yet).
class NotificationSettingsCard extends ConsumerStatefulWidget {
  const NotificationSettingsCard({super.key});

  @override
  ConsumerState<NotificationSettingsCard> createState() => _NotificationSettingsCardState();
}

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
      setState(() => _quietError = '開始與結束時間相同，靜音時段無效。實際：${clockOfMinute(start)} 至 ${clockOfMinute(end)}');
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
        SettingsBlock(children: [
          settingsErrorBanner(
            title: '無法讀取通知設定',
            text: causes,
            actionLabel: '重設為預設值',
            onAction: _resetScalars,
          ),
        ]),
      ]);
    } else if (scalars.any((s) => !s.hasValue)) {
      body = const AppCard.loading(skeletonHeight: AppSize.touch * 3);
    } else {
      body = AppList(children: _rows(toggles, edges, masterOn));
    }

    return SettingsGroup(
      title: '通知設定',
      meta: masterOn ? '偏好已儲存' : '已關閉',
      body: body,
      note: const SettingsNote(icon: Icons.info_outline, text: '目前只儲存通知偏好，App 尚未發送任何通知。'),
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
    final window = '${clockOfMinute(start)} 至 ${crosses ? '隔日 ' : ''}${clockOfMinute(end)}';

    return [
      NotifySwitchRow(
        icon: Icons.notifications_outlined,
        title: '通知',
        subtitle: masterOn ? '總開關：關閉時下列設定保留但不套用' : '已關閉：下列設定保留但不套用',
        value: masterOn,
        brand: masterOn,
        onChanged: (v) => ref.read(notifyToggleProvider(NotifyToggle.master).notifier).set(v),
      ),
      const NotifyGroupLabel('分區警特報通知'),
      ..._placeRows(masterOn),
      const NotifyGroupLabel('其他'),
      NotifySwitchRow(
        icon: Icons.umbrella_outlined,
        title: '降雨提醒',
        subtitle: '目前地點未來 1 小時可能降雨時',
        value: rainOn,
        enabled: masterOn,
        onChanged: (v) => ref.read(notifyToggleProvider(NotifyToggle.rain).notifier).set(v),
      ),
      NotifySwitchRow(
        icon: Icons.bedtime_outlined,
        title: '靜音時段',
        subtitle: quietOn ? (crosses ? '$window · 跨午夜' : window) : '未開啟',
        value: quietOn,
        enabled: masterOn,
        onChanged: (v) => ref.read(notifyToggleProvider(NotifyToggle.quiet).notifier).set(v),
      ),
      if (quietOn) ...[
        QuietTimeRow(
          title: '開始',
          minute: start,
          enabled: masterOn,
          onTap: () => _pickTime(QuietEdge.start, start, end),
        ),
        QuietTimeRow(
          title: '結束',
          minute: end,
          nextDay: crosses,
          enabled: masterOn,
          onTap: () => _pickTime(QuietEdge.end, end, start),
        ),
        if (_quietError case final error?)
          SettingsBlock(children: [StatusBanner(tone: StatusTone.error, title: error)]),
        QuietHoursBar(start: start, end: end, label: '靜音時段：$window'),
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
          SettingsBlock(children: [
            settingsErrorBanner(
              title: '無法讀取分區警特報設定',
              text: '$error',
              actionLabel: '重設分區警特報',
              // setPlace overwrites the whole corrupt set; the place is switched off.
              onAction: () => ref
                  .read(warningAreasProvider.notifier)
                  .setPlace(saved.requireValue.first, false),
            ),
          ]),
        ];
      }
      return [SettingsBlock(children: [settingsErrorBanner(title: '無法讀取已儲存的地點', text: '$error')])];
    }
    final places = saved.value;
    final on = areas.value;
    if (places == null || on == null) return const [AppListRow(enabled: false, primary: '讀取中…')];
    if (places.isEmpty) return const [none];
    return [
      for (final Place p in places)
        NotifySwitchRow(
          icon: Icons.warning_amber_outlined,
          title: placeLabel(p),
          subtitle: '依${p.county}的警特報',
          value: on.contains(p.areaKey),
          enabled: masterOn,
          onChanged: (v) => ref.read(warningAreasProvider.notifier).setPlace(p, v),
        ),
    ];
  }
}
