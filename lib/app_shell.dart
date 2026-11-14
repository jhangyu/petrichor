import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_tokens.dart';
import 'features/hazard/rainfall_screen.dart';
import 'features/hazard/warnings_screen.dart';
import 'features/location/location_screen.dart';
import 'features/radar/radar_screen.dart';
import 'features/weather/weather_screen.dart';

/// The 5 bottom-navigation tabs, in display order.
enum AppTab { weather, radar, rainfall, warnings, location }

/// Selected tab. Pages switch tabs with
/// `ref.read(appTabProvider.notifier).select(AppTab.location)` (e.g. 「手動選擇」).
final appTabProvider = NotifierProvider<AppTabNotifier, AppTab>(AppTabNotifier.new);

class AppTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.weather;

  void select(AppTab tab) => state = tab;
}

/// Centred 480-wide mobile column with the 5-tab bottom navigation
/// (天氣｜雷達｜雨量｜警特報｜地點). A tab is built on first visit and then
/// kept alive in an [IndexedStack], so radar frames are not fetched until
/// the user opens 雷達 and every tab keeps its state when switching.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _tabs = <AppTab, (String, IconData, Widget)>{
    AppTab.weather: ('天氣', Icons.home_outlined, WeatherScreen()),
    AppTab.radar: ('雷達', Icons.radar, RadarScreen()),
    AppTab.rainfall: ('雨量', Icons.water_drop_outlined, RainfallScreen()),
    AppTab.warnings: ('警特報', Icons.warning_amber_outlined, WarningsScreen()),
    AppTab.location: ('地點', Icons.location_on_outlined, LocationScreen()),
  };

  final Set<AppTab> _visited = {};

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(appTabProvider);
    _visited.add(tab);
    return ColoredBox(
      color: AppPalette.bg3,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSize.layoutMaxWidth),
          child: Scaffold(
            body: IndexedStack(
              index: tab.index,
              children: [
                for (final t in AppTab.values) _visited.contains(t) ? _tabs[t]!.$3 : const SizedBox.shrink(),
              ],
            ),
            bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppPalette.stroke2, width: AppStroke.thin)),
              ),
              child: NavigationBar(
                selectedIndex: tab.index,
                onDestinationSelected: (i) => ref.read(appTabProvider.notifier).select(AppTab.values[i]),
                destinations: [
                  for (final t in AppTab.values) NavigationDestination(icon: Icon(_tabs[t]!.$2), label: _tabs[t]!.$1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
