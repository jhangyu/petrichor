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
/// otherwise ([WindowSizeClass.usesNavigationRail]). A tab is built on first visit and
/// then kept alive in an [IndexedStack], so radar frames are not fetched until
/// the user opens 雷達 and every tab keeps its state when switching.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

/// Label, icon and page of one tab.
typedef _TabSpec = ({String label, IconData icon, Widget page});

class _AppShellState extends ConsumerState<AppShell> {
  static const _tabs = <AppTab, _TabSpec>{
    AppTab.weather: (label: '天氣', icon: Icons.home_outlined, page: WeatherScreen()),
    AppTab.radar: (label: '雷達', icon: Icons.radar, page: RadarScreen()),
    AppTab.rainfall: (label: '雨量', icon: Icons.water_drop_outlined, page: RainfallScreen()),
    AppTab.settings: (label: '設定', icon: Icons.settings_outlined, page: SettingsScreen()),
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
        // Hidden tabs stay mounted but their tickers (map pump, spinners) stop.
        for (final t in AppTab.values)
          TickerMode(enabled: t == tab, child: _visited.contains(t) ? _tabs[t]!.page : const SizedBox.shrink()),
      ],
    );
    final usesNavigationRail = WindowSizeClass.of(context).usesNavigationRail;
    return Scaffold(
      backgroundColor: AppPalette.background3,
      body: usesNavigationRail ? Row(children: [_rail(tab), Expanded(child: pages)]) : pages,
      bottomNavigationBar: usesNavigationRail ? null : _bar(tab),
    );
  }

  Widget _rail(AppTab tab) {
    return DecoratedBox(
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
        backgroundColor: AppPalette.background1,
        indicatorColor: AppPalette.brandBackgroundSubtle,
        indicatorShape: const StadiumBorder(),
        selectedIconTheme: const IconThemeData(size: AppSize.icon24, color: AppPalette.brandForegroundStrong),
        unselectedIconTheme: const IconThemeData(size: AppSize.icon24, color: AppPalette.foreground3),
        selectedLabelTextStyle: AppType.caption1.copyWith(color: AppPalette.brandForegroundStrong, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: AppType.caption1.copyWith(color: AppPalette.foreground3),
        destinations: [
          for (final t in AppTab.values)
            NavigationRailDestination(icon: Icon(_tabs[t]!.icon), label: Text(_tabs[t]!.label)),
        ],
      ),
    );
  }

  Widget _bar(AppTab tab) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppPalette.stroke2, width: AppStroke.thin)),
      ),
      child: NavigationBar(
        selectedIndex: tab.index,
        onDestinationSelected: _select,
        destinations: [
          for (final t in AppTab.values) NavigationDestination(icon: Icon(_tabs[t]!.icon), label: _tabs[t]!.label),
        ],
      ),
    );
  }
}
