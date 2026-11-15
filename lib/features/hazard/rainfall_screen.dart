import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_shell.dart' show AppTab, appTabProvider;
import '../../core/layout/adaptive.dart';
import '../../core/location/location_service.dart' show LocationFailure;
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/api_key_notice.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/choices.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/status.dart';
import '../../data/models/place.dart';
import '../../data/repositories/hazard_repository.dart';
import '../../data/repositories/weather_repository.dart' show Failure, Result, Success;
import '../location/place_provider.dart';
import '../radar/radar_playback.dart';
import 'hazard_provider.dart';
import 'rainfall/forecast_view.dart';
import 'rainfall/observation_view.dart';
import 'rainfall/station_list.dart';

enum _RainView { observation, forecast }

const _loadingSubtitle = '正在取得測站資料…';
const _heroSkeletonHeight = 160.0;
const _mapSkeletonHeight = 300.0;
const _listSkeletonHeight = 240.0;
const _thresholdHint = '警戒等級依 24 小時累積雨量：大雨 80、豪雨 200、大豪雨 350、超大豪雨 500 mm。';

/// 雨量 tab (team-a/rainfall.html): 觀測 / 未來 1 小時.
class RainfallScreen extends ConsumerStatefulWidget {
  const RainfallScreen({super.key});

  @override
  ConsumerState<RainfallScreen> createState() => _RainfallScreenState();
}

class _RainfallScreenState extends ConsumerState<RainfallScreen> {
  _RainView _view = _RainView.observation;

  @override
  Widget build(BuildContext context) {
    final switcher = AppSegmented<_RainView>(
      segments: const [(_RainView.observation, '觀測'), (_RainView.forecast, '未來 1 小時')],
      selected: _view,
      onChanged: (v) => setState(() => _view = v),
    );
    return switch (ref.watch(currentPlaceProvider)) {
      AsyncData(value: PlaceSelected(:final place)) => _placeBody(place, switcher),
      AsyncData(value: NoPlace(:final reason)) => _scaffold(
        subtitle: '尚無目前地點',
        switcher: switcher,
        children: [AppGridItem.full(child: _noPlaceBanner(reason))],
      ),
      AsyncError(:final error) => _scaffold(
        subtitle: '無法讀取地點',
        switcher: switcher,
        children: [
          AppGridItem.full(
            child: AppCard.error(
              title: '無法讀取已儲存的地點',
              message: '$error',
              onRetry: () => ref.invalidate(currentPlaceProvider),
            ),
          ),
        ],
      ),
      _ => _scaffold(
        subtitle: _loadingSubtitle,
        switcher: switcher,
        children: const [AppGridItem.full(child: AppCard.loading(hero: true, skeletonHeight: _heroSkeletonHeight))],
      ),
    };
  }

