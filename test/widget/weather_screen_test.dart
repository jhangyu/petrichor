import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cwb_flutter/core/location/location_service.dart';
import 'package:cwb_flutter/data/models/weather_models.dart';
import 'package:cwb_flutter/data/repositories/weather_repository.dart';
import 'package:cwb_flutter/features/weather/weather_screen.dart';

class MockLocationService extends Mock implements LocationService {}

class MockWeatherRepository extends Mock implements WeatherRepository {}

final mockCondition1 = WeatherCondition(
  wx: '晴天',
  pop: 10,
  t: 28,
  startTime: 'now',
  endTime: 'later',
);

final mockCondition2 = WeatherCondition(
  wx: '多雲',
  pop: 20,
  t: 25,
  startTime: 'later',
  endTime: 'much later',
);

final mockLocation = LocationData(
  latitude: 25.0330,
  longitude: 121.5654,
  city: '臺北市',
  district: '信義區',
);

void main() {
  group('WeatherScreen', () {
    testWidgets('[Contract] loading state shows CircularProgressIndicator', (tester) async {
      final mockLocService = MockLocationService();
      final mockRepo = MockWeatherRepository();

      when(() => mockLocService.getCurrentLocation())
          .thenAnswer((_) async => mockLocation);
      when(() => mockRepo.get24hForecast('臺北市', '信義區'))
          .thenAnswer((_) async => [mockCondition1]);

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLocService),
          weatherRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WeatherScreen()),
        ),
      );

      // Initial state before async _init() completes
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('[Contract] success state shows temperature and weather description', (tester) async {
      final mockLocService = MockLocationService();
      final mockRepo = MockWeatherRepository();

      when(() => mockLocService.getCurrentLocation())
          .thenAnswer((_) async => mockLocation);
      when(() => mockRepo.get24hForecast('臺北市', '信義區'))
          .thenAnswer((_) async => [mockCondition1, mockCondition2]);

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLocService),
          weatherRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WeatherScreen()),
        ),
      );

      // Wait for async _init() to complete
      await tester.pumpAndSettle();

      // Weather card displays temperature (main temp is large, forecast item is smaller)
      expect(find.text('28°C'), findsAtLeastNWidgets(1));
      // Weather description
      expect(find.text('晴天'), findsOneWidget);
      // Location header
      expect(find.text('臺北市 信義區'), findsOneWidget);
    });

    testWidgets('[Contract] error state shows error message', (tester) async {
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

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WeatherScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('[Contract] success state shows forecast list items', (tester) async {
      final mockLocService = MockLocationService();
      final mockRepo = MockWeatherRepository();

      when(() => mockLocService.getCurrentLocation())
          .thenAnswer((_) async => mockLocation);
      when(() => mockRepo.get24hForecast('臺北市', '信義區'))
          .thenAnswer((_) async => [mockCondition1, mockCondition2]);

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLocService),
          weatherRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WeatherScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Both forecast items should be visible in the horizontal list
      expect(find.text('28°C'), findsAtLeastNWidgets(1));
      expect(find.text('25°C'), findsAtLeastNWidgets(1));
    });

    testWidgets('[Contract] map icon button is present', (tester) async {
      final mockLocService = MockLocationService();
      final mockRepo = MockWeatherRepository();

      when(() => mockLocService.getCurrentLocation())
          .thenAnswer((_) async => mockLocation);
      when(() => mockRepo.get24hForecast('臺北市', '信義區'))
          .thenAnswer((_) async => [mockCondition1]);

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLocService),
          weatherRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WeatherScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Map icon button should be present
      expect(find.byIcon(Icons.map), findsOneWidget);
    });
  });
}
