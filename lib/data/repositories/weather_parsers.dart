part of 'weather_repository.dart';

// ============================================================================
// 邊界解析（CWA 回應 → 強型別；結構不符一律丟 FormatException，由 _query 轉成 Failure）
// ============================================================================

/// CWA 缺值標記（所有值皆為字串）
const double _missingValue = -99;
final _missingText = _missingValue.toStringAsFixed(0); // '-99'

/// 一週預報顯示天數
const int _weeklyDayCount = 7;

/// 12 小時預報中「白天時段」的起始時（臺灣時間）
const int _daySlotStartHour = 6;
const String _wgs84 = 'WGS84';

Map<String, dynamic> _asObject(Object? v, String path) {
  if (v is Map<String, dynamic>) return v;
  throw FormatException('$path：期望物件，實際 ${v.runtimeType}');
}

List<Object?> _asList(Object? v, String path) {
  if (v is List<Object?>) return v;
  throw FormatException('$path：期望陣列，實際 ${v.runtimeType}');
}

/// 沿路徑取值；中途缺少即回 null（欄位可選）。
Object? _digPath(Map<String, dynamic> m, List<String> path) {
  Object? cur = m;
  for (final key in path) {
    if (cur is! Map<String, dynamic>) return null;
    cur = cur[key];
  }
  return cur;
}

/// `records.Station`, at least one station.
List<Object?> _stationList(Map<String, dynamic> body) {
  final stations = _asList(_digPath(body, ['records', 'Station']), 'records.Station');
  if (stations.isEmpty) throw const FormatException('records.Station：期望至少 1 站，實際 0 站');
  return stations;
}

/// `records.Locations[0]`, which must exist.
Map<String, dynamic> _firstLocationGroup(Map<String, dynamic> body) {
  final groups = _asList(_digPath(body, ['records', 'Locations']), 'records.Locations');
  if (groups.isEmpty) throw const FormatException('records.Locations：期望 1 組，實際 0 組');
  return _asObject(groups.first, 'records.Locations[0]');
}

/// CWA 以「-」表示該時間槽無值（例如 12 小時降雨機率）。
const _noValueMarker = '-';

/// 數值字串 → double；缺值（null、-99、「-」）→ null；其他非數字 → FormatException。
double? _asNumber(Object? raw, String path) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text == _noValueMarker) return null;
  final value = double.tryParse(text);
  if (value == null) throw FormatException('$path：期望數字，實際「$text」');
  return value == _missingValue ? null : value;
}

int? _int(Object? raw, String path) => _asNumber(raw, path)?.round();

/// 文字欄位；缺值（null、-99、空字串）→ null。
String? _text(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  return (text.isEmpty || text == _missingText) ? null : text;
}

DateTime _asInstant(Object? raw, String path) {
  if (raw is! String) throw FormatException('$path：期望時間字串，實際 ${raw.runtimeType}');
  return DateTime.parse(raw);
}

double _distanceKilometers(double lat1, double lon1, double lat2, double lon2) {
  double radians(double degrees) => degrees * math.pi / 180;
  final latitudeDelta = radians(lat2 - lat1);
  final longitudeDelta = radians(lon2 - lon1);
  final a = math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(radians(lat1)) * math.cos(radians(lat2)) * math.pow(math.sin(longitudeDelta / 2), 2);
  return 2 * AppConstants.earthRadiusKm * math.asin(math.sqrt(a));
}

