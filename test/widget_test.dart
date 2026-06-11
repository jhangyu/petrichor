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

final smokeCondition = WeatherCondition(
  wx: '晴天',
  pop: 10,
  t: 28,
  startTime: 'now',
  endTime: 'later',
);

final smokeLocation = LocationData(
  latitude: 25.0330,
  longitude: 121.5654,
  city: '臺北市',
  district: '信義區',
);

void main() {
  /// Smoke test: verifies the full WeatherScreen renders without crashing,
  /// loading skeleton appears, and data loads successfully.
  testWidgets('WeatherScreen smoke test: loading → success', (tester) async {
    final mockLocService = MockLocationService();
    final mockRepo = MockWeatherRepository();

    when(() => mockLocService.getCurrentLocation())
        .thenAnswer((_) async => smokeLocation);
    when(() => mockRepo.get24hForecast('臺北市', '信義區'))
        .thenAnswer((_) async => [smokeCondition]);

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

    // Phase 1: loading skeleton
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Phase 2: data loaded (actual UI: '${current.t}°C')
    await tester.pumpAndSettle();
    expect(find.text('28°C'), findsAtLeastNWidgets(1));
    expect(find.text('晴天'), findsOneWidget);
    expect(find.text('臺北市 信義區'), findsOneWidget);
  });

  testWidgets('WeatherScreen smoke test: loading → error', (tester) async {
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
}
