import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';
import '../../core/location/location_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/choices.dart';
import '../../core/widgets/data_display.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/status.dart';
import '../../data/models/place.dart';
import '../../data/repositories/weather_repository.dart';
import '../weather/weather_provider.dart';
import '../weather/widgets/home_logic.dart';
import '../weather/widgets/weather_glyph_icon.dart';
import 'place_provider.dart';

/// 已儲存地點與目前地點 hero 的現況溫度來源
const _observationDataset = 'O-A0003-001';

/// 定位中 hero 骨架高度（地名＋溫度＋說明列）
const _heroSkeletonHeight = 96.0;

/// 鄉鎮清單載入骨架高度
const _townsSkeletonHeight = 240.0;

/// 定位中清單骨架列數
const _skeletonRows = 3;

/// 地點 tab (team-a/location.html): first-run explainer, current place hero,
/// 我的地點 list (GPS row + saved places), manual county/town picker, and the
/// no-place guidance frames (denied / denied forever / locating / failed).
class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  bool _picking = false;
  bool _focusSearch = false;

  void _openPicker({bool focusSearch = false}) => setState(() {
        _picking = true;
        _focusSearch = focusSearch;
      });

  void _closePicker() => setState(() => _picking = false);

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentPlaceProvider);
    if (_picking) {
      return _PickerView(
        current: switch (current) {
          AsyncData(value: PlaceSelected(:final place)) => place,
          _ => null,
        },
        autofocus: _focusSearch,
        onClose: _closePicker,
      );
    }
    final manual = _openPicker;
    return switch (current) {
      AsyncData(value: PlaceSelected(:final place, :final source, :final fixedAt)) =>
        _SelectedView(place: place, source: source, fixedAt: fixedAt, onManual: manual),
      AsyncData(value: final NoPlace none) when none.firstRun => _ExplainerView(onManual: manual),
      AsyncData(value: final NoPlace none) when none.reason == LocationFailure.permissionDeniedForever =>
        _DeniedForeverView(none: none, onManual: manual),
      AsyncData(value: final NoPlace none) when none.reason == LocationFailure.permissionDenied =>
        _DeniedView(none: none, onManual: manual),
      AsyncData(value: final NoPlace none) => _FailedView(none: none, onManual: manual),
      AsyncError(:final error) => _CorruptView(error: error, onManual: manual),
      _ => const _LocatingView(),
    };
  }
}

// ============================================================================
// Actions shared by the frames
// ============================================================================

Future<void> _useGps(WidgetRef ref) => ref.read(currentPlaceProvider.notifier).useGps();

/// Opens a system settings page; tells the user when the platform refuses.
Future<void> _openSettings(BuildContext context, Future<bool> Function() open) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!await open()) {
    messenger.showSnackBar(const SnackBar(content: Text('無法開啟系統設定，請手動到系統設定開啟本 App 的位置權限')));
  }
}

/// Guidance for the reason, then the underlying cause line as-is.
String _guidance(NoPlace none) => '${locationFailureMessage(none.reason)}\n原因：${none.cause}';

/// 「臺北市 中正區」
String _label(Place p) => '${p.county} ${p.town}';

// ============================================================================
// Frames
// ============================================================================

/// 首次說明：為何需要位置。
class _ExplainerView extends ConsumerWidget {
  const _ExplainerView({required this.onManual});

