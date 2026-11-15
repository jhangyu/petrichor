import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../app_shell.dart';
import '../../core/constants/app_constants.dart';
import '../../core/layout/adaptive.dart';
import '../../core/location/location_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/api_key_notice.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/status.dart';
import '../../data/models/hazard_models.dart';
import '../../data/models/place.dart';
import '../../data/models/weather_models.dart';
import '../../data/repositories/hazard_repository.dart';
import '../../data/repositories/weather_repository.dart';
import '../hazard/hazard_provider.dart';
import '../hazard/warnings/warning_groups.dart';
import '../location/place_provider.dart';
import 'weather_provider.dart';
import 'widgets/forecast_72h_card.dart';
import 'widgets/hero_card.dart';
import 'widgets/home_logic.dart';
import 'widgets/sun_card.dart';
import 'widgets/weekly_card.dart';

/// 天氣 tab (`team-a/home.html`): current observation hero, active-warning entry,
/// 日出日落, 未來 72 小時預報 and 7 日預報 for the current place. Each card shows
/// its own loading / error / data state from [WeatherState]'s per-dataset Result.
class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(currentPlaceProvider);
    final weather = ref.watch(weatherNotifierProvider);
    void openLocationTab() => ref.read(appTabProvider.notifier).select(AppTab.location);
    void refresh() {
      ref.invalidate(weatherNotifierProvider);
      ref.invalidate(activeWarningsProvider);
    }

    final selected = switch (place) {
      AsyncData(value: PlaceSelected(:final place, :final source)) => (place, source),
      _ => null,
    };
    final header = AppPageHeader(
      title: selected?.$1.name ?? (place.isLoading ? '定位中…' : '尚未選擇地點'),
      subtitle: _subtitle(place, weather),
      subtitleIcon: selected?.$2 == PlaceSource.gps ? Icons.near_me_outlined : Icons.location_on_outlined,
      subtitleIconColor: selected == null ? AppPalette.warningFg : AppPalette.brandFg,
      onTitleTap: openLocationTab,
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          tooltip: '重新整理',
          onPressed: selected == null || weather.isLoading ? null : refresh,
        ),
        AppIconButton(icon: Icons.location_on_outlined, tooltip: '切換地點', onPressed: openLocationTab),
      ],
    );

    return switch (place) {
      AsyncData(value: NoPlace() && final noPlace) => AppPageScaffold(
        header: header,
        children: [_NoPlaceGuide(noPlace: noPlace, onManual: openLocationTab)],
      ),
      AsyncError(:final error) => AppPageScaffold(
        header: header,
        children: [
          EmptyState(
            title: '無法讀取已選地點',
            text: '$error',
            error: true,
            actions: [AppButton(label: '重新選擇地點', variant: AppButtonVariant.primary, onPressed: openLocationTab)],
          ),
        ],
      ),
      _ when selected == null => AppPageScaffold(
        header: header,
        children: const [AppGridItem.full(child: _PullHint(loading: true))],
      ),
      _ => _content(context, ref, header, selected.$1, weather, refresh),
    };
  }

  /// 「目前位置 · 更新於 14:10」: when the app last finished loading the home data
  /// ([WeatherState.fetchedAt]); the observation time stays on the hero's 即時觀測 line.
  String _subtitle(AsyncValue<CurrentPlace> place, WeatherState weather) {
    final source = switch (place) {
      AsyncData(value: PlaceSelected(source: PlaceSource.gps)) => '目前位置',
      AsyncData(value: PlaceSelected(source: PlaceSource.manual)) => '已選地點',
      AsyncData(value: NoPlace()) || AsyncError() => '請選擇地點',
      _ => '定位中…',
    };
    if (!(place is AsyncData && place.value is PlaceSelected)) return source;
    if (weather.isLoading) return '$source · 更新中…';
    return switch (weather.fetchedAt) {
      final at? => '$source · 更新於 ${clockText(at)}',
      null => source,
    };
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AppPageHeader header,
    Place place,
    WeatherState weather,
    VoidCallback refresh,
  ) {
    final now = ref.read(weatherClockProvider)();
    final hourly = weather.hourly;
    final current = weather.current;
    final warnings = ref.watch(activeWarningsProvider);
    final datasets = AppConstants.townshipForecastDatasets[place.county];
    final groups = switch (warnings) {
      AsyncData(value: Success(:final data)) => groupsForCounty(groupWarnings(data), place.county),
      _ => const <WarningGroup>[],
    };
    // Credit only datasets whose data is on screen; none while loading.
    final sources = weather.isLoading
        ? const <String>[]
        : [
            if (current is Success) AppConstants.observationDataset,
            if (hourly is Success && datasets != null) datasets.threeDay,
            if (weather.weekly is Success && datasets != null) datasets.oneWeek,
            if (weather.sun is Success) AppConstants.sunTimesDataset,
            if (groups.isNotEmpty) ...[warningsByCountyDataset, warningBulletinsDataset],
          ];
    return AppPageScaffold(
      header: header,
      onRefresh: () async => refresh(),
      source: sources.isEmpty ? null : SourceLine(datasetIds: sources),
      children: [
        if (weather.isLoading || WindowSizeClass.of(context).width == WindowWidthClass.compact)
          AppGridItem.full(child: _PullHint(loading: weather.isLoading)),
        ?_warningEntry(ref, warnings, groups, now),
        AppGridItem.full(
          child: _CardFlow(
            hero: HeroCard(
              current: current,
              slot: hourly is Success<List<HourlyForecast>> ? currentSlot(hourly.data, now) : null,
              onRetry: refresh,
            ),
            sun: SunCard(days: weather.sun, now: now, onRetry: refresh),
            forecast: Forecast72hCard(hourly: hourly, issuedAt: weather.hourlyIssuedAt, now: now, onRetry: refresh),
            weekly: WeeklyCard(
              weekly: weather.weekly,
              currentTemperature: current is Success<CurrentWeather> ? current.data.temperature : null,
              now: now,
              onRetry: refresh,
            ),
          ),
        ),
      ],
    );
  }

  /// `.warn-entry`: highest active warning for the county → 警特報 tab.
  /// Loading and 「無特報」 show nothing; a failed fetch shows its error.
  Widget? _warningEntry(
    WidgetRef ref,
    AsyncValue<Result<ActiveWarnings>> warnings,
    List<WarningGroup> groups,
    DateTime now,
  ) {
    final entry = switch (warnings) {
      AsyncData(value: Failure(apiKeyIssue: final issue?)) => ApiKeyNotice(issue: issue),
      AsyncData(value: Failure(:final message)) => _warningError(ref, message),
      AsyncError(:final error) => _warningError(ref, '$error'),
      AsyncData(value: Success()) => _activeEntry(ref, groups, now),
      _ => null,
    };
    return entry == null ? null : AppGridItem.full(child: entry);
  }

  Widget _warningError(WidgetRef ref, String message) => StatusBanner(
    tone: StatusTone.error,
    title: '無法取得警特報',
    text: message,
    actions: [RetryButton(onPressed: () => ref.invalidate(activeWarningsProvider))],
  );

  Widget? _activeEntry(WidgetRef ref, List<WarningGroup> groups, DateTime now) {
    if (groups.isEmpty) return null;
    final top = groups.first;
    final more = groups.length > 1 ? ' · 另有 ${groups.length - 1} 則' : '';
    return Semantics(
      button: true,
      label: '${top.name}，查看詳情',
      child: InkWell(
        onTap: () => ref.read(appTabProvider.notifier).select(AppTab.warnings),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: StatusBanner(
          tone: top.level == null || top.level == 1 ? StatusTone.alert1 : StatusTone.alert3,
          title: '${top.name} · ${top.isUpcoming(now) ? '即將生效' : '生效中'}',
          text: '${_range(top.start, top.end)}$more',
        ),
      ),
    );
  }

  String _range(DateTime start, DateTime end) =>
      '${monthDay(taiwanWall(start))} ${clockText(start)} – ${monthDay(taiwanWall(end))} ${clockText(end)}';
}

