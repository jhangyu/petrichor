import 'dart:convert';

import 'package:petrichor/core/storage/stored_setting.dart';
import 'package:petrichor/data/models/place.dart';
import 'package:petrichor/features/place/place_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Settings only: the values are stored and restored; nothing delivers a notification yet.

enum NotifyToggle { master, rain, quiet }

enum QuietEdge { start, end }

/// Minutes in a day; valid minute-of-day values are 0 ..< minutesPerDay.
const minutesPerDay = Duration.minutesPerDay;

const _warningAreasKey = 'notify.warningAreas';
const _defaultQuietStartMinute = 22 * Duration.minutesPerHour;
const _defaultQuietEndMinute = 7 * Duration.minutesPerHour;

/// A notification on/off switch (stored as 1 / 0), off on a fresh install.
class NotifyToggleSetting extends IntSetting<bool> {
  NotifyToggleSetting(this.toggle);
  final NotifyToggle toggle;

  @override
  String get key => 'notify.${toggle.name}';
  @override
  bool get defaultValue => false;
  @override
  String get expected => '0 or 1';
  @override
  bool? fromStored(int stored) => switch (stored) { 1 => true, 0 => false, _ => null };
  @override
  int toStored(bool value) => value ? 1 : 0;
}

/// Start or end of the quiet hours as minute of day.
class QuietMinuteSetting extends IntSetting<int> {
  QuietMinuteSetting(this.edge);
  final QuietEdge edge;

  @override
  String get key => edge == QuietEdge.start ? 'notify.quietStart' : 'notify.quietEnd';
  @override
  int get defaultValue => edge == QuietEdge.start ? _defaultQuietStartMinute : _defaultQuietEndMinute;
  @override
  String get expected => '0..${minutesPerDay - 1}';
  @override
  int? fromStored(int stored) => stored >= 0 && stored < minutesPerDay ? stored : null;
  @override
  int toStored(int value) => value;
}

final notifyToggleProvider =
    AsyncNotifierProvider.family<NotifyToggleSetting, bool, NotifyToggle>(NotifyToggleSetting.new, retry: noRetry);
final quietMinuteProvider =
    AsyncNotifierProvider.family<QuietMinuteSetting, int, QuietEdge>(QuietMinuteSetting.new, retry: noRetry);

final warningAreasProvider = AsyncNotifierProvider<WarningAreas, Set<String>>(WarningAreas.new, retry: noRetry);

/// Area keys of the saved places whose 警特報 is on. Keys of places that are no
/// longer saved are pruned from the store whenever the saved places change.
class WarningAreas extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final saved = {for (final p in await ref.watch(savedPlacesProvider.future)) p.areaKey};
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final stored = _parse(prefs.get(_warningAreasKey));
    final kept = stored.intersection(saved);
    if (kept.length != stored.length) await _write(kept);
    return kept;
  }

  /// Turns 警特報 of [place] on or off. On a corrupt stored set, overwrites it with [place] alone or empty.
  Future<void> setPlace(Place place, bool on) async {
    final saved = await ref.read(savedPlacesProvider.future);
    if (!saved.any((p) => p.areaKey == place.areaKey)) {
      throw ArgumentError.value(place, 'place', 'expected a saved place, key ${place.areaKey}');
    }
    final next = {...?state.value}..remove(place.areaKey);
    if (on) next.add(place.areaKey);
    state = AsyncData(next);
    final written = await AsyncValue.guard(() async {
      await _write(next);
      return next;
    });
    // A later setPlace() may have replaced the state meanwhile; only a failure overrides it.
    if (written is AsyncError || state.value == next) state = written;
  }

  /// Overwrites the stored set with empty (all off): recovery from a corrupt set, needs no saved place.
  Future<void> reset() async {
    await _write(const {});
    state = const AsyncData({});
  }

  Future<void> _write(Set<String> keys) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await writeChecked(_warningAreasKey, prefs.setString(_warningAreasKey, jsonEncode(keys.toList()..sort())));
  }

  static Set<String> _parse(Object? raw) {
    if (raw == null) return {};
    StoredSettingException corrupt() =>
        StoredSettingException(_warningAreasKey, '儲存資料損毀：期望 非空且不重複的字串 JSON 陣列，實際「$raw」');
    if (raw is! String) throw corrupt();
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw corrupt();
    }
    if (decoded is! List) throw corrupt();
    final keys = <String>{};
    for (final item in decoded) {
      if (item is! String || item.isEmpty || !keys.add(item)) throw corrupt();
    }
    return keys;
  }
}