  final VoidCallback onManual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPageScaffold(
      header: const AppPageHeader(title: '地點', subtitle: '首次使用'),
      children: [
        const _IntroCard(
          icon: Icons.my_location,
          circleColor: AppPalette.brandBg,
          cardColor: AppPalette.brandBgSubtle,
          title: '讓天氣跟著你',
          text: '允許使用位置後，App 會自動顯示你所在鄉鎮的天氣與警特報，不必每次手動選擇。',
        ),
        const AppList(children: [
          AppListRow(
            leading: _Tint(icon: Icons.wb_cloudy_outlined, brand: true),
            primary: '所在地的即時天氣',
            secondary: '溫度、降雨機率、一週預報',
          ),
          AppListRow(
            leading: _Tint(icon: Icons.warning_amber_outlined, brand: true),
            primary: '你所在縣市的警特報',
            secondary: '大雨、豪雨、低溫等即時提醒',
          ),
          AppListRow(
            leading: _Tint(icon: Icons.radar, brand: true),
            primary: '雷達圖以你為中心',
            secondary: '一眼看雨雲是否靠近',
          ),
        ]),
        _ActionsColumn(children: [
          AppButton(
            label: '允許使用位置',
            icon: Icons.my_location,
            variant: AppButtonVariant.primary,
            block: true,
            onPressed: () => _useGps(ref),
          ),
          AppButton(label: '手動選擇地點', block: true, onPressed: onManual),
        ]),
        const _Note(icon: Icons.lock_outline, text: '位置僅在你的裝置上用來查詢天氣，不會上傳或分享。'),
      ],
    );
  }
}

/// 已有目前地點（GPS 或手動）：hero + 搜尋 + 我的地點。
class _SelectedView extends ConsumerWidget {
  const _SelectedView({required this.place, required this.source, required this.fixedAt, required this.onManual});

  final Place place;
  final PlaceSource source;

  /// GPS 定位時刻；手動地點為 null
  final DateTime? fixedAt;
  final void Function({bool focusSearch}) onManual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gps = source == PlaceSource.gps;
    final fix = fixedAt;
    return AppPageScaffold(
      header: AppPageHeader(
        title: '地點',
        subtitle: fix != null ? '定位於 ${clockText(fix)}' : (gps ? 'GPS 定位' : '手動選擇'),
        subtitleIcon: gps ? Icons.my_location : Icons.place_outlined,
        actions: [AppIconButton(icon: Icons.refresh, tooltip: '重新定位', onPressed: () => _useGps(ref))],
      ),
      source: SourceLine(datasetIds: [
        _observationDataset,
        ?AppConstants.townshipForecastDatasets[place.county]?.threeDay,
      ]),
      children: [
        _PlaceHero(place: place, gps: gps),
        _SearchField(readOnly: true, onTap: () => onManual(focusSearch: true)),
        _MyPlaces(
          current: place,
          gpsRow: gps
              ? AppListRow(
                  leading: const _Tint(icon: Icons.my_location),
                  primary: '目前位置',
                  secondary: '${_label(place)} · 自動定位',
                  selected: true,
                  trailing: const AppBadge(label: '使用中', tone: BadgeTone.brand),
                )
              : AppListRow(
                  leading: const _Tint(icon: Icons.my_location),
                  primary: '目前位置',
                  secondary: '自動定位',
                  onTap: () => _useGps(ref),
                ),
          onManual: onManual,
        ),
      ],
    );
  }
}

/// 權限被拒（尚可再詢問）：橫幅 + 停用的目前位置列 + 已儲存地點。不給預設地點。
class _DeniedView extends ConsumerWidget {
  const _DeniedView({required this.none, required this.onManual});

  final NoPlace none;

  final VoidCallback onManual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSaved = ref.watch(savedPlacesProvider).value?.isNotEmpty ?? false;
    return AppPageScaffold(
      header: const AppPageHeader(title: '地點', subtitle: '未取得位置權限'),
      source: hasSaved ? const SourceLine(datasetIds: [_observationDataset]) : null,
      children: [
        StatusBanner(
          tone: StatusTone.permission,
          title: '未取得位置權限',
          text: _guidance(none),
          actions: [
            AppButton(
              label: '前往設定',
              variant: AppButtonVariant.primary,
              small: true,
              onPressed: () => _openSettings(context, Geolocator.openAppSettings),
            ),
            AppButton(label: '手動選擇', small: true, onPressed: onManual),
          ],
        ),
        _MyPlaces(current: null, gpsRow: _disabledGpsRow('未授權'), onManual: null),
      ],
    );
  }
}