CurrentWeather _parseObservation(Map<String, dynamic> body, double latitude, double longitude) {
  final stations = _stationList(body);

  Map<String, dynamic>? best;
  double bestKm = double.infinity;
  for (var i = 0; i < stations.length; i++) {
    final path = 'records.Station[$i]';
    final station = _asObject(stations[i], path);
    final temp = _asNumber(_digPath(station, ['WeatherElement', 'AirTemperature']), '$path.AirTemperature');
    if (temp == null) continue;
    final (stationLatitude, stationLongitude) = _wgs84Of(station, path);
    final km = _distanceKilometers(latitude, longitude, stationLatitude, stationLongitude);
    if (km < bestKm) {
      bestKm = km;
      best = station;
    }
  }
  if (best == null) {
    throw FormatException('期望至少 1 站有氣溫讀數，實際 ${stations.length} 站皆缺氣溫');
  }

  final weatherElement = _asObject(best['WeatherElement'], 'WeatherElement');
  return CurrentWeather(
    stationName: _text(best['StationName']) ?? '',
    observedAt: _asInstant(_digPath(best, ['ObsTime', 'DateTime']), 'ObsTime.DateTime'),
    temperature: _asNumber(weatherElement['AirTemperature'], 'AirTemperature')!,
    humidity: _int(weatherElement['RelativeHumidity'], 'RelativeHumidity'),
    windSpeed: _asNumber(weatherElement['WindSpeed'], 'WindSpeed'),
    windDirection: _observedWind(weatherElement['WindDirection']),
    weather: _text(weatherElement['Weather']),
    dailyHigh: _asNumber(
      _digPath(weatherElement, ['DailyExtreme', 'DailyHigh', 'TemperatureInfo', 'AirTemperature']),
      'DailyHigh',
    ),
    dailyLow: _asNumber(
      _digPath(weatherElement, ['DailyExtreme', 'DailyLow', 'TemperatureInfo', 'AirTemperature']),
      'DailyLow',
    ),
  );
}

/// 測站所屬縣市與到使用者的距離
class _StationCounty {
  final String county;
  final double km;
  const _StationCounty(this.county, this.km);
}

/// 全部測站依距離由近到遠排序；縣市名正規化成「臺」。
List<_StationCounty> _parseStationCounties(Map<String, dynamic> body, double latitude, double longitude) {
  final stations = _stationList(body);
  return [
    for (var i = 0; i < stations.length; i++)
      _stationCounty(_asObject(stations[i], 'records.Station[$i]'), latitude, longitude, 'records.Station[$i]'),
  ]..sort((a, b) => a.km.compareTo(b.km));
}

_StationCounty _stationCounty(Map<String, dynamic> station, double latitude, double longitude, String path) {
  final county = _text(_digPath(station, ['GeoInfo', 'CountyName'])) ??
      (throw FormatException('$path.GeoInfo.CountyName：期望縣市名，實際缺值'));
  final (stationLatitude, stationLongitude) = _wgs84Of(station, path);
  return _StationCounty(normalizeCwaPlaceName(county), _distanceKilometers(latitude, longitude, stationLatitude, stationLongitude));
}

(double, double) _wgs84Of(Map<String, dynamic> station, String path) {
  final coords = _asList(_digPath(station, ['GeoInfo', 'Coordinates']), '$path.GeoInfo.Coordinates')
      .map((c) => _asObject(c, '$path.GeoInfo.Coordinates[]'))
      .firstWhere(
        (c) => c['CoordinateName'] == _wgs84,
        orElse: () => throw FormatException('$path：缺少 $_wgs84 座標'),
      );
  return (
    _asNumber(coords['StationLatitude'], '$path.StationLatitude') ??
        (throw FormatException('$path.StationLatitude：期望緯度，實際缺值')),
    _asNumber(coords['StationLongitude'], '$path.StationLongitude') ??
        (throw FormatException('$path.StationLongitude：期望經度，實際缺值')),
  );
}

Place _nearestPlace(List<Place> places, double latitude, double longitude) => places.reduce((a, b) =>
    _distanceKilometers(latitude, longitude, a.latitude, a.longitude) <= _distanceKilometers(latitude, longitude, b.latitude, b.longitude) ? a : b);

final _issueTimePattern = RegExp(r'"IssueTime"\s*:\s*"([^"]+)"');
final _sunClockPattern = RegExp(r'^\d{2}:\d{2}$');
final _transitAltitudePattern = RegExp(r'^(\d{1,2})([NS])$');

