import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/place.dart';
import '../../data/models/weather_models.dart';
import '../../data/repositories/weather_repository.dart';
import '../location/place_provider.dart';

/// 首頁狀態。四組資料各自成敗（null＝尚未載入或尚無地點），單一資料集失敗不影響其他。
/// [error] 僅用於整頁級錯誤（尚無地點、地點儲存資料損毀）。
class WeatherState {
  final Place? location;
  final Result<CurrentWeather>? current;
  final Result<List<HourlyForecast>>? hourly;
  final Result<List<DailyForecast>>? weekly;

  /// [今天, 明天] 的日出日沒
  final Result<List<SunDay>>? sun;
  final bool isLoading;

  /// 使用者可讀的中文錯誤訊息（整頁級）
  final String? error;

  const WeatherState({
    this.location,
    this.current,
    this.hourly,
    this.weekly,
    this.sun,
    this.isLoading = true,
    this.error,
  });
}

/// 首頁「今天」的時鐘（測試可覆寫）
final weatherClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// 依目前地點（[currentPlaceProvider]）載入首頁資料；地點變更即重新載入。
class WeatherNotifier extends Notifier<WeatherState> {
  @override
  WeatherState build() {
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
    final (current, hourly, weekly, sun) = await (
      repo.getCurrentWeather(place.toLocationData()),
      repo.getHourlyForecast(place.county, place.town),
      repo.getWeeklyForecast(place.county, place.town),
      repo.getSunTimes(place.county, ref.read(weatherClockProvider)()),
    ).wait;
    // 地點已變更（重新 build）則丟棄舊結果
    if (!buildRef.mounted) return;

    state = WeatherState(
      location: place,
      current: current,
      hourly: hourly,
      weekly: weekly,
      sun: sun,
      isLoading: false,
    );
  }
}

final weatherNotifierProvider = NotifierProvider<WeatherNotifier, WeatherState>(() {
  return WeatherNotifier();
});