/// 永久拒絕：到系統設定開啟的步驟。
class _DeniedForeverView extends ConsumerWidget {
  const _DeniedForeverView({required this.none, required this.onManual});

  final NoPlace none;

  final VoidCallback onManual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSaved = ref.watch(savedPlacesProvider).value?.isNotEmpty ?? false;
    return AppPageScaffold(
      header: const AppPageHeader(title: '地點', subtitle: '位置權限已關閉'),
      source: hasSaved ? const SourceLine(datasetIds: [_observationDataset]) : null,
      children: [
        const _IntroCard(
          icon: Icons.location_disabled_outlined,
          circleColor: AppPalette.warningSolid,
          cardColor: AppPalette.warningBg,
          title: '位置權限已關閉',
          text: '系統不再詢問位置權限。要使用自動定位，請在系統設定中手動開啟。',
        ),
        const AppCard(
          title: '開啟步驟',
          child: Column(
            spacing: AppSpace.s12,
            children: [
              _Step(no: 1, text: '點下「前往設定」，開啟本 App 的設定頁'),
              _Step(no: 2, text: '選擇「位置」'),
              _Step(no: 3, text: '改為「使用 App 時允許」，再返回本 App'),
            ],
          ),
        ),
        _ActionsColumn(children: [
          AppButton(
            label: '前往設定',
            variant: AppButtonVariant.primary,
            block: true,
            onPressed: () => _openSettings(context, Geolocator.openAppSettings),
          ),
          AppButton(label: '手動選擇地點', block: true, onPressed: onManual),
        ]),
        _Note(icon: Icons.info_outline, text: '原因：${none.cause}'),
        if (hasSaved) _MyPlaces(current: null, gpsRow: _disabledGpsRow('未授權'), onManual: null),
      ],
    );
  }
}

/// 定位失敗（定位服務關閉／無法取得位置／無法解析所在地）。
class _FailedView extends ConsumerWidget {
  const _FailedView({required this.none, required this.onManual});

  final NoPlace none;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSaved = ref.watch(savedPlacesProvider).value?.isNotEmpty ?? false;
    final serviceOff = none.reason == LocationFailure.serviceDisabled;
    return AppPageScaffold(
      header: AppPageHeader(
        title: '地點',
        subtitle: '定位失敗',
        actions: [AppIconButton(icon: Icons.refresh, tooltip: '重新定位', onPressed: () => _useGps(ref))],
      ),
      source: hasSaved ? const SourceLine(datasetIds: [_observationDataset]) : null,
      children: [
        StatusBanner(
          tone: StatusTone.error,
          title: '無法取得目前位置',
          text: _guidance(none),
          actions: [
            if (serviceOff)
              AppButton(
                label: '前往設定',
                variant: AppButtonVariant.primary,
                small: true,
                onPressed: () => _openSettings(context, Geolocator.openLocationSettings),
              ),
            RetryButton(primary: !serviceOff, onPressed: () => _useGps(ref)),
            AppButton(label: '手動選擇', small: true, onPressed: onManual),
          ],
        ),
        if (hasSaved)
          _MyPlaces(current: null, gpsRow: _disabledGpsRow(serviceOff ? '定位服務關閉' : '無法定位'), onManual: null)
        else
          EmptyState(
            title: '尚未設定地點',
            text: '選擇一個縣市與鄉鎮後，即可查看當地天氣與警特報。',
            icon: Icons.location_off_outlined,
            actions: [AppButton(label: '手動選擇地點', variant: AppButtonVariant.primary, onPressed: onManual)],
          ),
      ],
    );
  }
}

/// 本機地點資料損毀：重新選擇會覆寫。
class _CorruptView extends StatelessWidget {
  const _CorruptView({required this.error, required this.onManual});

  final Object error;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      header: const AppPageHeader(title: '地點', subtitle: '地點資料損毀'),
      children: [
        StatusBanner(
          tone: StatusTone.error,
          title: '無法讀取已儲存的地點',
          text: '$error',
          actions: [AppButton(label: '手動選擇', variant: AppButtonVariant.primary, small: true, onPressed: onManual)],
        ),
      ],
    );
  }
}