/// file API 回應開頭（非完整 JSON）→ DatasetInfo.IssueTime。
DateTime _parseIssueTime(String head, String dataset) {
  final match = _issueTimePattern.firstMatch(head);
  if (match == null) {
    throw FormatException(
      '$dataset 前 ${head.length} 位元組：期望含 DatasetInfo.IssueTime，實際開頭「${head.substring(0, math.min(head.length, 80))}」',
    );
  }
  return _asInstant(match.group(1), 'DatasetInfo.IssueTime');
}

/// 觀測風向的特殊值（度）：0＝靜風，990＝風向不定；其餘 1–360 為方位角（360＝北）。
const double _calmWindDegrees = 0;
const double _variableWindDegrees = 990;
const double _fullCircleDegrees = 360;

/// 觀測風向（度，字串）→ [ObservedWind]；缺值 → null；範圍外 → FormatException。
ObservedWind? _observedWind(Object? raw) {
  final degrees = _asNumber(raw, 'WindDirection');
  if (degrees == null) return null;
  if (degrees == _calmWindDegrees) return const ObservedWind.calm();
  if (degrees == _variableWindDegrees) return const ObservedWind.variable();
  if (degrees < 0 || degrees > _fullCircleDegrees) {
    throw FormatException(
      'WindDirection：期望 0（靜風）、1–360 度或 990（風向不定），實際「$raw」',
    );
  }
  return ObservedWind.degrees(degrees);
}

List<Place> _parseTowns(Map<String, dynamic> body, String county) {
  final group = _firstLocationGroup(body);
  final actual = normalizeCwaPlaceName(_text(group['LocationsName']) ?? '');
  if (actual != county) throw FormatException('LocationsName：期望「$county」，實際「$actual」');
  final list = _asList(group['Location'], 'Location');
  if (list.isEmpty) throw FormatException('$county Location：期望至少 1 個鄉鎮，實際 0 個');
  return [
    for (var i = 0; i < list.length; i++)
      _town(_asObject(list[i], 'Location[$i]'), county, 'Location[$i]'),
  ];
}

Place _town(Map<String, dynamic> locationJson, String county, String path) {
  final town = _text(locationJson['LocationName']) ?? (throw FormatException('$path.LocationName：期望鄉鎮名，實際「${locationJson['LocationName']}」'));
  return Place(
    county: county,
    town: normalizeCwaPlaceName(town),
    latitude: _asNumber(locationJson['Latitude'], '$path.Latitude') ?? (throw FormatException('$path.Latitude：期望緯度，實際缺值')),
    longitude: _asNumber(locationJson['Longitude'], '$path.Longitude') ?? (throw FormatException('$path.Longitude：期望經度，實際缺值')),
  );
}

/// 一個時間槽：起點（key）、終點（僅區間型要素有）、第一個 ElementValue。
class _Slot {
  final DateTime? end;
  final Map<String, dynamic> value;
  const _Slot(this.end, this.value);
}

/// 要素名稱 → 依起點排序的時間槽
typedef _Elements = Map<String, Map<DateTime, _Slot>>;

_Elements _parseElements(Map<String, dynamic> body, String township) {
  final list = _asList(_firstLocationGroup(body)['Location'], 'Location');
  final names = <String>[];
  for (final item in list) {
    final locationJson = _asObject(item, 'Location[]');
    final name = _text(locationJson['LocationName']) ?? '';
    names.add(name);
    if (name != township) continue;
    final elements = <String, Map<DateTime, _Slot>>{};
    for (final e in _asList(locationJson['WeatherElement'], '$name.WeatherElement')) {
      final elementJson = _asObject(e, '$name.WeatherElement[]');
      final elementName = _text(elementJson['ElementName']) ?? '';
      final slots = <DateTime, _Slot>{};
      for (final t in _asList(elementJson['Time'], '$elementName.Time')) {
        final timeJson = _asObject(t, '$elementName.Time[]');
        final rawStart = timeJson['StartTime'] ?? timeJson['DataTime'];
        final rawEnd = timeJson['EndTime'];
        final values = _asList(timeJson['ElementValue'], '$elementName.ElementValue');
        if (values.isEmpty) throw FormatException('$elementName：ElementValue 為空');
        slots[_asInstant(rawStart, '$elementName.StartTime')] = _Slot(
          rawEnd == null ? null : _asInstant(rawEnd, '$elementName.EndTime'),
          _asObject(values.first, '$elementName.ElementValue[0]'),
        );
      }
      elements[elementName] = Map.fromEntries(
        slots.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );
    }
    return elements;
  }
  throw FormatException(
    '期望地點「$township」，實際 ${names.isEmpty ? '無任何地點（若地名含「台」請改「臺」）' : names.join('、')}',
  );
}

