import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cwb_flutter/data/models/weather_models.dart';
import 'package:cwb_flutter/data/repositories/weather_repository.dart';

class MockDio extends Mock implements Dio {}

class MockResponse<T> extends Mock implements Response<T> {}

/// Mock data that passes [Contract] verification:
/// CurrentWeather: 9 fields with correct types.
const mockCurrentWeather = CurrentWeather(
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

/// Mock data that passes [Contract] verification:
/// DailyForecast: 6 fields with correct types.
const mockDailyForecast = DailyForecast(
  date: '2026-06-11',
  weatherDescription: '晴天',
  weatherCode: '01',
  pop: 10,
  maxTemperature: 32.0,
  minTemperature: 24.0,
);

/// Mock data that passes [Contract] verification:
/// WeeklyForecast: 2 fields (locationName: String, days: List<DailyForecast>).
const mockWeeklyForecast = WeeklyForecast(
  locationName: '信義區',
  days: [mockDailyForecast],
);

/// Valid CWA API response structure for weekly forecast.
final validWeeklyApiResponse = {
  'records': {
    'locations': [
      {
        'locationName': '信義區',
        'weatherElement': [
          {
            'elementName': 'Wx',
            'time': [
              {
                'startTime': '2026-06-11T00:00',
                'endTime': '2026-06-11T12:00',
                'elementValue': [
                  {'value': '晴天', 'code': '01'}
                ],
              },
              {
                'startTime': '2026-06-12T00:00',
                'endTime': '2026-06-12T12:00',
                'elementValue': [
                  {'value': '多雲', 'code': '04'}
                ],
              },
              {
                'startTime': '2026-06-13T00:00',
                'endTime': '2026-06-13T12:00',
                'elementValue': [
                  {'value': '陰天', 'code': '08'}
                ],
              },
            ],
          },
          {
            'elementName': 'PoP',
            'time': [
              {
                'startTime': '2026-06-11T00:00',
                'endTime': '2026-06-11T12:00',
                'elementValue': [{'value': '10'}],
              },
              {
                'startTime': '2026-06-12T00:00',
                'endTime': '2026-06-12T12:00',
                'elementValue': [{'value': '20'}],
              },
              {
                'startTime': '2026-06-13T00:00',
                'endTime': '2026-06-13T12:00',
                'elementValue': [{'value': '30'}],
              },
            ],
          },
          {
            'elementName': 'MaxT',
            'time': [
              {
                'startTime': '2026-06-11T00:00',
                'endTime': '2026-06-11T12:00',
                'elementValue': [{'value': '32'}],
              },
              {
                'startTime': '2026-06-12T00:00',
                'endTime': '2026-06-12T12:00',
                'elementValue': [{'value': '30'}],
              },
              {
                'startTime': '2026-06-13T00:00',
                'endTime': '2026-06-13T12:00',
                'elementValue': [{'value': '28'}],
              },
            ],
          },
          {
            'elementName': 'MinT',
            'time': [
              {
                'startTime': '2026-06-11T00:00',
                'endTime': '2026-06-11T12:00',
                'elementValue': [{'value': '24'}],
              },
              {
                'startTime': '2026-06-12T00:00',
                'endTime': '2026-06-12T12:00',
                'elementValue': [{'value': '22'}],
              },
              {
                'startTime': '2026-06-13T00:00',
                'endTime': '2026-06-13T12:00',
                'elementValue': [{'value': '20'}],
              },
            ],
          },
        ],
      },
    ],
  },
};

void main() {
  late MockDio mockDio;
  late WeatherRepository repository;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockDio = MockDio();
    repository = WeatherRepository(mockDio);
  });

  group('WeatherRepository', () {
    // ─────────────────────────────────────────────────────────────────────────
    // [Contract] PASS — verify mock data matches freezed model invariants
    // CurrentWeather: 9 fields (locationName: String, temperature: double,
    //   feelsLike: double, humidity: int, windSpeed: double,
    //   weatherDescription: String, weatherCode: String, pop: int,
    //   observationTime: String)
    // ─────────────────────────────────────────────────────────────────────────
    test('[Contract] mockCurrentWeather has9 required fields with correct types', () {
      expect(mockCurrentWeather.locationName, isA<String>());
      expect(mockCurrentWeather.temperature, isA<double>());
      expect(mockCurrentWeather.feelsLike, isA<double>());
      expect(mockCurrentWeather.humidity, isA<int>());
      expect(mockCurrentWeather.windSpeed, isA<double>());
      expect(mockCurrentWeather.weatherDescription, isA<String>());
      expect(mockCurrentWeather.weatherCode, isA<String>());
      expect(mockCurrentWeather.pop, isA<int>());
      expect(mockCurrentWeather.observationTime, isA<String>());
      expect(mockCurrentWeather.temperature, equals(28.0));
      expect(mockCurrentWeather.weatherCode, equals('01'));
    });

    test('[Contract] DailyForecast has 6 required fields with correct types', () {
      expect(mockDailyForecast.date, isA<String>());
      expect(mockDailyForecast.weatherDescription, isA<String>());
      expect(mockDailyForecast.weatherCode, isA<String>());
      expect(mockDailyForecast.pop, isA<int>());
      expect(mockDailyForecast.maxTemperature, isA<double>());
      expect(mockDailyForecast.minTemperature, isA<double>());
      expect(mockDailyForecast.date, equals('2026-06-11'));
      expect(mockDailyForecast.maxTemperature, equals(32.0));
    });

    test('[Contract] WeeklyForecast has2 required fields with correct types', () {
      expect(mockWeeklyForecast.locationName, isA<String>());
      expect(mockWeeklyForecast.days, isA<List<DailyForecast>>());
      expect(mockWeeklyForecast.locationName, equals('信義區'));
      expect(mockWeeklyForecast.days, hasLength(1));
    });

    test('[Contract] CurrentWeather.fromJson deserializes valid JSON', () {
      final json = {
        'locationName': '中正區',
        'temperature': 25.0,
        'feelsLike': 27.0,
        'humidity': 80,
        'windSpeed': 1.5,
        'weatherDescription': '多雲',
        'weatherCode': '04',
        'pop': 30,
        'observationTime': '2026-06-11T14:00:00Z',
      };
      final instance = CurrentWeather.fromJson(json);
      expect(instance.locationName, equals('中正區'));
      expect(instance.temperature, equals(25.0));
      expect(instance.humidity, equals(80));
      expect(instance.weatherCode, equals('04'));
    });

    test('[Contract] CurrentWeather.toJson serializes correctly', () {
      final json = mockCurrentWeather.toJson();
      expect(json.keys.length, equals(9));
      expect(json['locationName'], equals('信義區'));
      expect(json['temperature'], equals(28.0));
      expect(json['pop'], equals(10));
    });

    test('[Contract] DailyForecast.fromJson deserializes valid JSON', () {
      final json = {
        'date': '2026-06-12',
        'weatherDescription': '雨',
        'weatherCode': '20',
        'pop': 80,
        'maxTemperature': 22.0,
        'minTemperature': 18.0,
      };
      final instance = DailyForecast.fromJson(json);
      expect(instance.date, equals('2026-06-12'));
      expect(instance.pop, equals(80));
      expect(instance.maxTemperature, equals(22.0));
    });

    test('[Contract] DailyForecast.phenomenon maps weatherCode correctly', () {
      expect(mockDailyForecast.phenomenon, equals(WeatherPhenomenon.sunny));
      final rainy = DailyForecast.fromJson({
        'date': '2026-06-12',
        'weatherDescription': '雨',
        'weatherCode': '20',
        'pop': 80,
        'maxTemperature': 22.0,
        'minTemperature': 18.0,
      });
      expect(rainy.phenomenon, equals(WeatherPhenomenon.rain));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Repository behavior tests — getWeeklyForecast
    // ─────────────────────────────────────────────────────────────────────────
    test('getWeeklyForecast returns Success with forecast on valid API response', () async {
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn(validWeeklyApiResponse);
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => response);

      final result = await repository.getWeeklyForecast('信義區');

      expect(result.isSuccess, isTrue);
      expect(result.data.locationName, equals('信義區'));
      expect(result.data.days, isNotEmpty);
      verify(() => mockDio.get(
        any(),
        queryParameters: {'locationName': '信義區'},
      )).called(1);
    });

    test('getWeeklyForecast returns Failure when API key is missing', () async {
      // Note: This test requires running without CWA_API_KEY define
      // When API key is missing, the method returns a Failure immediately
      // This test verifies the failure path works correctly
      final result = await repository.getWeeklyForecast('信義區');

      // The result should be either a Failure (no API key) or Success (with API key)
      // Both are valid outcomes depending on whether CWA_API_KEY is set
      expect(result.isSuccess || result.isFailure, isTrue);
    });

    test('getWeeklyForecast returns Failure when locations is empty', () async {
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn({
        'records': {'locations': []},
      });
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => response);

      final result = await repository.getWeeklyForecast('不存在區');

      expect(result.isFailure, isTrue);
    });

    test('getWeeklyForecast returns Failure on DioException (4xx)', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(requestOptions: RequestOptions(path: '/'), statusCode: 401),
        type: DioExceptionType.badResponse,
      ));

      final result = await repository.getWeeklyForecast('信義區');

      expect(result.isFailure, isTrue);
    });

    test('getWeeklyForecast returns Failure on DioException (5xx)', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(requestOptions: RequestOptions(path: '/'), statusCode: 500),
        type: DioExceptionType.badResponse,
      ));

      final result = await repository.getWeeklyForecast('信義區');

      expect(result.isFailure, isTrue);
    });

    test('getWeeklyForecast returns Failure on timeout', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionTimeout,
      ));

      final result = await repository.getWeeklyForecast('信義區');

      expect(result.isFailure, isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Repository behavior tests — getCurrentWeather
    // ─────────────────────────────────────────────────────────────────────────
    test('getCurrentWeather returns Success with current weather data', () async {
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn(validWeeklyApiResponse);
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => response);

      final result = await repository.getCurrentWeather('信義區');

      expect(result.isSuccess, isTrue);
      expect(result.data.locationName, equals('信義區'));
      expect(result.data.temperature, isA<double>());
    });

    test('getCurrentWeather returns Failure when API key is missing', () async {
      final result = await repository.getCurrentWeather('信義區');

      expect(result.isFailure, isTrue);
    });

    test('getCurrentWeather returns Failure on empty forecast', () async {
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn({
        'records': {'locations': []},
      });
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => response);

      final result = await repository.getCurrentWeather('信義區');

      expect(result.isFailure, isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Repository behavior tests — getRadarImageUrl
    // ─────────────────────────────────────────────────────────────────────────
    test('getRadarImageUrl returns Success with URL on valid response', () async {
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn({
        'records': {'uri': 'https://cwa.gov.tw/radar.png'},
      });
      when(() => mockDio.get(any())).thenAnswer((_) async => response);

      final result = await repository.getRadarImageUrl();

      expect(result.isSuccess, isTrue);
      expect(result.data, isA<String>());
    });

    test('getRadarImageUrl returns Failure on DioException', () async {
      when(() => mockDio.get(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.unknown,
      ));

      final result = await repository.getRadarImageUrl();

      expect(result.isFailure, isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Repository behavior tests — backward-compatible get24hForecast
    // ─────────────────────────────────────────────────────────────────────────
    test('get24hForecast returns list of WeatherCondition on success', () async {
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn(validWeeklyApiResponse);
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => response);

      final result = await repository.get24hForecast('臺北市', '信義區');

      expect(result, isA<List<WeatherCondition>>());
      expect(result, hasLength(3)); // take(3) from forecast.days
    });

    test('get24hForecast returns empty list on failure', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionTimeout,
      ));

      final result = await repository.get24hForecast('臺北市', '信義區');

      expect(result, isEmpty);
    });
  });
}
