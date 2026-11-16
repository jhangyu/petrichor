import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/navigation/app_tab.dart' show AppTab, appTabProvider;
import '../../core/layout/adaptive.dart';
import '../../data/location/location_service.dart' show LocationFailure;
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/api_key_notice.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/status.dart';
import '../../data/models/hazard_models.dart' show CountyRainfall;
import '../../data/models/place.dart';
import '../../core/api/cwa_datasets.dart';
import '../../core/api/result.dart' show Failure, Result, Success;
import '../place/place_provider.dart';
import '../place/location_failure_text.dart';
import '../../core/time/taiwan_time.dart';
import '../radar/widgets/radar_map_view.dart' show RadarCameraLink;
import 'hazard_provider.dart';
import 'rainfall/rain_accumulation_card.dart';
import 'rainfall/rain_accumulation_provider.dart';
import 'rainfall/forecast_map_card.dart';
import 'rainfall/observation_hero_card.dart';
import 'rainfall/rainfall_logic.dart';
import 'rainfall/station_list_card.dart';

const _loadingSubtitle = '正在取得測站資料…';
const _heroSkeletonHeight = 160.0;
const _mapSkeletonHeight = 300.0;
const _listSkeletonHeight = 240.0;
final _thresholdHint =
    '警戒等級依 24 小時累積雨量：${[for (var i = 0; i < rainWarningThresholds.length; i++) rainThresholdLabel(i)].join('、')} mm。';

