import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app_shell.dart' show AppTab, appTabProvider;
import '../../core/layout/adaptive.dart';
import '../../core/location/location_service.dart' show LocationFailure;
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/api_key_notice.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/status.dart';
import '../../data/models/hazard_models.dart' show CountyRainfall;
import '../../data/models/place.dart';
import '../../data/repositories/hazard_repository.dart';
import '../../data/repositories/weather_repository.dart' show Failure, Result, Success;
import '../location/place_provider.dart';
import '../radar/radar_playback.dart';
import 'hazard_provider.dart';
import 'rainfall/accum_card.dart';
import 'rainfall/accum_provider.dart';
import 'rainfall/forecast_view.dart';
import 'rainfall/observation_view.dart';
import 'rainfall/station_list.dart';

const _loadingSubtitle = '正在取得測站資料…';
const _heroSkeletonHeight = 160.0;
const _mapSkeletonHeight = 300.0;
const _listSkeletonHeight = 240.0;
const _thresholdHint = '警戒等級依 24 小時累積雨量：大雨 80、豪雨 200、大豪雨 350、超大豪雨 500 mm。';

/// 雨量 tab: 最近測站, 未來1hr預測, 累積雨量, 測站今日累積雨量.
class RainfallScreen extends ConsumerWidget {
  const RainfallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(currentPlaceProvider)) {
      AsyncData(value: PlaceSelected(:final place)) => _placeBody(ref, place),
      AsyncData(value: NoPlace(:final reason)) => _scaffold(
        ref,
        subtitle: '尚無目前地點',
        children: [
          AppGridItem.full(child: _noPlaceBanner(ref, reason)),
          AppGridItem.full(child: _paneWidth(const AccumulationCard(me: null))),
        ],
      ),
      AsyncError(:final error) => _scaffold(
        ref,
        subtitle: '無法讀取地點',
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
        ref,
        subtitle: _loadingSubtitle,
        children: const [AppGridItem.full(child: AppCard.loading(hero: true, skeletonHeight: _heroSkeletonHeight))],
      ),
    };
  }

  Widget _scaffold(
    WidgetRef ref, {
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

  Widget _paneWidth(Widget child) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: AppLayout.paneMaxWidth), child: child),
  );

  Widget _noPlaceBanner(WidgetRef ref, LocationFailure reason) {
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
          onPressed: () => ref.read(appTabProvider.notifier).select(AppTab.settings),
        ),
      ],
    );
  }

  Widget _placeBody(WidgetRef ref, Place place) {
    final loc = place.hazardLocation;
    final rainfall = ref.watch(rainfallProvider(loc));
    final forecastLoc = (latitude: place.latitude, longitude: place.longitude);
    final forecast = ref.watch(rainForecastProvider(forecastLoc));
    void retryRainfall() => ref.invalidate(rainfallProvider(loc));
    void retryForecast() => ref.invalidate(rainForecastProvider(forecastLoc));
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
    final forecastCard = _resultCard(
      forecast,
      errorTitle: '無法取得降雨預測',
      skeleton: const AppCard.loading(title: '未來 1hr 預測', skeletonHeight: _mapSkeletonHeight),
      onRetry: retryForecast,
      builder: (f) => ForecastMapCard(forecast: f, placeName: place.name, latitude: place.latitude, longitude: place.longitude),
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
    final sourceIds = [
      if (result is Success) rainObservationDataset,
      if (forecastResult is Success) rainForecast1hDataset,
    ];
    final accum = AccumulationCard(me: LatLng(place.latitude, place.longitude));
    return _scaffold(
      ref,
      subtitle: switch (result) {
        Success(:final data) => '${place.name} · 觀測 ${formatTaiwanClock(data.nearest.obsTime)}',
        Failure() => '${place.name} · 無法取得觀測',
        null => _loadingSubtitle,
      },
      sourceIds: sourceIds.isEmpty ? null : sourceIds,
      onRefresh: rainfall.isLoading || forecast.isLoading
          ? null
          : () {
              retryRainfall();
              retryForecast();
              ref.invalidate(accumLoopProvider);
            },
      children: [
        if (hero != null) AppGridItem.full(child: hero),
        AppGridItem.full(child: _mapRow([?forecastCard, accum])),
        if (list != null) AppGridItem.full(child: list),
        if (result is Success)
          AppGridItem.full(
            child: Text(_thresholdHint, style: AppType.caption1.copyWith(color: AppPalette.fg3)),
          ),
      ],
    );
  }

  /// The map cards side by side when two panes fit, otherwise stacked in order.
  Widget _mapRow(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, box) {
        if (cards.length < 2 || !AppTwoPane.fits(box.maxWidth)) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: AppLayout.gridGap, children: cards);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppLayout.gridGap,
          children: [for (final c in cards) Expanded(child: c)],
        );
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
