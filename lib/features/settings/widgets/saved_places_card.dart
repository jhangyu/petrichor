import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/taiwan_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/data_display.dart';
import '../../../core/widgets/status.dart';
import '../../../data/models/place.dart';
import '../../../data/models/weather_models.dart';
import '../../../core/api/result.dart';
import '../../location/place_provider.dart';
import '../../weather/widgets/weather_format.dart';
import '../../weather/widgets/weather_glyph_icon.dart';
import 'settings_parts.dart';

/// Skeleton height while the saved-place list loads (three rows).
const _loadingHeight = AppSize.touch * 3;

/// 儲存的地點 (spec §5): saved places with per-row weather, select, remove, and the add row.
class SavedPlacesCard extends ConsumerWidget {
  const SavedPlacesCard({super.key, required this.onAdd});

  /// Opens the manual place picker.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentPlaceProvider).value;
    final currentKey = switch (current) {
      PlaceSelected(:final place) => place.areaKey,
      _ => null,
    };
    final usingGps = current is PlaceSelected && current.source == PlaceSource.gps;
    final addRow = AppListRow(
      leading: const SettingsTint(icon: Icons.add, brand: true),
      primary: '新增地點',
      trailing: const Icon(Icons.chevron_right, size: AppSize.icon20, color: AppPalette.fg3),
      onTap: onAdd,
    );
    return switch (ref.watch(savedPlacesProvider)) {
      AsyncData(value: final saved) => SettingsGroup(
          title: '儲存的地點',
          meta: '${saved.length} 個地點',
          body: AppList(children: [
            if (saved.isEmpty)
              const SettingsBlock(children: [
                StatusBanner(
                  tone: StatusTone.empty,
                  icon: Icons.bookmark_outline,
                  title: '尚未儲存地點',
                  text: '儲存地點後，可快速切換、查看各地現況，並分別設定警特報通知。',
                ),
              ]),
            for (final p in saved) _SavedPlaceRow(place: p, isCurrent: p.areaKey == currentKey),
            addRow,
          ]),
          note: usingGps
              ? const SettingsNote(
                  icon: Icons.info_outline,
                  text: '目前使用 GPS 定位（見「地點設定」）。點選儲存的地點會改用該地點並關閉自動定位。',
                )
              : null,
        ),
      AsyncError(:final error) => SettingsGroup(
          title: '儲存的地點',
          body: settingsErrorBanner(
            title: '無法讀取已儲存的地點',
            text: '$error',
            actionLabel: '清除已儲存的地點',
            variant: AppButtonVariant.primary,
            onAction: () => ref.read(savedPlacesProvider.notifier).clear(),
          ),
        ),
      _ => const SettingsGroup(title: '儲存的地點', body: AppCard.loading(skeletonHeight: _loadingHeight)),
    };
  }
}

class _SavedPlaceRow extends ConsumerWidget {
  const _SavedPlaceRow({required this.place, required this.isCurrent});

  final Place place;
  final bool isCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = placeLabel(place);
    final weather = _weatherView(ref.watch(placeObservationProvider(place)));
    return Semantics(
      label: [name, if (isCurrent) '目前地點', weather.spoken].join('，'),
      child: AppListRow(
        flushTrailing: true,
        leading: const SettingsTint(icon: Icons.bookmark_outline),
        primary: name,
        secondary: weather.secondary,
        selected: isCurrent,
        onTap: () => ref.read(currentPlaceProvider.notifier).select(place),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpace.s8,
          children: [
            if (isCurrent) const AppBadge(label: '使用中', tone: BadgeTone.brand),
            ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpace.s4,
                children: [weather.glyph, SizedBox(width: AppSize.icon32, child: weather.temp)],
              ),
            ),
            AppIconButton(
              icon: Icons.delete_outline,
              tooltip: '移除$name',
              onPressed: () => ref.read(savedPlacesProvider.notifier).remove(place),
            ),
          ],
        ),
      ),
    );
  }
}

/// What one row shows for its observation state (spec §5 table).
typedef _WeatherView = ({Widget glyph, Widget temp, String secondary, String spoken});

_WeatherView _weatherView(AsyncValue<Result<CurrentWeather>> observation) {
  switch (observation) {
    case AsyncData(value: Success(:final data)):
      final text = data.weather;
      return (
        glyph: WeatherGlyphIcon(text: text, size: AppSize.icon20),
        temp: _temp(tempText(data.temperature), strong: true),
        secondary: '${text ?? '無天氣現象資料'} · 觀測 ${clockText(data.observedAt)}',
        spoken: '${text ?? '無天氣現象資料'} ${data.temperature.round()} 度',
      );
    case AsyncData(value: Failure(:final apiKeyIssue, :final message)):
      return switch (apiKeyIssue) {
        ApiKeyIssue.missing || ApiKeyIssue.unreadable => _unavailable(Icons.key_outlined, '需要 API 授權碼'),
        ApiKeyIssue.rejected => _unavailable(Icons.key_outlined, 'API 授權碼無效'),
        null => _unavailable(Icons.cloud_off_outlined, '無法取得天氣：$message'),
      };
    case AsyncError(:final error):
      return _unavailable(Icons.cloud_off_outlined, '無法取得天氣：$error');
    default:
      return (
        glyph: const Skeleton(width: AppSize.icon20, height: AppSize.icon20, circle: true),
        temp: const Align(
          alignment: Alignment.centerRight,
          child: Skeleton(width: AppSize.icon32, height: AppSpace.s16),
        ),
        secondary: '讀取天氣中…',
        spoken: '天氣載入中',
      );
  }
}

_WeatherView _unavailable(IconData icon, String secondary) => (
      glyph: Icon(icon, size: AppSize.icon20, color: AppPalette.fg3),
      temp: _temp('—', strong: false),
      secondary: secondary,
      spoken: secondary,
    );

Widget _temp(String text, {required bool strong}) => Text(
      text,
      textAlign: TextAlign.end,
      maxLines: 1,
      style: (strong ? AppType.body1Strong : AppType.body1)
          .copyWith(color: strong ? AppPalette.fg1 : AppPalette.fg3, fontFeatures: AppType.tabular),
    );