/// 載入中：定位中。
class _LocatingView extends StatelessWidget {
  const _LocatingView();

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      header: const AppPageHeader(
        title: '地點',
        subtitle: '定位中…',
        actions: [AppIconButton(icon: Icons.refresh, tooltip: '重新定位', onPressed: null)],
      ),
      children: [
        const StatusBanner(tone: StatusTone.loading, title: '正在取得你的位置…', text: '通常需要數秒'),
        const AppCard.loading(hero: true, skeletonHeight: _heroSkeletonHeight),
        AppList(children: [
          for (var i = 0; i < _skeletonRows; i++)
            const AppListRow(
              leading: Skeleton(height: AppSize.icon32, circle: true),
              primary: '',
              trailing: Skeleton(height: AppSpace.s12, width: AppSpace.s48),
            ),
        ]),
      ],
    );
  }
}

// ============================================================================
// Manual picker: 縣市 chips + 鄉鎮 list + 搜尋 + 儲存 / 設為目前地點
// ============================================================================

class _PickerView extends ConsumerStatefulWidget {
  const _PickerView({required this.current, required this.autofocus, required this.onClose});

  final Place? current;
  final bool autofocus;
  final VoidCallback onClose;

  @override
  ConsumerState<_PickerView> createState() => _PickerViewState();
}

