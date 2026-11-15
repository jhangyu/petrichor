import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/layout/adaptive.dart';
import 'core/navigation/app_tab.dart';
import 'core/theme/app_tokens.dart';
import 'features/hazard/rainfall_screen.dart';
import 'features/radar/radar_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/weather/weather_screen.dart';

/// Full-window shell with the 4 tabs (天氣｜雷達｜雨量｜設定): bottom
/// [NavigationBar] on compact-width windows, [NavigationRail] on the left
/// otherwise ([WindowSizeClass.usesRail]). A tab is built on first visit and
/// then kept alive in an [IndexedStack], so radar frames are not fetched until
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
    AppTab.settings: ('設定', Icons.settings_outlined, SettingsScreen()),
  };

  /// Destinations start at the top of the rail (Fluent / M3 rail default).
  static const _railGroupAlignment = -1.0;

  final Set<AppTab> _visited = {};

  void _select(int i) => ref.read(appTabProvider.notifier).select(AppTab.values[i]);

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(appTabProvider);
    _visited.add(tab);
    final pages = IndexedStack(
      index: tab.index,
      children: [
        for (final t in AppTab.values) _visited.contains(t) ? _tabs[t]!.$3 : const SizedBox.shrink(),
      ],
    );
    if (WindowSizeClass.of(context).usesRail) {
      return Scaffold(
        backgroundColor: AppPalette.bg3,
        body: Row(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppPalette.stroke2, width: AppStroke.thin)),
              ),
              child: NavigationRail(
                selectedIndex: tab.index,
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                groupAlignment: _railGroupAlignment,
                // Short landscape windows (720x360) cannot fit every labelled destination.
                scrollable: true,
                backgroundColor: AppPalette.bg1,
                indicatorColor: AppPalette.brandBgSubtle,
                indicatorShape: const StadiumBorder(),
                selectedIconTheme: const IconThemeData(size: AppSize.icon24, color: AppPalette.brandFgStrong),
                unselectedIconTheme: const IconThemeData(size: AppSize.icon24, color: AppPalette.fg3),
                selectedLabelTextStyle:
                    AppType.caption1.copyWith(color: AppPalette.brandFgStrong, fontWeight: FontWeight.w600),
                unselectedLabelTextStyle: AppType.caption1.copyWith(color: AppPalette.fg3),
                destinations: [
                  for (final t in AppTab.values)
                    NavigationRailDestination(icon: Icon(_tabs[t]!.$2), label: Text(_tabs[t]!.$1)),
                ],
              ),
            ),
            Expanded(child: pages),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppPalette.bg3,
      body: pages,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppPalette.stroke2, width: AppStroke.thin)),
        ),
        child: NavigationBar(
          selectedIndex: tab.index,
          onDestinationSelected: _select,
          destinations: [
            for (final t in AppTab.values) NavigationDestination(icon: Icon(_tabs[t]!.$2), label: _tabs[t]!.$1),
          ],
        ),
      ),
    );
  }
}
