import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The 4 bottom-navigation tabs, in display order.
enum AppTab { weather, radar, rainfall, settings }

/// Selected tab. Pages switch tabs with
/// `ref.read(appTabProvider.notifier).select(AppTab.settings)` (e.g. 「手動選擇」).
final appTabProvider = NotifierProvider<AppTabNotifier, AppTab>(AppTabNotifier.new);

class AppTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.weather;

  void select(AppTab tab) => state = tab;
}
