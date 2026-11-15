import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choices.dart';
import '../../../core/widgets/data_display.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/status.dart';
import '../../location/place_provider.dart';
import '../../../core/time/taiwan_time.dart';
import 'settings_parts.dart';

/// 地點設定 (spec §6): manual search entry, the auto-locate switch and its state, in one group.
class PlaceSettingsCard extends ConsumerWidget {
  const PlaceSettingsCard({super.key, required this.onSearch});

  /// Opens the manual place picker with the search field focused.
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentPlaceProvider);
    final notifier = ref.read(currentPlaceProvider.notifier);
    // Locating (first load or useGps) shows the switch on; a corrupt record shows it off.
    final autoLocate = switch (current) {
      AsyncData(:final value) => value.autoLocate,
      AsyncError() => false,
      _ => true,
    };
    final manualPlace = switch (current) {
      AsyncData(value: PlaceSelected(:final place, source: PlaceSource.manual)) => place,
      _ => null,
    };
    final failure = switch (current) {
      AsyncData(value: final NoPlace none) when none.kind == NoPlaceKind.locationFailed => none,
      _ => null,
    };
    return SettingsGroup(
      title: '地點設定',
      body: AppList(children: [
        SettingsBlock(children: [
          AppTextField(
            variant: AppTextFieldVariant.search,
            readOnly: true,
            label: '手動搜尋地點',
            hint: '搜尋縣市或鄉鎮市區',
            prefixIcon: Icons.search,
            onTap: onSearch,
          ),
        ]),
        AppListRow(
          leading: SettingsTint(icon: Icons.my_location, brand: autoLocate),
          primary: '自動定位',
          secondary: autoLocate
              ? '啟動時以 GPS 取得所在鄉鎮'
              : manualPlace == null
                  ? '已關閉：尚未選擇地點'
                  : '已關閉：使用儲存的地點「${placeLabel(manualPlace)}」',
          onTap: () => autoLocate ? notifier.stopAutoLocate() : notifier.useGps(),
          trailing: AppSwitch(
            value: autoLocate,
            semanticLabel: '自動定位',
            onChanged: (on) => on ? notifier.useGps() : notifier.stopAutoLocate(),
          ),
        ),
        ..._status(context, ref, current, failure),
      ]),
      note: failure == null
          ? null
          : const SettingsNote(icon: Icons.info_outline, text: '自動定位保持開啟；在取得權限前，App 沒有可用地點。'),
    );
  }

  List<Widget> _status(BuildContext context, WidgetRef ref, AsyncValue<CurrentPlace> current, NoPlace? failure) {
    final relocate = ref.read(currentPlaceProvider.notifier).useGps;
    return switch (current) {
      AsyncData(value: PlaceSelected(source: PlaceSource.gps, :final place, :final fixedAt)) => [
          AppListRow(
            selected: true,
            flushTrailing: true,
            leading: const SettingsTint(icon: Icons.check_circle_outline),
            primary: '已定位：${placeLabel(place)}',
            secondary: fixedAt == null ? null : '定位於 ${clockText(fixedAt)}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpace.s8,
              children: [
                const AppBadge(label: '使用中', tone: BadgeTone.brand),
                AppIconButton(icon: Icons.refresh, tooltip: '重新定位', onPressed: relocate),
              ],
            ),
          ),
        ],
      AsyncLoading() => [
          Semantics(
            liveRegion: true,
            child: const AppListRow(
              flushTrailing: true,
              leading: SettingsTint(child: AppSpinner()),
              primary: '定位中…',
              secondary: '正在取得目前位置',
              trailing: AppIconButton(icon: Icons.refresh, tooltip: '重新定位', onPressed: null),
            ),
          ),
        ],
      AsyncError(:final error) => [
          SettingsBlock(children: [
            settingsErrorBanner(
              title: '無法讀取地點設定',
              text: '$error',
              actionLabel: '改用 GPS 定位',
              variant: AppButtonVariant.primary,
              onAction: relocate,
            ),
          ]),
        ],
      _ when failure != null => [SettingsBlock(children: [_failureBanner(context, failure, relocate)])],
      _ => const [],
    };
  }

  Widget _failureBanner(BuildContext context, NoPlace none, Future<void> Function() relocate) {
    final guidance = '${locationFailureMessage(none.reason)}\n原因：${none.cause}';
    final retry = RetryButton(onPressed: relocate);
    return switch (none.reason) {
      LocationFailure.permissionDenied || LocationFailure.permissionDeniedForever => StatusBanner(
          tone: StatusTone.permission,
          title: none.reason == LocationFailure.permissionDenied ? '未取得位置權限' : '位置權限已關閉',
          text: guidance,
          actions: [_openSettingsButton(context, Geolocator.openAppSettings), retry],
        ),
      LocationFailure.serviceDisabled => StatusBanner(
          tone: StatusTone.error,
          title: '定位服務已關閉',
          text: guidance,
          actions: [_openSettingsButton(context, Geolocator.openLocationSettings), retry],
        ),
      LocationFailure.positionUnavailable || LocationFailure.addressUnresolved => StatusBanner(
          tone: StatusTone.error,
          title: '無法取得目前位置',
          text: guidance,
          actions: [retry],
        ),
    };
  }

  Widget _openSettingsButton(BuildContext context, Future<bool> Function() open) => AppButton(
        label: '前往設定',
        variant: AppButtonVariant.primary,
        small: true,
        onPressed: () => _openSystemSettings(context, open),
      );
}

/// Opens a system settings page; tells the user when the platform refuses.
Future<void> _openSystemSettings(BuildContext context, Future<bool> Function() open) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!await open()) {
    messenger.showSnackBar(const SnackBar(content: Text('無法開啟系統設定，請手動到系統設定開啟本 App 的位置權限')));
  }
}
