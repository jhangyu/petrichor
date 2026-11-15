import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_shell.dart' show AppTab, appTabProvider;
import '../../../core/layout/adaptive.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/api_key_notice.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/choices.dart';
import '../../../core/widgets/status.dart';
import '../../../core/api/result.dart' show Failure, Success;
import '../../radar/radar_playback.dart' show formatTaiwanClock;
import '../../weather/weather_provider.dart' show weatherClockProvider;
import '../hazard_provider.dart';
import 'warning_card.dart';
import 'warning_groups.dart';

/// 警特報 section at the bottom of 天氣: 我的縣市 / 全部 switch and the warning list (the only 警特報 view).
class WarningsSection extends ConsumerStatefulWidget {
  const WarningsSection({super.key, required this.county});

  /// Current place's county, CWA 「臺」 spelling.
  final String county;

  @override
  ConsumerState<WarningsSection> createState() => _WarningsSectionState();
}

class _WarningsSectionState extends ConsumerState<WarningsSection> {
  bool _mineOnly = true;

  void _retry() => ref.invalidate(activeWarningsProvider);

  @override
  Widget build(BuildContext context) {
    return switch (ref.watch(activeWarningsProvider)) {
      AsyncLoading() => _frame(
        body: const [AppCard.loading(skeletonHeight: AppSize.touch), AppCard.loading(skeletonHeight: AppSize.touch)],
      ),
      AsyncError(:final error) => _error('$error'),
      AsyncData(value: Failure(apiKeyIssue: final issue?)) => _frame(body: [ApiKeyNotice(issue: issue)]),
      AsyncData(value: Failure(:final message)) => _error(message),
      AsyncData(value: Success(:final data)) => _data(groupWarnings(data), data.updatedAt ?? data.fetchedAt),
    };
  }

  Widget _data(List<WarningGroup> all, DateTime updated) {
    final county = widget.county;
    final mine = groupsForCounty(all, county);
    final shown = _mineOnly ? mine : all;
    return _frame(
      updated: updated,
      chips: Wrap(
        spacing: AppSpace.s8,
        runSpacing: AppSpace.s8,
        children: [
          AppChip(
            label: '我的縣市 $county',
            icon: Icons.location_on_outlined,
            selected: _mineOnly,
            onTap: () => setState(() => _mineOnly = true),
          ),
          AppChip(label: '全部 ${all.length}', selected: !_mineOnly, onTap: () => setState(() => _mineOnly = false)),
        ],
      ),
      body: shown.isEmpty ? [_empty(county, all.length)] : _cards(shown),
    );
  }

  Widget _frame({DateTime? updated, Widget? chips, required List<Widget> body}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s12,
      children: [
        SectionHeader(
          title: '警特報',
          trailing: updated == null
              ? null
              : Text(
                  '更新於 ${formatTaiwanClock(updated)}',
                  style: AppType.caption1.copyWith(color: AppPalette.fg3, fontFeatures: AppType.tabular),
                ),
        ),
        ?chips,
        ...body,
      ],
    );
  }

  Widget _empty(String county, int totalGroups) {
    if (_mineOnly) {
      return StatusBanner(
        tone: StatusTone.empty,
        title: '$county目前無警特報',
        text: totalGroups == 0 ? null : '其他縣市有 $totalGroups 項生效中警特報，切換到「全部」查看。',
      );
    }
    return const StatusBanner(tone: StatusTone.empty, title: '全臺目前無警特報');
  }

  Widget _error(String message) {
    return _frame(
      body: [
        StatusBanner(
          tone: StatusTone.error,
          title: '無法取得警特報',
          text: '$message 這不代表目前沒有警特報。',
          actions: [RetryButton(onPressed: _retry)],
        ),
      ],
    );
  }

  List<Widget> _cards(List<WarningGroup> shown) {
    final now = ref.watch(weatherClockProvider)();
    return [
      LayoutBuilder(
        builder: (context, box) {
          final columns = AppGrid.columnsFor(box.maxWidth, spanUnits: shown.length);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppLayout.gridGap,
            children: [
              for (var c = 0; c < columns; c++)
                Expanded(
                  child: Column(
                    spacing: AppSpace.s12,
                    children: [
                      // Item i goes to column i % columns so the highest levels share the top row.
                      for (var i = c; i < shown.length; i += columns)
                        WarningCard(
                          // Key by content so an open card stays attached to its warning when the list changes.
                          key: ValueKey((shown[i].name, shown[i].start, shown[i].end)),
                          group: shown[i],
                          now: now,
                          onViewRainfall: () => ref.read(appTabProvider.notifier).select(AppTab.rainfall),
                          initiallyOpen: i == 0,
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ];
  }
}
