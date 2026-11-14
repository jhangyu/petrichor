import 'package:flutter/material.dart';

import 'core/theme/app_tokens.dart';
import 'features/hazard/rainfall_screen.dart';
import 'features/hazard/warnings_screen.dart';
import 'features/location/location_screen.dart';
import 'features/radar/radar_screen.dart';
import 'features/weather/weather_screen.dart';

/// Centred 480-wide mobile column with the 5-tab bottom navigation
/// (天氣｜雷達｜雨量｜警特報｜地點). A tab is built on first visit and then
/// kept alive in an [IndexedStack], so radar frames are not fetched until
/// the user opens 雷達 and every tab keeps its state when switching.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _tabs = <(String, IconData, Widget)>[
    ('天氣', Icons.home_outlined, WeatherScreen()),
    ('雷達', Icons.radar, RadarScreen()),
    ('雨量', Icons.water_drop_outlined, RainfallScreen()),
    ('警特報', Icons.warning_amber_outlined, WarningsScreen()),
    ('地點', Icons.location_on_outlined, LocationScreen()),
  ];

  int _index = 0;
  final Set<int> _visited = {0};

  void _select(int index) => setState(() {
        _index = index;
        _visited.add(index);
      });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppPalette.bg3,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSize.layoutMaxWidth),
          child: Scaffold(
            body: IndexedStack(
              index: _index,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  _visited.contains(i) ? _tabs[i].$3 : const SizedBox.shrink(),
              ],
            ),
            bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppPalette.stroke2, width: AppStroke.thin)),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _select,
                destinations: [
                  for (final (label, icon, _) in _tabs) NavigationDestination(icon: Icon(icon), label: label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