Map<DateTime, _Slot> _element(_Elements elements, String name) =>
    elements[name] ?? (throw FormatException('缺少要素「$name」，實際要素：${elements.keys.join('、')}'));

List<HourlyForecast> _parseHourly(Map<String, dynamic> body, String township) {
  final elementsByName = _parseElements(body, township);
  final weather = _element(elementsByName, '天氣現象');
  final temperature = _element(elementsByName, '溫度');
  final apparent = _element(elementsByName, '體感溫度');
  final humidity = _element(elementsByName, '相對濕度');
  final windSpeed = _element(elementsByName, '風速');
  final windDirection = _element(elementsByName, '風向');
  final pop = _element(elementsByName, '3小時降雨機率');
  final description = _element(elementsByName, '天氣預報綜合描述');
  return [
    for (final start in weather.keys)
      HourlyForecast(
        startTime: start,
        temperature: _asNumber(temperature[start]?.value['Temperature'], '溫度@$start'),
        apparentTemperature: _asNumber(apparent[start]?.value['ApparentTemperature'], '體感溫度@$start'),
        humidity: _int(humidity[start]?.value['RelativeHumidity'], '相對濕度@$start'),
        windSpeed: _asNumber(windSpeed[start]?.value['WindSpeed'], '風速@$start'),
        windDirection: _text(windDirection[start]?.value['WindDirection']),
        pop: _int(pop[start]?.value['ProbabilityOfPrecipitation'], '3小時降雨機率@$start'),
        weather: _text(weather[start]!.value['Weather']),
        weatherCode: _text(weather[start]!.value['WeatherCode']),
        description: _text(description[start]?.value['WeatherDescription']),
      ),
  ];
}

/// 一週預報為 12 小時時段（白天 06–18、夜間 18–06）。
/// 單日最高／最低溫 = 該臺灣曆日所涉時段的最高／最低；其餘欄位取該日白天時段（今天只剩夜間時只取夜間）。
List<DailyForecast> _parseWeekly(Map<String, dynamic> body, String township) {
  final elementsByName = _parseElements(body, township);
  final maxT = _element(elementsByName, '最高溫度');
  final minT = _element(elementsByName, '最低溫度');
  final maxA = _element(elementsByName, '最高體感溫度');
  final minA = _element(elementsByName, '最低體感溫度');
  final humidity = _element(elementsByName, '平均相對濕度');
  final windSpeed = _element(elementsByName, '風速');
  final pop = _element(elementsByName, '12小時降雨機率');
  final weather = _element(elementsByName, '天氣現象');

  final slotsByDate = <String, List<DateTime>>{};
  for (final entry in maxT.entries) {
    final end = entry.value.end;
    if (end == null) throw FormatException('最高溫度@${entry.key}：缺少 EndTime');
    final startWall = entry.key.add(taiwanUtcOffset);
    final lastWall = end.add(taiwanUtcOffset).subtract(const Duration(microseconds: 1));
    for (var day = DateTime.utc(startWall.year, startWall.month, startWall.day);
        !day.isAfter(lastWall);
        day = day.add(const Duration(days: 1))) {
      slotsByDate.putIfAbsent(isoDate(day), () => []).add(entry.key);
    }
  }

  double? extreme(Map<DateTime, _Slot> element, String key, List<DateTime> starts, bool max) {
    final values = [
      for (final s in starts) _asNumber(element[s]?.value[key], '$key@$s'),
    ].whereType<double>();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => max ? math.max(a, b) : math.min(a, b));
  }

  final days = <DailyForecast>[];
  for (final entry in slotsByDate.entries.take(_weeklyDayCount)) {
    final starts = entry.value;
    final representativeStart = starts.firstWhere(
      (s) => s.add(taiwanUtcOffset).hour == _daySlotStartHour && isoDate(s.add(taiwanUtcOffset)) == entry.key,
      orElse: () => starts.first,
    );
    days.add(DailyForecast(
      date: entry.key,
      maxTemperature: extreme(maxT, 'MaxTemperature', starts, true),
      minTemperature: extreme(minT, 'MinTemperature', starts, false),
      maxApparentTemperature: extreme(maxA, 'MaxApparentTemperature', starts, true),
      minApparentTemperature: extreme(minA, 'MinApparentTemperature', starts, false),
      humidity: _int(humidity[representativeStart]?.value['RelativeHumidity'], '平均相對濕度@$representativeStart'),
      windSpeed: _asNumber(windSpeed[representativeStart]?.value['WindSpeed'], '風速@$representativeStart'),
      pop: _int(pop[representativeStart]?.value['ProbabilityOfPrecipitation'], '12小時降雨機率@$representativeStart'),
      weather: _text(weather[representativeStart]?.value['Weather']),
      weatherCode: _text(weather[representativeStart]?.value['WeatherCode']),
    ));
  }
  return days;
}