/// The four data cards. Cards sit in a row only while each keeps at least a
/// grid column of width: hero beside sun, then 72 小時 beside 7 日; otherwise
/// they stack in reading order.
class _CardFlow extends StatelessWidget {
  const _CardFlow({required this.hero, required this.sun, required this.forecast, required this.weekly});

  final Widget hero;
  final Widget sun;
  final Widget forecast;
  final Widget weekly;

  /// Share of the lower row taken by the 72 小時 card (3 of 5 parts).
  static const _forecastFlex = 3;
  static const _weeklyFlex = 2;
  static const _cardCount = 4;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final columns = AppGrid.columnsFor(box.maxWidth, spanUnits: _cardCount);
        Widget pair(Widget a, Widget b, {int aFlex = 1, int bFlex = 1}) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppLayout.gridGap,
          children: [
            Expanded(flex: aFlex, child: a),
            Expanded(flex: bFlex, child: b),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppLayout.gridGap,
          children: switch (columns) {
            1 => [hero, sun, forecast, weekly],
            2 => [_EqualHeightPair(gap: AppLayout.gridGap, children: [hero, sun]), forecast, weekly],
            _ => [
              _EqualHeightPair(gap: AppLayout.gridGap, children: [hero, sun]),
              pair(forecast, weekly, aFlex: _forecastFlex, bFlex: _weeklyFlex),
            ],
          },
        );
      },
    );
  }
}

