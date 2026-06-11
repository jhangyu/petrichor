import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cwb_flutter/core/location/location_service.dart';
import 'package:cwb_flutter/data/models/weather_models.dart';
import 'package:cwb_flutter/data/repositories/weather_repository.dart';
import 'package:cwb_flutter/features/weather/weather_provider.dart';

class MockLocationService extends Mock implements LocationService {}

class MockWeatherRepository extends Mock implements WeatherRepository {}

/// Mock data that passes [Contract] verification:
/// DailyForecast: 6 fields with correct types.
final mockDailyForecast = DailyForecast(
  date: '2026-06-11',
  weatherDescription: '晴天',
  weatherCode: '01',
  pop: 10,
  maxTemperature: 32.0,
  minTemperature: 24.0,
);

final mockWeeklyForecast = WeeklyForecast(
  locationName: '信義區',
  days: [mockDailyForecast],
);

final mockCurrentWeather = CurrentWeather(
  locationName: '信義區',
  temperature: 28.0,
  feelsLike: 30.0,
  humidity: 75,
  windSpeed: 2.5,
  weatherDescription: '晴天',
  weatherCode: '01',
  pop: 10,
  observationTime: '2026-06-11T12:00:00Z',
);

final mockLocation = LocationData(
  latitude: 25.0330,
  longitude: 121.5654,
  city: '臺北市',
  district: '信義區',
);

/// Wait for provider state to settle (loading becomes false)
Future<WeatherState> _waitForState(ProviderContainer container) async {
  // Listen for state changes
  final completer = Completer<WeatherState>();
  late ProviderSubscription<WeatherState> subscription;

  subscription = container.listen<WeatherState>(
    weatherNotifierProvider,
    (previous, next) {
      if (!next.isLoading) {
        subscription.close();
        if (!completer.isCompleted) {
          completer.complete(next);
        }
      }
    },
    fireImmediately: true,
  );

  return completer.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () => container.read(weatherNotifierProvider),
  );
}

void main() {
  group('WeatherNotifier', () {
    test('[Contract] mockDailyForecast has 6 required fields with correct types', () {
      expect(mockDailyForecast.date, isA<String>());
      expect(mockDailyForecast.weatherDescription, isA<String>());
      expect(mockDailyForecast.weatherCode, isA<String>());
      expect(mockDailyForecast.pop, isA<int>());
      expect(mockDailyForecast.maxTemperature, isA<double>());
      expect(mockDailyForecast.minTemperature, isA<double>());
      expect(mockDailyForecast.date, equals('2026-06-11'));
      expect(mockDailyForecast.maxTemperature, equals(32.0));
    });

    test('[Contract] WeatherState initial state is correct', () {
      final state = WeatherState();
      expect(state.isLoading, isTrue);
      expect(state.forecast, isEmpty);
      expect(state.location, isNull);
      expect(state.error, isNull);
    });

    test('[Contract] WeatherState.copyWith updates only specified fields', () {
      final state = WeatherState(isLoading: true);
      final updated = state.copyWith(isLoading: false, error: 'test error');

      expect(updated.isLoading, isFalse);
      expect(updated.error, equals('test error'));
      expect(updated.location, isNull);
      expect(updated.forecast, isEmpty);
    });

    test('[Contract] WeatherState.copyWith preserves unchanged fields', () {
      final condition = WeatherCondition(
        wx: '晴天',
        pop: 10,
        t: 28,
        startTime: 'now',
        endTime: 'later',
      );
      final state = WeatherState(
        location: mockLocation,
        forecast: [condition],
        isLoading: false,
      );
      final updated = state.copyWith(error: 'some error');

      expect(updated.location, equals(mockLocation));
      expect(updated.forecast, equals([condition]));
      expect(updated.isLoading, isFalse);
      expect(updated.error, equals('some error'));
    });

    test('loading state → success state: sets location and forecast', () async {
      final mockLocService = MockLocationService();
      final mockRepo = MockWeatherRepository();

      when(() => mockLocService.getCurrentLocation())
          .thenAnswer((_) async => mockLocation);
      when(() => mockRepo.get24hForecast('臺北市', '信義區'))
          .thenAnswer((_) async => [
                WeatherCondition(
                  wx: '晴天',
                  pop: 10,
                  t: 28,
                  startTime: 'now',
                  endTime: 'later',
                ),
              ]);

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLocService),
          weatherRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      addTearDown(container.dispose);

      final state = await _waitForState(container);

      expect(state.location, equals(mockLocation));
      expect(state.forecast, hasLength(1));
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('loading state → error state: sets error on location failure', () async {
      final mockLocService = MockLocationService();
      final mockRepo = MockWeatherRepository();

      when(() => mockLocService.getCurrentLocation())
          .thenThrow(Exception('Location unavailable'));
      when(() => mockRepo.get24hForecast(any(), any()))
          .thenAnswer((_) async => []);

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLocService),
          weatherRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      addTearDown(container.dispose);

      final state = await _waitForState(container);

      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
    });

    test('loading state → error state: sets error on repository failure', () async {
      final mockLocService = MockLocationService();
      final mockRepo = MockWeatherRepository();

      when(() => mockLocService.getCurrentLocation())
          .thenAnswer((_) async => mockLocation);
      when(() => mockRepo.get24hForecast('臺北市', '信義區'))
          .thenThrow(Exception('Network error'));

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLocService),
          weatherRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      addTearDown(container.dispose);

      final state = await _waitForState(container);

      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
    });

    test('loading state → empty forecast: no error, just empty list', () async {
      final mockLocService = MockLocationService();
      final mockRepo = MockWeatherRepository();

      when(() => mockLocService.getCurrentLocation())
          .thenAnswer((_) async => mockLocation);
      when(() => mockRepo.get24hForecast('臺北市', '信義區'))
          .thenAnswer((_) async => []);

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLocService),
          weatherRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      addTearDown(container.dispose);

      final state = await _waitForState(container);

      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.forecast, isEmpty);
      expect(state.location, equals(mockLocation));
    });
  });
}
