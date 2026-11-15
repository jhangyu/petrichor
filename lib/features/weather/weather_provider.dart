import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/place.dart';
import '../../data/models/weather_models.dart';
import '../../core/api/result.dart';
import '../../data/repositories/weather_repository.dart';
import '../location/place_provider.dart';

/// 首頁狀態。四組資料各自成敗（null＝尚未載入或尚無地點），單一資料集失敗不影響其他。
/// [error] 僅用於整頁級錯誤（尚無地點、地點儲存資料損毀）。
class WeatherState {
  final Place? location;
  final Result<CurrentWeather>? current;
  final Result<List<HourlyForecast>>? hourly;
  final Result<List<DailyForecast>>? weekly;

  /// [昨天, 今天, 明天] 的日出日沒
  final Result<List<SunDay>>? sun;

  /// 72 小時預報（[hourly] 同一資料集）的發布時間
  final Result<DateTime>? hourlyIssuedAt;

  /// App 完成這次載入的時刻（[weatherClockProvider]）；首頁「更新於」。尚未載入完成為 null
  final DateTime? fetchedAt;
  final bool isLoading;

  /// 使用者可讀的中文錯誤訊息（整頁級）
  final String? error;

  const WeatherState({
    this.location,
    this.current,
    this.hourly,
    this.weekly,
    this.sun,
    this.hourlyIssuedAt,
    this.fetchedAt,
    this.isLoading = true,
    this.error,
  });
}

/// 首頁「今天」的時鐘（測試可覆寫）
final weatherClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// 建立計時器的函式（測試可覆寫為假計時器）
typedef TimerFactory = Timer Function(Duration delay, void Function() callback);

final minuteTimerFactoryProvider = Provider<TimerFactory>((ref) => Timer.new);

/// 每分鐘整點對齊的時鐘節拍（值為 [weatherClockProvider] 當下時刻）；訂閱即先送出一次。
/// 首頁「現在 HH:mm」、倒數與太陽位置據此重算；不輪詢資料。
final minuteTickProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.watch(weatherClockProvider);
  final schedule = ref.watch(minuteTimerFactoryProvider);
  late final StreamController<DateTime> controller;
  Timer? timer;
  void arm() {
    final now = clock();
    final intoMinute = Duration(seconds: now.second, milliseconds: now.millisecond, microseconds: now.microsecond);
    timer = schedule(const Duration(minutes: 1) - intoMinute, () {
      controller.add(clock());
      arm();
    });
  }

  controller = StreamController<DateTime>(
    onListen: () {
      controller.add(clock());
      arm();
    },
    onCancel: () => timer?.cancel(),
  );
  ref.onDispose(controller.close);
  return controller.stream;
});

/// 依目前地點（[currentPlaceProvider]）載入首頁資料；地點變更即重新載入。
class WeatherNotifier extends Notifier<WeatherState> {
  @override
  WeatherState build() {
    // 金鑰變更會重建 repository，據此重新載入
    ref.watch(weatherRepositoryProvider);
    return switch (ref.watch(currentPlaceProvider)) {
      AsyncLoading() => const WeatherState(),
      AsyncError(:final error) => WeatherState(isLoading: false, error: '$error'),
      AsyncData(value: NoPlace(:final reason)) =>
        WeatherState(isLoading: false, error: locationFailureMessage(reason)),
      AsyncData(value: PlaceSelected(:final place)) => _startLoad(place),
    };
  }

  WeatherState _startLoad(Place place) {
    final buildRef = ref;
    Future.microtask(() => _load(place, buildRef));
    return WeatherState(location: place);
  }

  Future<void> _load(Place place, Ref buildRef) async {
    final repo = ref.read(weatherRepositoryProvider);
    final (current, hourly, weekly, sun, hourlyIssuedAt) = await (
      repo.getCurrentWeather(place.toLocationData()),
      repo.getHourlyForecast(place.county, place.town),
      repo.getWeeklyForecast(place.county, place.town),
      repo.getSunTimes(place.county, ref.read(weatherClockProvider)()),
      repo.getForecastIssueTime(place.county),
    ).wait;
    // 地點已變更（重新 build）則丟棄舊結果
    if (!buildRef.mounted) return;

    state = WeatherState(
      location: place,
      current: current,
      hourly: hourly,
      weekly: weekly,
      sun: sun,
      hourlyIssuedAt: hourlyIssuedAt,
      fetchedAt: ref.read(weatherClockProvider)(),
      isLoading: false,
    );
  }
}

final weatherNotifierProvider = NotifierProvider<WeatherNotifier, WeatherState>(() {
  return WeatherNotifier();
});
