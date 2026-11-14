import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/location/location_service.dart';
import '../../data/models/weather_models.dart';
import '../../data/repositories/weather_repository.dart';

/// 首頁狀態。四組資料各自成敗（null＝尚未載入或定位失敗），單一資料集失敗不影響其他。
/// [error] 僅用於整頁級錯誤（定位失敗）。
class WeatherState {
  final LocationData? location;
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

/// 定位失敗 → 使用者可讀訊息（含下一步）
String locationFailureMessage(LocationException e) {
  return switch (e.failure) {
    LocationFailure.serviceDisabled => '裝置的定位服務已關閉，請開啟後重試',
    LocationFailure.permissionDenied => '尚未允許定位權限，請允許後重試',
    LocationFailure.permissionDeniedForever => '定位權限已被永久拒絕，請到系統設定開啟',
    LocationFailure.positionUnavailable => '無法取得目前位置，請稍後重試',
    LocationFailure.addressUnresolved => '無法判斷所在縣市與鄉鎮，請稍後重試',
  };
}

/// 首頁「今天」的時鐘（測試可覆寫）
final weatherClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class WeatherNotifier extends Notifier<WeatherState> {
  @override
  WeatherState build() {
    Future.microtask(_init);
    return const WeatherState();
  }

  Future<void> _init() async {
    final LocationData location;
    try {
      location = await ref.read(locationServiceProvider).getCurrentLocation();
    } on LocationException catch (e) {
      state = WeatherState(isLoading: false, error: locationFailureMessage(e));
      return;
    }

    final repo = ref.read(weatherRepositoryProvider);
    final (current, hourly, weekly, sun) = await (
      repo.getCurrentWeather(location),
      repo.getHourlyForecast(location.city, location.district),
      repo.getWeeklyForecast(location.city, location.district),
      repo.getSunTimes(location.city, ref.read(weatherClockProvider)()),
    ).wait;

    state = WeatherState(
      location: location,
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