/// 日出日沒時刻字串「HH:mm」（臺灣時間）→ 絕對時刻
DateTime _sunTime(Object? raw, String date, String path) {
  final text = _text(raw);
  if (text == null || !_sunClockPattern.hasMatch(text)) {
    throw FormatException('$path@$date：期望「HH:mm」，實際「$raw」');
  }
  return DateTime.parse('${date}T$text:00$taiwanOffsetText');
}

List<SunDay> _parseSunTimes(Map<String, dynamic> body, String county, List<String> days) {
  final locations = _asList(_digPath(body, ['records', 'locations', 'location']), 'records.locations.location');
  final names = <String>[];
  for (final item in locations) {
    final locationJson = _asObject(item, 'location[]');
    final name = _text(locationJson['CountyName']) ?? '';
    names.add(name);
    if (name != county) continue;
    final byDate = {
      for (final t in _asList(locationJson['time'], '$name.time'))
        _text(_asObject(t, '$name.time[]')['Date']): _asObject(t, '$name.time[]'),
    };
    return [
      for (final date in days)
        _sunDay(
          byDate[date] ??
              (throw FormatException('期望 $name 有 $date 的資料，實際日期：${byDate.keys.join('、')}')),
          date,
        ),
    ];
  }
  throw FormatException(
    '期望縣市「$county」，實際 ${names.isEmpty ? '無任何縣市（若縣市名含「台」請改「臺」）' : names.join('、')}',
  );
}

/// 過中天仰角「47S」→ 47（N/S 只驗證格式）；格式不符即 FormatException。
int _transitAltitude(Object? raw, String date) {
  final match = _transitAltitudePattern.firstMatch(_text(raw) ?? '');
  if (match == null) throw FormatException('SunTransitAlt@$date：期望「度數+N/S」（如 47S），實際「$raw」');
  return int.parse(match.group(1)!);
}

SunDay _sunDay(Map<String, dynamic> day, String date) {
  final altitude = _transitAltitude(day['SunTransitAlt'], date);
  return SunDay(
      date: date,
      civilDawn: _sunTime(day['BeginCivilTwilightTime'], date, 'BeginCivilTwilightTime'),
      sunrise: _sunTime(day['SunRiseTime'], date, 'SunRiseTime'),
      sunset: _sunTime(day['SunSetTime'], date, 'SunSetTime'),
      civilDusk: _sunTime(day['EndCivilTwilightTime'], date, 'EndCivilTwilightTime'),
      transit: _sunTime(day['SunTransitTime'], date, 'SunTransitTime'),
      transitAltitudeDegrees: altitude,
    );
}
