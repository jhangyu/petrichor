import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/choices.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/status.dart';
import '../../data/models/hazard_models.dart';
import '../../data/repositories/hazard_repository.dart' show warningBulletinsDataset, warningsByCountyDataset;
import '../../data/repositories/weather_repository.dart' show Failure, Success;
import '../location/place_provider.dart';
import 'hazard_provider.dart';
import 'warnings/warning_card.dart';
import 'warnings/warning_groups.dart';
import 'warnings/warnings_hero.dart';

/// Clock for 「即將生效」 vs 「生效中」 (tests may override).
final warningsClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// 警特報 tab (team-a/warnings.html): county-level warnings, all or the current place's county.
class WarningsScreen extends ConsumerStatefulWidget {
  const WarningsScreen({super.key});

  @override
  ConsumerState<WarningsScreen> createState() => _WarningsScreenState();
}

class _WarningsScreenState extends ConsumerState<WarningsScreen> {
  bool _mineOnly = false;

  void _retry() => ref.invalidate(activeWarningsProvider);

  Future<void> _refresh() async {
    ref.invalidate(activeWarningsProvider);
    await ref.read(activeWarningsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final placeAsync = ref.watch(currentPlaceProvider);
    return switch (placeAsync) {
      AsyncLoading() => _loading(),
      AsyncError(:final error) => _page(
          subtitle: '無法取得目前地點',
          children: [
            AppCard.error(title: '無法取得目前地點', message: '$error', onRetry: () => ref.invalidate(currentPlaceProvider)),
          ],
        ),
      AsyncData(value: NoPlace(:final reason)) => _page(
          children: [StatusBanner(tone: StatusTone.permission, title: '尚未選定地點', text: locationFailureMessage(reason))],
        ),
      AsyncData(value: PlaceSelected(:final place)) => _forPlace(place.county),
    };
  }

  Widget _forPlace(String county) {
    return switch (ref.watch(activeWarningsProvider)) {
      AsyncLoading() => _loading(),
      AsyncError(:final error) => _error('$error'),
      AsyncData(value: Failure(:final message)) => _error(message),
      AsyncData(value: Success(:final data)) => _data(data, county),
    };
  }

  Widget _data(ActiveWarnings active, String county) {
    final all = groupWarnings(active);
    final mine = groupsForCounty(all, county);
    final shown = _mineOnly ? mine : all;
    final now = ref.watch(warningsClockProvider)();
    final WarningsHero hero;
    if (_mineOnly) {
      hero = WarningsHero(
        label: shown.isEmpty ? '$county目前無警特報' : '$county目前生效',
        groups: shown,
        foot: shown.isEmpty ? null : (icon: Icons.schedule, text: WarningsHero.periodText(shown)),
        emptyText: '$county目前沒有生效中的警特報。',
      );
    } else {
      hero = WarningsHero(
        label: shown.isEmpty ? '目前無警特報' : '目前生效',
        groups: shown,
        foot: shown.isEmpty
            ? null
            : (
                icon: Icons.location_on_outlined,
                text: '影響 ${countyCount(shown)} 個縣市 · '
                    '${mine.isEmpty ? '你所在的$county目前無生效特報' : '你所在的$county有 ${mine.length} 項'}',
              ),
        emptyText: '全臺目前沒有生效中的警特報。',
      );
    }
    return _page(
      source: SourceLine(datasetIds: const [warningsByCountyDataset, warningBulletinsDataset]),
      children: [
        hero,
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            AppChip(label: '全部 ${all.length}', selected: !_mineOnly, onTap: () => setState(() => _mineOnly = false)),
            AppChip(
              label: '我的縣市 $county',
              icon: Icons.location_on_outlined,
              selected: _mineOnly,
              onTap: () => setState(() => _mineOnly = true),
            ),
          ],
        ),
        if (shown.isNotEmpty) ..._list(shown, county, now) else _empty(county, all.length),
      ],
    );
  }

  List<Widget> _list(List<WarningGroup> shown, String county, DateTime now) {
    return [
      SectionHeader(
        title: _mineOnly ? county : '生效中',
        trailing: Text(_mineOnly ? '${shown.length} 項' : '依等級排序',
            style: AppType.caption1.copyWith(color: AppPalette.fg3)),
      ),
      Column(
        spacing: AppSpace.s12,
        children: [
          for (var i = 0; i < shown.length; i++)
            WarningCard(
              // Key by content so an open card stays attached to its warning when the list changes.
              key: ValueKey((shown[i].name, shown[i].start, shown[i].end)),
              group: shown[i],
              now: now,
              initiallyOpen: i == 0,
            ),
        ],
      ),
    ];
  }

  Widget _empty(String county, int totalGroups) {
    final refresh = AppButton(label: '重新整理', icon: Icons.refresh, onPressed: _retry);
    if (_mineOnly) {
      return EmptyState(
        icon: Icons.warning_amber_outlined,
        title: '$county目前無警特報',
        text: '其他縣市有 $totalGroups 項生效中警特報，切換到「全部」查看。',
        actions: [refresh],
      );
    }
    return EmptyState(
      icon: Icons.warning_amber_outlined,
      title: '目前無警特報',
      text: '有新的警特報發布時，這裡會即時顯示。',
      actions: [refresh],
    );
  }

  Widget _loading() {
    return _page(
      subtitle: '更新中…',
      loading: true,
      children: [
        const StatusBanner(tone: StatusTone.loading, title: '載入警特報…'),
        const AppCard.loading(skeletonHeight: AppSize.icon64 + AppSpace.s32, hero: true),
        const AppCard.loading(skeletonHeight: AppSize.touch),
        const AppCard.loading(skeletonHeight: AppSize.touch),
      ],
    );
  }

  Widget _error(String message) {
    return _page(
      subtitle: '更新失敗',
      children: [
        StatusBanner(tone: StatusTone.error, title: '無法取得警特報', text: message, actions: [RetryButton(onPressed: _retry)]),
        const EmptyState(
          error: true,
          title: '暫時無法顯示警特報',
          text: '這不代表目前沒有警特報。請稍後重試。',
        ),
      ],
    );
  }

  Widget _page({String? subtitle, bool loading = false, SourceLine? source, required List<Widget> children}) {
    return AppPageScaffold(
      header: AppPageHeader(
        title: '警特報',
        subtitle: subtitle,
        actions: [AppIconButton(icon: Icons.refresh, tooltip: '重新整理', onPressed: loading ? null : _retry)],
      ),
      source: source,
      onRefresh: loading ? null : _refresh,
      children: children,
    );
  }
}
