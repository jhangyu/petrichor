import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/navigation/app_tab.dart';
import '../../core/layout/adaptive.dart';
import '../../data/location/location_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/time/taiwan_time.dart';
import '../../core/widgets/api_key_notice.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/status.dart';
import '../../data/models/place.dart';
import '../../data/models/weather_models.dart';
import '../../core/api/result.dart';
import '../hazard/hazard_provider.dart';
import '../hazard/warnings/warning_groups.dart';
import '../hazard/warnings/warnings_section.dart';
import '../place/place_provider.dart';
import 'weather_provider.dart';
import 'widgets/hourly_forecast_card.dart';
import 'weather_logic.dart';
import 'widgets/now_card.dart';
import 'widgets/weekly_card.dart';

/// 天氣 tab (`docs/design/home/final/home-v1.html`): now card (observation on the
/// sun arc), 7 日預報, 未來 72 小時預報 and the 警特報 section at the bottom, for
/// the current place. Each card shows its own loading / error / data state from
/// [WeatherState]'s per-dataset Result; a missing or rejected CWA token replaces
/// the whole page with one [ApiKeyNotice].
class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  /// The 警特報 section, target of the now card's jump badge.
  final _warningsKey = GlobalKey();

  static const _jumpDuration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final place = ref.watch(currentPlaceProvider);
    final weather = ref.watch(weatherNotifierProvider);
    void openLocationTab() => ref.read(appTabProvider.notifier).select(AppTab.settings);
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
      subtitleIconColor: selected == null ? AppPalette.warningForeground : AppPalette.brandForeground,
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
            isError: true,
            actions: [AppButton(label: '重新選擇地點', variant: AppButtonVariant.primary, onPressed: openLocationTab)],
          ),
        ],
      ),
      _ when selected == null => AppPageScaffold(
        header: header,
        children: const [AppGridItem.full(child: _PullHint(loading: true))],
      ),
      _ => _content(context, header, selected.$1, weather, refresh),
    };
  }

  /// 「目前位置 · 更新於 14:10」: when the app last finished loading the home data
  /// ([WeatherState.fetchedAt]); the observation time stays on the now card's 即時觀測 line.
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
    AppPageHeader header,
    Place place,
    WeatherState weather,
    VoidCallback refresh,
  ) {
    // The now card's 「現在 HH:mm」, countdown and sun position follow the
    // minute tick. Until its first event is delivered, the same injected clock is read directly.
    final now = switch (ref.watch(minuteTickProvider)) {
      AsyncData(:final value) => value,
      _ => ref.read(weatherClockProvider)(),
    };
    final hourly = weather.hourly;
    final current = weather.current;
    final warnings = ref.watch(activeWarningsProvider);
    final warningsResult = switch (warnings) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final apiKeyIssue = firstApiKeyIssue([
      current,
      hourly,
      weather.weekly,
      weather.sun,
      weather.hourlyIssuedAt,
      warningsResult,
    ]);
    if (apiKeyIssue != null) {
      return AppPageScaffold(
        header: header,
        onRefresh: () async => refresh(),
        children: [
          AppGridItem.full(child: ApiKeyNotice(issue: apiKeyIssue)),
          const AppGridItem.full(
            child: EmptyState(
              title: '天氣資料需要授權碼',
              text: '現況、日出日落、7 日、72 小時與警特報都使用同一組授權碼，所以整頁只顯示這一則提示。',
              icon: Icons.key_outlined,
            ),
          ),
        ],
      );
    }
    final countyWarnings = switch (warningsResult) {
      Success(:final data) => groupsForCounty(groupWarnings(data), place.county),
      _ => const <WarningGroup>[],
    };
    final sources = creditedDatasets(weather, place.county, warningsResult);
    return AppPageScaffold(
      header: header,
      onRefresh: () async => refresh(),
      source: sources.isEmpty ? null : SourceLine(datasetIds: sources),
      children: [
        if (weather.isLoading || WindowSizeClass.of(context).isCompactWidth)
          AppGridItem.full(child: _PullHint(loading: weather.isLoading)),
        AppGridItem.full(
          child: NowCard(
            state: nowCard(weather, now),
            warning: countyWarnings.firstOrNull,
            onJumpToWarnings: () =>
                Scrollable.ensureVisible(_warningsKey.currentContext!, duration: _jumpDuration),
            onRetry: refresh,
          ),
        ),
        AppGridItem.full(
          child: _ForecastFlow(
            weekly: WeeklyCard(
              weekly: weather.weekly,
              currentTemperature: current is Success<CurrentWeather> ? current.data.temperature : null,
              now: now,
              onRetry: refresh,
            ),
            forecast: HourlyForecastCard(hourly: hourly, issuedAt: weather.hourlyIssuedAt, now: now, onRetry: refresh),
          ),
        ),
        AppGridItem.full(child: WarningsSection(key: _warningsKey, county: place.county)),
      ],
    );
  }
}

/// 7 日 beside 未來 72 小時 (2 : 3 parts) once three grid columns fit; otherwise
/// stacked, 7 日 first (reading order).
class _ForecastFlow extends StatelessWidget {
  const _ForecastFlow({required this.weekly, required this.forecast});

  final Widget weekly;
  final Widget forecast;

  static const _weeklyFlex = 2;
  static const _forecastFlex = 3;

  /// Grid columns needed before the two cards share a row.
  static const _rowColumns = 3;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (AppGrid.columnsFor(box.maxWidth, spanUnits: _rowColumns) < _rowColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppLayout.gridGap,
            children: [weekly, forecast],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppLayout.gridGap,
          children: [
            Expanded(flex: _weeklyFlex, child: weekly),
            Expanded(flex: _forecastFlex, child: forecast),
          ],
        );
      },
    );
  }
}

/// `.ptr`: pull-to-refresh hint; while loading, the spinner pill 「載入天氣資料…」.
class _PullHint extends StatelessWidget {
  const _PullHint({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final style = AppType.caption1.copyWith(color: loading ? AppPalette.brandForegroundStrong : AppPalette.foreground3);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSize.controlSmall),
      child: Center(
        child: loading
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4),
                decoration: BoxDecoration(
                  color: AppPalette.background1,
                  borderRadius: BorderRadius.circular(AppRadius.full),
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
                  const Icon(Icons.expand_more, size: AppSize.icon16, color: AppPalette.foreground3),
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
    final title = locationFailureTitle(reason);
    final text = locationFailureMessage(reason);

    Future<void> openSettings(Future<bool> Function() open, String what) async {
      if (await open()) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(openSettingsFailedMessage(what))));
    }

    void startAutoLocate() => ref.read(currentPlaceProvider.notifier).startAutoLocate();
    // Settings actions lead (mockup 「前往設定」 primary); otherwise 手動選擇 leads.
    final (locateLabel, VoidCallback locate, settingsFirst) = switch (reason) {
      LocationFailure.permissionDenied => ('使用目前位置', startAutoLocate, false),
      LocationFailure.permissionDeniedForever => (
        '前往設定',
        () => openSettings(Geolocator.openAppSettings, '應用程式設定'),
        true,
      ),
      LocationFailure.serviceDisabled => ('開啟定位服務', () => openSettings(Geolocator.openLocationSettings, '定位設定'), true),
      _ => ('重試定位', startAutoLocate, false),
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
