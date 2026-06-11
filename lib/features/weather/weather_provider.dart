import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/location/location_service.dart';
import '../../data/models/weather_models.dart';
import '../../data/repositories/weather_repository.dart';

// State to hold both location and forecast
class WeatherState {
  final LocationData? location;
  final List<WeatherCondition> forecast;
  final bool isLoading;
  final String? error;

  WeatherState({
    this.location,
    this.forecast = const [],
    this.isLoading = true,
    this.error,
  });

  WeatherState copyWith({
    LocationData? location,
    List<WeatherCondition>? forecast,
    bool? isLoading,
    String? error,
  }) {
    return WeatherState(
      location: location ?? this.location,
      forecast: forecast ?? this.forecast,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class WeatherNotifier extends Notifier<WeatherState> {
  @override
  WeatherState build() {
    // We can't await in build directly without AsyncNotifier, so we call _init async.
    // However, it's safer to just start it.
    Future.microtask(() => _init());
    return WeatherState();
  }

  Future<void> _init() async {
    try {
      final locService = ref.read(locationServiceProvider);
      final location = await locService.getCurrentLocation();
      
      state = state.copyWith(location: location);

      final repo = ref.read(weatherRepositoryProvider);
      final forecast = await repo.get24hForecast(location.city, location.district);

      state = state.copyWith(forecast: forecast, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final weatherNotifierProvider = NotifierProvider<WeatherNotifier, WeatherState>(() {
  return WeatherNotifier();
});