  Widget _scaffold({
    required String subtitle,
    required Widget switcher,
    required List<Widget> children,
    List<String>? sourceIds,
    VoidCallback? onRefresh,
  }) {
    return AppPageScaffold(
      header: AppPageHeader(
        title: '雨量',
        subtitle: subtitle,
        subtitleIcon: Icons.schedule,
        actions: [AppIconButton(icon: Icons.refresh, tooltip: '重新整理', onPressed: onRefresh)],
      ),
      source: sourceIds == null ? null : SourceLine(datasetIds: sourceIds),
      children: [
        AppGridItem.full(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.readingWidth),
              child: switcher,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _noPlaceBanner(LocationFailure reason) {
    return StatusBanner(
      tone: StatusTone.permission,
      title: '尚無目前地點',
      text: locationFailureMessage(reason),
      actions: [
        AppButton(
          label: '允許定位',
          variant: AppButtonVariant.primary,
          small: true,
          onPressed: () => ref.read(currentPlaceProvider.notifier).useGps(),
        ),
        AppButton(
          label: '手動選擇',
          variant: AppButtonVariant.subtle,
          small: true,
          onPressed: () => ref.read(appTabProvider.notifier).select(AppTab.location),
        ),
      ],
    );
  }

  Widget _placeBody(Place place, Widget switcher) {
    return switch (_view) {
      _RainView.observation => _observation(place, switcher),
      _RainView.forecast => _forecast(place, switcher),
    };
  }

  // ---- 觀測 ----

  Widget _observation(Place place, Widget switcher) {
    final loc = place.hazardLocation;
    final rainfall = ref.watch(rainfallProvider(loc));
    final map = ref.watch(rainfallMapProvider);
    void retryRainfall() => ref.invalidate(rainfallProvider(loc));
    void retryMap() => ref.invalidate(rainfallMapProvider);
    final result = rainfall.value;
    final mapResult = map.value;
    final loading = rainfall.isLoading || map.isLoading;
    final anyData = result is Success || mapResult is Success;
    final hero = _resultCard(
      rainfall,
      errorTitle: '無法取得雨量資料',
      skeleton: const AppCard.loading(hero: true, skeletonHeight: _heroSkeletonHeight),
      onRetry: retryRainfall,
      builder: (r) => ObservationHeroCard(rainfall: r),
    );
    final mapCard = _resultCard(
      map,
      errorTitle: '無法取得累積雨量圖',
      skeleton: const AppCard.loading(title: '累積雨量圖', skeletonHeight: _mapSkeletonHeight),
      onRetry: retryMap,
      builder: (m) => RainfallMapCard(map: m, latitude: place.latitude, longitude: place.longitude),
    );
    final list = _resultCard(
      rainfall,
      errorTitle: '無法取得測站列表',
      skeleton: const AppCard.loading(title: '測站今日累積雨量', skeletonHeight: _listSkeletonHeight),
      onRetry: retryRainfall,
      builder: (r) => StationListCard(county: r.county, stations: r.allStations, nearestId: r.nearest.id),
      showError: false,
    );
    return _scaffold(
      subtitle: switch (result) {
        Success(:final data) => '${place.name} · 觀測 ${formatTaiwanClock(data.nearest.obsTime)}',
        Failure() => '${place.name} · 無法取得觀測',
        null => _loadingSubtitle,
      },
      switcher: switcher,
      sourceIds: anyData ? const [rainObservationDataset, rainfallMapDataset] : null,
      onRefresh: loading
          ? null
          : () {
              retryRainfall();
              retryMap();
            },
      children: [
        AppGridItem.full(
          child: _panes(hero: hero, map: mapCard, list: list),
        ),
        if (result is Success)
          AppGridItem.full(
            child: Text(_thresholdHint, style: AppType.caption1.copyWith(color: AppPalette.fg3)),
          ),
      ],
    );
  }

  // ---- 未來 1 小時 ----

  Widget _forecast(Place place, Widget switcher) {
    final loc = (latitude: place.latitude, longitude: place.longitude);
    final forecast = ref.watch(rainForecastProvider(loc));
    void retry() => ref.invalidate(rainForecastProvider(loc));
    final hero = _resultCard(
      forecast,
      errorTitle: '無法取得降雨預測',
      skeleton: const AppCard.loading(hero: true, skeletonHeight: _heroSkeletonHeight),
      onRetry: retry,
      builder: (f) => ForecastHeroCard(forecast: f, placeName: place.name),
    );
    final mapCard = _resultCard(
      forecast,
      errorTitle: '無法取得降雨預測',
      skeleton: const AppCard.loading(title: '未來 1 小時雨量', skeletonHeight: _mapSkeletonHeight),
      onRetry: retry,
      builder: (f) => ForecastMapCard(grid: f.grid, latitude: place.latitude, longitude: place.longitude),
      showError: false,
    );
    return _scaffold(
      subtitle: switch (forecast.value) {
        Success(:final data) => '${place.name} · 預測發布 ${formatTaiwanClock(data.grid.issuedAt)}',
        Failure() => '${place.name} · 無法取得預測',
        null => _loadingSubtitle,
      },
      switcher: switcher,
      sourceIds: forecast.value is Success ? const [rainForecast1hDataset] : null,
      onRefresh: forecast.isLoading ? null : retry,
      children: [
        AppGridItem.full(
          child: _panes(hero: hero, map: mapCard),
        ),
      ],
    );
  }

  /// Hero (+ [list]) in the main pane, map in the side pane when both fit side by side;
  /// otherwise stacked in reading order hero, map, list.
  Widget _panes({required Widget? hero, required Widget? map, Widget? list}) {
    final mapSlot = map == null
        ? null
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.paneMaxWidth),
              child: map,
            ),
          );
    Widget column(List<Widget?> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppLayout.gridGap,
      children: [...items.nonNulls],
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (mapSlot == null || !AppTwoPane.fits(box.maxWidth)) return column([hero, mapSlot, list]);
        return AppTwoPane(main: column([hero, list]), side: mapSlot);
      },
    );
  }

  /// One card per provider state. [showError] false hides the failure (the sibling card
  /// of the same provider already shows the error banner once).
  Widget? _resultCard<T>(
    AsyncValue<Result<T>> async, {
    required String errorTitle,
    required Widget skeleton,
    required VoidCallback onRetry,
    required Widget Function(T data) builder,
    bool showError = true,
  }) {
    return switch (async) {
      AsyncData(value: Success(:final data)) => builder(data),
      AsyncData(value: Failure(apiKeyIssue: final issue?)) => showError ? ApiKeyNotice(issue: issue) : null,
      AsyncData(value: Failure(:final message)) =>
        showError ? AppCard.error(title: errorTitle, message: message, onRetry: onRetry) : null,
      AsyncError(:final error) => AppCard.error(title: errorTitle, message: '$error', onRetry: onRetry),
      _ => skeleton,
    };
  }
}