/// Two equal-width cards side by side, both as tall as the taller one. A custom
/// layout because IntrinsicHeight cannot measure SunCard's LayoutBuilder.
class _EqualHeightPair extends MultiChildRenderObjectWidget {
  const _EqualHeightPair({required this.gap, required super.children});

  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEqualHeightPair(gap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderEqualHeightPair renderObject,
  ) => renderObject.gap = gap;
}

class _PairParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderEqualHeightPair extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PairParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PairParentData> {
  _RenderEqualHeightPair(this._gap);

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PairParentData) child.parentData = _PairParentData();
  }

  @override
  void performLayout() {
    final first = firstChild!;
    final second = childAfter(first)!;
    final width = (constraints.maxWidth - _gap) / 2;
    final loose = BoxConstraints(minWidth: width, maxWidth: width);
    first.layout(loose, parentUsesSize: true);
    second.layout(loose, parentUsesSize: true);
    final height = first.size.height > second.size.height
        ? first.size.height
        : second.size.height;
    final tight = BoxConstraints.tightFor(width: width, height: height);
    for (final child in [first, second]) {
      if (child.size.height != height) {
        child.layout(tight, parentUsesSize: true);
      }
    }
    (first.parentData! as _PairParentData).offset = Offset.zero;
    (second.parentData! as _PairParentData).offset = Offset(width + _gap, 0);
    size = constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// `.ptr`: pull-to-refresh hint; while loading, the spinner pill 「載入天氣資料…」.
class _PullHint extends StatelessWidget {
  const _PullHint({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final style = AppType.caption1.copyWith(color: loading ? AppPalette.brandFgStrong : AppPalette.fg3);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSize.controlSm),
      child: Center(
        child: loading
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4),
                decoration: BoxDecoration(
                  color: AppPalette.bg1,
                  borderRadius: BorderRadius.circular(AppRadius.circular),
                  boxShadow: AppShadows.s4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpace.s8,
                  children: [
                    const AppSpinner(),
                    Text('載入天氣資料…', style: style),
                  ],
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpace.s8,
                children: [
                  const Icon(Icons.expand_more, size: AppSize.icon16, color: AppPalette.fg3),
                  Text('下拉即可重新整理', style: style),
                ],
              ),
      ),
    );
  }
}

/// No current place: why, and the next steps (permission / settings, 手動選擇).
/// No data and no default place are shown.
class _NoPlaceGuide extends ConsumerWidget {
  const _NoPlaceGuide({required this.noPlace, required this.onManual});

  final NoPlace noPlace;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reason = noPlace.reason;
    final title = switch (reason) {
      LocationFailure.permissionDenied || LocationFailure.permissionDeniedForever => '未取得位置權限',
      LocationFailure.serviceDisabled => '定位服務已關閉',
      LocationFailure.positionUnavailable || LocationFailure.addressUnresolved => '無法取得目前位置',
    };
    final text = locationFailureMessage(reason);

    Future<void> openSettings(Future<bool> Function() open, String what) async {
      if (await open()) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('無法開啟$what，請手動前往系統設定')));
    }

    void useGps() => ref.read(currentPlaceProvider.notifier).useGps();
    // Settings actions lead (mockup 「前往設定」 primary); otherwise 手動選擇 leads.
    final (locateLabel, VoidCallback locate, settingsFirst) = switch (reason) {
      LocationFailure.permissionDenied => ('使用目前位置', useGps, false),
      LocationFailure.permissionDeniedForever => (
        '前往設定',
        () => openSettings(Geolocator.openAppSettings, '應用程式設定'),
        true,
      ),
      LocationFailure.serviceDisabled => ('開啟定位服務', () => openSettings(Geolocator.openLocationSettings, '定位設定'), true),
      _ => ('重試定位', useGps, false),
    };
    AppButtonVariant lead(bool first) => first ? AppButtonVariant.primary : AppButtonVariant.secondary;

    return StatusBanner(
      tone: StatusTone.permission,
      title: title,
      text: text,
      actions: [
        AppButton(label: locateLabel, small: true, variant: lead(settingsFirst), onPressed: locate),
        AppButton(label: '手動選擇', small: true, variant: lead(!settingsFirst), onPressed: onManual),
      ],
    );
  }
}