class _PickerViewState extends ConsumerState<_PickerView> {
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
    return AppPageScaffold(
      header: AppPageHeader(title: '選擇地點', subtitle: '${_counties.length} 個縣市', onBack: widget.onClose),
      children: [
        _SearchField(autofocus: widget.autofocus, onChanged: (q) => setState(() => _query = q.trim())),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.s8,
          children: [
            const SectionHeader(title: '縣市', trailing: _Meta('左右滑動')),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: AppSpace.s8,
                // ponytail: a query that matches no county (e.g. a town name) keeps every chip so the user can still pick one.
                children: [
                  for (final c in counties.isEmpty ? _counties : counties)
                    AppChip(
                      label: c,
                      selected: c == _county,
                      onTap: () => setState(() {
                        _county = c;
                        _town = null;
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
        _TownList(
          county: _county,
          query: _query,
          selected: town,
          onSelect: (p) => setState(() => _town = p),
        ),
        Row(
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
      AsyncData(value: Failure(:final message)) => AppCard.error(
          title: '無法取得$county鄉鎮清單',
          message: message,
          onRetry: () => ref.invalidate(townsProvider(county)),
        ),
      AsyncError(:final error) => AppCard.error(
          title: '無法取得$county鄉鎮清單',
          message: '$error',
          onRetry: () => ref.invalidate(townsProvider(county)),
        ),
      _ => AppCard.loading(title: title, skeletonHeight: _townsSkeletonHeight),
    };
  }

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
          AppList(children: [
            for (final t in shown)
              AppListRow(
                primary: t.town,
                selected: _sameTown(t, selected),
                trailing: _sameTown(t, selected)
                    ? const Icon(Icons.check, size: AppSize.icon20, color: AppPalette.brandFg)
                    : null,
                onTap: () => onSelect(t),
              ),
          ]),
      ],
    );
  }
}

/// GPS places carry device coordinates, the town list carries town-centre coordinates: match by name.
bool _sameTown(Place a, Place? b) => b != null && a.county == b.county && a.town == b.town;

// ============================================================================
// 我的地點
// ============================================================================

AppListRow _disabledGpsRow(String why) => AppListRow(
      leading: const _Tint(icon: Icons.my_location),
      primary: '目前位置',
      secondary: '定位不可用 · $why',
      enabled: false,
      trailing: const AppBadge(label: '已停用'),
    );

/// `我的地點` section: GPS row first, then saved places (select, remove, current temperature).
class _MyPlaces extends ConsumerWidget {
  const _MyPlaces({required this.current, required this.gpsRow, required this.onManual});

  /// Current place (highlighted as 使用中 when it is a saved place); null = no place.
  final Place? current;
  final AppListRow gpsRow;

  /// Shows the 「手動選擇」 header button when set.
  final void Function({bool focusSearch})? onManual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manual = onManual;
    final header = SectionHeader(
      title: '我的地點',
      trailing: manual == null
          ? null
          : AppButton(
              label: '手動選擇',
              icon: Icons.chevron_right,
              variant: AppButtonVariant.subtle,
              small: true,
              onPressed: manual,
            ),
    );
    final Widget body = switch (ref.watch(savedPlacesProvider)) {
      AsyncData(value: final saved) => AppList(children: [
          gpsRow,
          for (final p in saved) _savedRow(ref, p),
        ]),
      AsyncError(:final error) => StatusBanner(tone: StatusTone.error, title: '無法讀取已儲存的地點', text: '$error'),
      _ => AppCard.loading(skeletonHeight: AppSize.touch),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: AppSpace.s8, children: [header, body]);
  }

  AppListRow _savedRow(WidgetRef ref, Place p) {
    final inUse = _sameTown(p, current);
    final (String? secondary, String temp) = switch (ref.watch(placeObservationProvider(p))) {
      AsyncData(value: Success(:final data)) => (data.weather, '${data.temperature.round()}°'),
      AsyncData(value: Failure(:final message)) => (message, '—'),
      AsyncError(:final error) => ('$error', '—'),
      _ => (null, '—'),
    };
    return AppListRow(
      leading: const _Tint(icon: Icons.place_outlined),
      primary: _label(p),
      secondary: secondary,
      selected: inUse,
      onTap: () => ref.read(currentPlaceProvider.notifier).select(p),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpace.s4,
        children: [
          if (inUse) const AppBadge(label: '使用中', tone: BadgeTone.brand),
          Text(temp),
          AppIconButton(
            icon: Icons.delete_outline,
            tooltip: '移除${_label(p)}',
            onPressed: () => ref.read(savedPlacesProvider.notifier).remove(p),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Page-local parts (.loc-hero, .intro, .field, .step, .privacy)
// ============================================================================

/// `.loc-hero`: source label, place name, current temperature with weather icon,
/// and 「天氣 · 降雨 20% · 更新於 14:10」. Shares the home page's data for the current place
/// ([weatherNotifierProvider]); 降雨 is the township forecast slot covering now.
class _PlaceHero extends ConsumerWidget {
  const _PlaceHero({required this.place, required this.gps});

  final Place place;
  final bool gps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(weatherNotifierProvider);
    final now = ref.read(weatherClockProvider)();
    void retry() => ref.invalidate(weatherNotifierProvider);
    final current = weather.location == place && !weather.isLoading ? weather.current : null;
    final pop = switch (weather.hourly) {
      Success(:final data) => currentSlot(data, now)?.pop,
      _ => null,
    };
    final (Widget temp, Widget foot) = switch (current) {
      Success(:final data) => (
          Row(
            spacing: AppSpace.s8,
            children: [
              WeatherGlyphIcon(text: data.weather, size: AppSize.icon48),
              Text(
                tempText(data.temperature),
                style: AppType.largeTitle.copyWith(color: AppPalette.fg1, fontFeatures: AppType.tabular),
              ),
            ],
          ),
          Text(
            [?data.weather, '降雨 ${percentText(pop)}', '更新於 ${clockText(data.observedAt)}'].join(' · '),
            style: AppType.caption1.copyWith(color: AppPalette.fg2, fontFeatures: AppType.tabular),
          ),
        ),
      Failure(:final message) => (const SizedBox.shrink(), _HeroError(message: message, onRetry: retry)),
      null => (
          const Skeleton(height: AppSpace.s40, width: AppSpace.s64),
          const Skeleton(height: AppSpace.s12),
        ),
    };
    return AppCard(
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s12,
        children: [
          Row(
            spacing: AppSpace.s12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpace.s4,
                  children: [
                    Row(
                      spacing: AppSpace.s4,
                      children: [
                        Icon(gps ? Icons.my_location : Icons.place_outlined,
                            size: AppSize.icon16, color: AppPalette.brandFgStrong),
                        Text(
                          gps ? 'GPS 定位' : '手動選擇',
                          style: AppType.caption1
                              .copyWith(color: AppPalette.brandFgStrong, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      _label(place),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.title3.copyWith(color: AppPalette.fg1),
                    ),
                  ],
                ),
              ),
              temp,
            ],
          ),
          foot,
        ],
      ),
    );
  }
}

class _HeroError extends StatelessWidget {
  const _HeroError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.s8,
      children: [
        Text('無法取得現況：$message', style: AppType.caption1.copyWith(color: AppPalette.dangerFg)),
        RetryButton(onPressed: onRetry),
      ],
    );
  }
}

/// `.intro`: centred circle icon + title + text on a tinted hero card.
class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.icon,
    required this.circleColor,
    required this.cardColor,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color circleColor;
  final Color cardColor;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      hero: true,
      heroColor: cardColor,
      child: Column(
        spacing: AppSpace.s12,
        children: [
          Container(
            width: AppSize.icon64,
            height: AppSize.icon64,
            decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle, boxShadow: AppShadows.s8),
            child: Icon(icon, size: AppSize.icon32, color: AppPalette.fgOnBrand),
          ),
          Text(title, textAlign: TextAlign.center, style: AppType.title3.copyWith(color: AppPalette.fg1)),
          Text(text, textAlign: TextAlign.center, style: AppType.body1.copyWith(color: AppPalette.fg2)),
        ],
      ),
    );
  }
}