/// 雨量 tab: 最近測站, 累積雨量, 未來1hr預測, 測站今日累積雨量.
class RainfallScreen extends ConsumerWidget {
  const RainfallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(currentPlaceProvider)) {
      AsyncData(value: PlaceSelected(:final place)) => _placeBody(ref, place),
      AsyncData(value: NoPlace(:final reason)) => _noPlaceBody(ref, reason),
      AsyncError(:final error) => _scaffold(
        subtitle: '無法讀取地點',
        children: [
          AppGridItem.full(
            child: AppCard.error(title: '無法讀取已儲存的地點', message: '$error', onRetry: () => ref.invalidate(currentPlaceProvider)),
          ),
        ],
      ),
      _ => _scaffold(
        subtitle: _loadingSubtitle,
        children: const [AppGridItem.full(child: AppCard.loading(hero: true, skeletonHeight: _heroSkeletonHeight))],
      ),
    };
  }

  Widget _scaffold({
    required String subtitle,
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
      children: children,
    );
  }

  /// The accumulation and forecast map cards sharing one camera row.
  Widget _mapRow(LatLng? me, Widget? Function(RadarCameraLink? link, bool wide) forecastCard) {
    return AppGridItem.full(
      child: _MapCards(
        cards: (link, wide) => [AccumulationCard(me: me, cameraLink: link, wide: wide), ?forecastCard(link, wide)],
      ),
    );
  }

  /// Refresh action: disabled while [busy], else retries every provider then the accumulation loop.
  VoidCallback? _refreshAll(WidgetRef ref, {required bool busy, required List<VoidCallback> retries}) {
    return busy
        ? null
        : () {
            for (final retry in retries) {
              retry();
            }
            ref.invalidate(accumulationLoopProvider);
          };
  }

  /// 最近測站 in its no-place state: why, with the buttons to locate or pick a place.
  Widget _noPlaceCard(WidgetRef ref, LocationFailure reason) {
    return AppCard(
      title: '最近測站',
      child: StatusBanner(
        tone: StatusTone.permission,
        title: '尚無目前地點',
        text: locationFailureMessage(reason),
        actions: [
          AppButton(
            label: '允許定位',
            variant: AppButtonVariant.primary,
            small: true,
            onPressed: () => ref.read(currentPlaceProvider.notifier).startAutoLocate(),
          ),
          AppButton(
            label: '選擇地點',
            variant: AppButtonVariant.subtle,
            small: true,
            onPressed: () => ref.read(appTabProvider.notifier).select(AppTab.settings),
          ),
        ],
      ),
    );
  }

  /// No place: the nearest-station card asks for one, the rest needs none (national data).
  Widget _noPlaceBody(WidgetRef ref, LocationFailure reason) {
    final stations = ref.watch(rainStationsProvider);
    final grid = ref.watch(rainForecastGridProvider);
    void retryStations() => ref.invalidate(rainStationsProvider);
    void retryGrid() => ref.invalidate(rainForecastGridProvider);
    Widget? forecastCard(RadarCameraLink? link, bool wide) => _resultCard(
      grid,
      errorTitle: '無法取得降雨預測',
      skeleton: const AppCard.loading(title: '未來 1hr 預測', skeletonHeight: _mapSkeletonHeight),
      onRetry: retryGrid,
      builder: (g) => ForecastMapCard(grid: g, currentPlaceForecast: null, cameraLink: link, wide: wide),
    );
    final list = _resultCard(
      stations,
      errorTitle: '無法取得測站列表',
      skeleton: const AppCard.loading(title: '測站今日累積雨量', skeletonHeight: _listSkeletonHeight),
      onRetry: retryStations,
      builder: (all) => StationListCard(county: null, stations: all, nearestId: null),
    );
    return _scaffold(
      subtitle: '尚無目前地點',
      sourceIds: [if (stations.value is Success) CwaDatasets.rainObservationDatasetId, if (grid.value is Success) CwaDatasets.rainForecastOneHourDatasetId],
      onRefresh: _refreshAll(ref, busy: stations.isLoading || grid.isLoading, retries: [retryStations, retryGrid]),
      children: [
        AppGridItem.full(child: _noPlaceCard(ref, reason)),
        _mapRow(null, forecastCard),
        if (list != null) AppGridItem.full(child: list),
      ],
    );
  }

  Widget _placeBody(WidgetRef ref, Place place) {
    final hazardLocation = place.hazardLocation;
    final rainfall = ref.watch(countyRainfallProvider(hazardLocation));
    final forecastPoint = (latitude: place.latitude, longitude: place.longitude);
    final me = LatLng(place.latitude, place.longitude);
    final forecast = ref.watch(rainForecastProvider(forecastPoint));
    void retryRainfall() => ref.invalidate(countyRainfallProvider(hazardLocation));
    void retryForecast() => ref.invalidate(rainForecastProvider(forecastPoint));
    final result = rainfall.value;
    final forecastResult = forecast.value;
    // A missing token shows one notice, on the nearest-station card.
    final tokenIssue = result is Failure<CountyRainfall> && result.apiKeyIssue != null;
    final hero = _resultCard(
      rainfall,
      errorTitle: '無法取得雨量資料',
      skeleton: const AppCard.loading(hero: true, skeletonHeight: _heroSkeletonHeight),
      onRetry: retryRainfall,
      builder: (r) => ObservationHeroCard(rainfall: r),
    );
    Widget? forecastCard(RadarCameraLink? link, bool wide) => _resultCard(
      forecast,
      errorTitle: '無法取得降雨預測',
      skeleton: const AppCard.loading(title: '未來 1hr 預測', skeletonHeight: _mapSkeletonHeight),
      onRetry: retryForecast,
      builder: (f) => ForecastMapCard(
        grid: f.grid,
        currentPlaceForecast: (name: place.name, point: me, millimeters: f.millimetersAtLocation),
        cameraLink: link,
        wide: wide,
      ),
      showError: !tokenIssue,
    );
    final list = _resultCard(
      rainfall,
      errorTitle: '無法取得測站列表',
      skeleton: const AppCard.loading(title: '測站今日累積雨量', skeletonHeight: _listSkeletonHeight),
      onRetry: retryRainfall,
      builder: (r) => StationListCard(county: r.county, stations: r.allStations, nearestId: r.nearest.id),
      showError: false,
    );
    final sourceIds = [if (result is Success) CwaDatasets.rainObservationDatasetId, if (forecastResult is Success) CwaDatasets.rainForecastOneHourDatasetId];
    return _scaffold(
      subtitle: switch (result) {
        Success(:final data) => '${place.name} · 觀測 ${clockText(data.nearest.observedAt)}',
        Failure() => '${place.name} · 無法取得觀測',
        null => _loadingSubtitle,
      },
      sourceIds: sourceIds.isEmpty ? null : sourceIds,
      onRefresh: _refreshAll(ref, busy: rainfall.isLoading || forecast.isLoading, retries: [retryRainfall, retryForecast]),
      children: [
        if (hero != null) AppGridItem.full(child: hero),
        _mapRow(me, forecastCard),
        if (list != null) AppGridItem.full(child: list),
        if (result is Success)
          AppGridItem.full(
            child: Text(_thresholdHint, style: AppType.caption1.copyWith(color: AppPalette.foreground3)),
          ),
      ],
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
      AsyncData(value: Failure(:final message)) => showError ? AppCard.error(title: errorTitle, message: message, onRetry: onRetry) : null,
      AsyncError(:final error) => AppCard.error(title: errorTitle, message: '$error', onRetry: onRetry),
      _ => skeleton,
    };
  }
}

/// The map cards, one per row in order. Wide (radar's map+controls split
/// fits, [AppTwoPane.fitsWindow]): each card puts its map left and controls
/// right, and the maps share one camera. Otherwise each map is square and locked.
class _MapCards extends StatefulWidget {
  const _MapCards({required this.cards});

  /// The cards in order, given the shared camera (null when narrow) and the layout.
  final List<Widget> Function(RadarCameraLink? link, bool wide) cards;

  @override
  State<_MapCards> createState() => _MapCardsState();
}

class _MapCardsState extends State<_MapCards> {
  final _link = RadarCameraLink();

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // box is the full-row grid cell: page margin already removed.
        final wide = AppTwoPane.fitsWindow(context, box.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppLayout.gridGap,
          children: widget.cards(wide ? _link : null, wide),
        );
      },
    );
  }
}
