import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_key.dart';
import '../../core/layout/adaptive.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/status.dart';
import '../../data/repositories/weather_repository.dart';
import '../location/place_provider.dart';
import 'place_picker.dart';
import 'widgets/notification_card.dart';
import 'widgets/place_settings_card.dart';
import 'widgets/saved_places_card.dart';
import 'widgets/settings_parts.dart';
import 'widgets/token_card.dart';

/// Observation dataset behind the per-row weather of 儲存的地點.
const _observationDataset = 'O-A0003-001';

/// Why the page-level token banner shows (未設定 / 無效 only; 無法驗證 and 驗證中 show none).
enum _TokenProblem { notSet, invalid }

/// 設定 tab (spec `docs/design/settings/designer-1/settings.md`): 儲存的地點, 地點設定,
/// 通知設定, token 設定; the manual place picker replaces the page while open.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _tokenGroupKey = GlobalKey();
  bool _picking = false;
  bool _focusSearch = false;

  void _openPicker({required bool focusSearch}) => setState(() {
        _picking = true;
        _focusSearch = focusSearch;
      });

  void _closePicker() => setState(() => _picking = false);

  void _showTokenGroup() => Scrollable.ensureVisible(_tokenGroupKey.currentContext!, duration: AppMotion.normal);

  Future<void> _refreshWeather() async {
    final saved = ref.read(savedPlacesProvider).value ?? const [];
    await Future.wait([for (final p in saved) ref.refresh(placeObservationProvider(p).future)]);
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentPlaceProvider);
    if (_picking) {
      return PlacePicker(
        current: switch (current) {
          AsyncData(value: PlaceSelected(:final place)) => place,
          _ => null,
        },
        autofocus: _focusSearch,
        onClose: _closePicker,
      );
    }
    final problem = switch (ref.watch(apiKeyStatusProvider)) {
      ApiKeyNotSet() => _TokenProblem.notSet,
      ApiKeyInvalid(kind: ApiKeyInvalidKind.rejected || ApiKeyInvalidKind.unreadable) => _TokenProblem.invalid,
      _ => null,
    };
    return AppPageScaffold(
      header: AppPageHeader(title: '設定', subtitle: _subtitle(problem, current)),
      source: _hasObservation() ? const SourceLine(datasetIds: [_observationDataset]) : null,
      onRefresh: _refreshWeather,
      children: [
        if (problem != null) AppGridItem.full(child: _tokenBanner(problem)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.s16,
          children: [
            SavedPlacesCard(onAdd: () => _openPicker(focusSearch: false)),
            PlaceSettingsCard(onSearch: () => _openPicker(focusSearch: true)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.s16,
          children: [
            const NotificationSettingsCard(),
            KeyedSubtree(key: _tokenGroupKey, child: const TokenSettingsCard()),
          ],
        ),
      ],
    );
  }

  /// True when at least one saved place shows a successful observation.
  bool _hasObservation() {
    final saved = ref.watch(savedPlacesProvider).value ?? const [];
    return saved.any((p) => ref.watch(placeObservationProvider(p)).value is Success);
  }

  String? _subtitle(_TokenProblem? problem, AsyncValue<CurrentPlace> current) {
    if (problem == _TokenProblem.notSet) return '尚未設定 API 授權碼';
    if (problem == _TokenProblem.invalid) return 'API 授權碼無效';
    return switch (current) {
      AsyncData(value: PlaceSelected(:final place, :final source)) =>
        '目前地點 ${placeLabel(place)} · ${source == PlaceSource.gps ? 'GPS 定位' : '手動選擇'}',
      AsyncData() => '尚未選擇地點',
      AsyncError() => '無法讀取地點設定',
      _ => '定位中…',
    };
  }

  Widget _tokenBanner(_TokenProblem problem) {
    final notSet = problem == _TokenProblem.notSet;
    return StatusBanner(
      tone: StatusTone.error,
      icon: Icons.key_outlined,
      title: notSet ? '尚未設定 API 授權碼' : 'API 授權碼無效',
      text: notSet ? '輸入中央氣象署 API 授權碼後，才能取得天氣、雨量與警特報資料。' : '中央氣象署無法接受目前的授權碼，請更新後再試。',
      actions: [
        AppButton(
          label: notSet ? '輸入授權碼' : '更新授權碼',
          variant: AppButtonVariant.primary,
          small: true,
          onPressed: _showTokenGroup,
        ),
      ],
    );
  }
}