/// `.list-row__leading--tint` (32 circle); [brand] = `--brand`.
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

/// `.field[role=search]`. [readOnly] makes it a button that opens the picker.
class _SearchField extends StatelessWidget {
  const _SearchField({this.readOnly = false, this.autofocus = false, this.onTap, this.onChanged});

  final bool readOnly;
  final bool autofocus;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  static OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return TextField(
      readOnly: readOnly,
      autofocus: autofocus,
      onTap: onTap,
      onChanged: onChanged,
      style: AppType.body1.copyWith(color: AppPalette.fg1),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppPalette.bg1,
        hintText: '搜尋縣市或鄉鎮市區',
        hintStyle: AppType.body1.copyWith(color: AppPalette.fg3),
        prefixIcon: const Icon(Icons.search, size: AppSize.icon20, color: AppPalette.fg3),
        constraints: const BoxConstraints(minHeight: AppSize.control),
        enabledBorder: _border(AppPalette.stroke1, AppStroke.thin),
        focusedBorder: _border(AppPalette.brandStroke, AppStroke.thick),
      ),
    );
  }
}

/// `.step`: numbered circle + text.
class _Step extends StatelessWidget {
  const _Step({required this.no, required this.text});

  final int no;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpace.s12,
      children: [
        Container(
          width: AppSize.icon24,
          height: AppSize.icon24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppPalette.brandBgSubtle, shape: BoxShape.circle),
          child: Text(
            '$no',
            style: AppType.caption1.copyWith(color: AppPalette.brandFgStrong, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(text, style: AppType.body1.copyWith(color: AppPalette.fg1))),
      ],
    );
  }
}

/// `.actions-col`
class _ActionsColumn extends StatelessWidget {
  const _ActionsColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: AppSpace.s8, children: children);
  }
}

/// `.privacy`: small icon + caption.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.s8,
      children: [
        Icon(icon, size: AppSize.icon16, color: AppPalette.fg3),
        Flexible(child: Text(text, style: AppType.caption1.copyWith(color: AppPalette.fg3))),
      ],
    );
  }
}

/// `.card__meta` beside a section title.
class _Meta extends StatelessWidget {
  const _Meta(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: AppType.caption1.copyWith(color: AppPalette.fg3));
}
