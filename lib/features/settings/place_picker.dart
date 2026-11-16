import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/layout/adaptive.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/choices.dart';
import '../../core/widgets/data_display.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../data/models/place.dart';
import '../../core/api/result.dart';
import '../location/place_provider.dart';

/// 鄉鎮清單載入骨架高度
const _townsSkeletonHeight = 240.0;

/// Manual picker: 縣市 chips + 鄉鎮 list + 搜尋 + 儲存 / 設為目前地點.
class PlacePicker extends ConsumerStatefulWidget {
  const PlacePicker({super.key, required this.current, required this.autofocus, required this.onClose});

  final Place? current;
  final bool autofocus;
  final VoidCallback onClose;

  @override
  ConsumerState<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends ConsumerState<PlacePicker> {
  static final _counties = AppConstants.townshipForecastDatasets.keys.toList();

  late String _county = widget.current?.county ?? _counties.first;
  late Place? _town = widget.current;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final counties = [for (final c in _counties) if (c.contains(_query)) c];
    final town = _town;
    final saved = ref.watch(savedPlacesProvider).value ?? const [];
    final alreadySaved = town != null && saved.contains(town);
    // ponytail: a query that matches no county (e.g. a town name) keeps every chip so the user can still pick one.
    final shownCounties = counties.isEmpty ? _counties : counties;
    final scrollChips = WindowSizeClass.of(context).isCompactWidth;
    final chips = [
      for (final c in shownCounties)
        AppChip(
          label: c,
          selected: c == _county,
          onTap: () => setState(() {
            _county = c;
            _town = null;
          }),
        ),
    ];
    final countySection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s8,
      children: [
        SectionHeader(title: '縣市', trailing: scrollChips ? const _Meta('左右滑動') : null),
        if (scrollChips)
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(spacing: AppSpace.s8, children: chips))
        else
          Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8, children: chips),
      ],
    );
    final townSection = _TownList(
      county: _county,
      query: _query,
      selected: town,
      onSelect: (p) => setState(() => _town = p),
    );
    final buttons = Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.readingWidth),
        child: Row(
          spacing: AppSpace.s8,
          children: [
            Expanded(
              child: AppButton(
                label: alreadySaved ? '已儲存' : '儲存',
                icon: Icons.bookmark_border,
                block: true,
                onPressed: town == null || alreadySaved
                    ? null
                    : () => ref.read(savedPlacesProvider.notifier).save(town),
              ),
            ),
            Expanded(
              child: AppButton(
                label: '設為目前地點',
                variant: AppButtonVariant.primary,
                block: true,
                onPressed: town == null
                    ? null
                    : () async {
                        await ref.read(currentPlaceProvider.notifier).select(town);
                        widget.onClose();
                      },
              ),
            ),
          ],
        ),
      ),
    );
    return AppPageScaffold(
      header: AppPageHeader(title: '選擇地點', subtitle: '${_counties.length} 個縣市', onBack: widget.onClose),
      children: [
        AppGridItem.full(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.readingWidth),
              child: AppTextField(
                variant: AppTextFieldVariant.search,
                hint: '搜尋縣市或鄉鎮市區',
                prefixIcon: Icons.search,
                autofocus: widget.autofocus,
                onChanged: (q) => setState(() => _query = q.trim()),
              ),
            ),
          ),
        ),
        AppGridItem.full(
          child: LayoutBuilder(
            builder: (context, constraints) => AppTwoPane.fits(constraints.maxWidth)
                ? AppTwoPane(
                    sideFirst: true,
                    side: countySection,
                    main: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: AppSpace.s16,
                      children: [townSection, buttons],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpace.s16,
                    children: [countySection, townSection, buttons],
                  ),
          ),
        ),
      ],
    );
  }
}

class _TownList extends ConsumerWidget {
  const _TownList({required this.county, required this.query, required this.selected, required this.onSelect});

  final String county;
  final String query;
  final Place? selected;
  final ValueChanged<Place> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = '$county · 鄉鎮市區';
    return switch (ref.watch(townsProvider(county))) {
      AsyncData(value: Success(data: final towns)) => _towns(title, towns),
      AsyncData(value: Failure(:final message)) => _error(ref, message),
      AsyncError(:final error) => _error(ref, '$error'),
      _ => AppCard.loading(title: title, skeletonHeight: _townsSkeletonHeight),
    };
  }

  Widget _error(WidgetRef ref, String message) => AppCard.error(
        title: '無法取得$county鄉鎮清單',
        message: message,
        onRetry: () => ref.invalidate(townsProvider(county)),
      );

  Widget _towns(String title, List<Place> towns) {
    final shown = [for (final t in towns) if (t.name.contains(query)) t];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s8,
      children: [
        SectionHeader(title: title, trailing: _Meta('${towns.length} 區')),
        if (shown.isEmpty)
          AppCard.empty(title: '找不到「$query」', message: '搜尋只比對$county的鄉鎮市區；請先選擇縣市')
        else
          LayoutBuilder(builder: (context, constraints) {
            final rows = [
              for (final t in shown)
                AppListRow(
                  primary: t.town,
                  selected: _sameTown(t, selected),
                  trailing: _sameTown(t, selected)
                      ? const Icon(Icons.check, size: AppSize.icon20, color: AppPalette.brandForeground)
                      : null,
                  onTap: () => onSelect(t),
                ),
            ];
            if (!AppTwoPane.fits(constraints.maxWidth)) return AppList(children: rows);
            return AppGrid(minColumnWidth: AppLayout.paneMinimumWidth, children: [for (final r in rows) AppList(children: [r])]);
          }),
      ],
    );
  }
}

/// GPS places carry device coordinates, the town list carries town-centre coordinates: match by name.
bool _sameTown(Place a, Place? b) => b != null && a.county == b.county && a.town == b.town;

/// `.card__meta` beside a section title.
class _Meta extends StatelessWidget {
  const _Meta(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: AppType.caption1.copyWith(color: AppPalette.foreground3));
}
