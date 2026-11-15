import 'package:petrichor/data/repositories/weather_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_cwa_adapter.dart';

/// 1 週預報 臺北市 指定要素第 [slot] 個時間槽的第一個 ElementValue
Map<String, dynamic> _weeklyValue(Map<String, dynamic> json, String element, int slot) {
  final location = (((json['records'] as Map)['Locations'] as List).first as Map)['Location'] as List;
  final elements = ((location.first as Map)['WeatherElement'] as List).cast<Map<String, dynamic>>();
  final time = (elements.firstWhere((e) => e['ElementName'] == element)['Time'] as List)[slot] as Map;
  return ((time['ElementValue'] as List).first as Map).cast<String, dynamic>();
}

void main() {
  late FakeCwaAdapter adapter;
  late WeatherRepository repo;

  setUp(() {
    adapter = FakeCwaAdapter();
    repo = WeatherRepository(adapter.dio());
  });

  test('"-" 12-hour rain probability is a missing slot (null), other values intact', () async {
    adapter.serveFixture('F-D0047-091', (json) {
      _weeklyValue(json, '12小時降雨機率', 1)['ProbabilityOfPrecipitation'] = '-';
      return null;
    }, 'F-D0047-063');
    final r = await repo.getWeeklyForecast('臺北市', '臺北市');

    final days = r.data;
    expect(days[1].pop, isNull);
    expect(days[1].maxTemperature, 24);
    expect(days[1].humidity, 92);
    expect(days[2].pop, 30);
  });

  test('non-numeric value other than "-" is still a Failure naming expected and actual', () async {
    adapter.serveFixture('F-D0047-091', (json) {
      _weeklyValue(json, '12小時降雨機率', 1)['ProbabilityOfPrecipitation'] = 'abc';
      return null;
    }, 'F-D0047-063');
    final r = await repo.getWeeklyForecast('臺北市', '臺北市');

    final f = r as Failure;
    expect(f.dataset, 'F-D0047-063');
    expect(f.message, contains('期望數字，實際「abc」'));
  });
}
