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

Map<String, dynamic> _obj(Object? v, String path) {
  if (v is Map<String, dynamic>) return v;
  throw FormatException('$path：期望物件，實際 ${v.runtimeType}');
}

List<Object?> _list(Object? v, String path) {
  if (v is List<Object?>) return v;
  throw FormatException('$path：期望陣列，實際 ${v.runtimeType}');
}

/// 沿路徑取值；中途缺少即回 null（欄位可選）。
Object? _dig(Map<String, dynamic> m, List<String> path) {
  Object? cur = m;
  for (final key in path) {
    if (cur is! Map<String, dynamic>) return null;
    cur = cur[key];
  }
  return cur;
}

/// `records.Station`, at least one station.
List<Object?> _stationList(Map<String, dynamic> body) {
  final stations = _list(_dig(body, ['records', 'Station']), 'records.Station');
  if (stations.isEmpty) throw const FormatException('records.Station：期望至少 1 站，實際 0 站');
  return stations;
}

/// `records.Locations[0]`, which must exist.
Map<String, dynamic> _firstLocationGroup(Map<String, dynamic> body) {
  final groups = _list(_dig(body, ['records', 'Locations']), 'records.Locations');
  if (groups.isEmpty) throw const FormatException('records.Locations：期望 1 組，實際 0 組');
  return _obj(groups.first, 'records.Locations[0]');
}

/// CWA 以「-」表示該時間槽無值（例如 12 小時降雨機率）。
const _noValueMarker = '-';

/// 數值字串 → double；缺值（null、-99、「-」）→ null；其他非數字 → FormatException。
double? _num(Object? raw, String path) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text == _noValueMarker) return null;
  final value = double.tryParse(text);
  if (value == null) throw FormatException('$path：期望數字，實際「$text」');
  return value == _missingValue ? null : value;
}

int? _int(Object? raw, String path) => _num(raw, path)?.round();

/// 文字欄位；缺值（null、-99、空字串）→ null。
String? _text(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  return (text.isEmpty || text == _missingText) ? null : text;
}

DateTime _time(Object? raw, String path) {
  if (raw is! String) throw FormatException('$path：期望時間字串，實際 ${raw.runtimeType}');
  return DateTime.parse(raw);
}

double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * AppConstants.earthRadiusKm * math.asin(math.sqrt(a));
}

CurrentWeather _parseObservation(Map<String, dynamic> body, double lat, double lon) {
  final stations = _stationList(body);

  Map<String, dynamic>? best;
  double bestKm = double.infinity;
  for (var i = 0; i < stations.length; i++) {
    final path = 'records.Station[$i]';
    final station = _obj(stations[i], path);
    final temp = _num(_dig(station, ['WeatherElement', 'AirTemperature']), '$path.AirTemperature');
    if (temp == null) continue;
    final (sLat, sLon) = _wgs84Of(station, path);
    final km = _distanceKm(lat, lon, sLat, sLon);
    if (km < bestKm) {
      bestKm = km;
      best = station;
    }
  }
  if (best == null) {
    throw FormatException('期望至少 1 站有氣溫讀數，實際 ${stations.length} 站皆缺氣溫');
  }

  final we = _obj(best['WeatherElement'], 'WeatherElement');
  return CurrentWeather(
    stationName: _text(best['StationName']) ?? '',
    countyName: _text(_dig(best, ['GeoInfo', 'CountyName'])) ?? '',
    townName: _text(_dig(best, ['GeoInfo', 'TownName'])) ?? '',
    observedAt: _time(_dig(best, ['ObsTime', 'DateTime']), 'ObsTime.DateTime'),
    temperature: _num(we['AirTemperature'], 'AirTemperature')!,
    humidity: _int(we['RelativeHumidity'], 'RelativeHumidity'),
    windSpeed: _num(we['WindSpeed'], 'WindSpeed'),
    windDirection: _observedWind(we['WindDirection']),
    weather: _text(we['Weather']),
    dailyHigh: _num(
      _dig(we, ['DailyExtreme', 'DailyHigh', 'TemperatureInfo', 'AirTemperature']),
      'DailyHigh',
    ),
    dailyLow: _num(
      _dig(we, ['DailyExtreme', 'DailyLow', 'TemperatureInfo', 'AirTemperature']),
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
List<_StationCounty> _parseStationCounties(Map<String, dynamic> body, double lat, double lon) {
  final stations = _stationList(body);
  return [
    for (var i = 0; i < stations.length; i++)
      _stationCounty(_obj(stations[i], 'records.Station[$i]'), lat, lon, 'records.Station[$i]'),
  ]..sort((a, b) => a.km.compareTo(b.km));
}

_StationCounty _stationCounty(Map<String, dynamic> station, double lat, double lon, String path) {
  final county = _text(_dig(station, ['GeoInfo', 'CountyName'])) ??
      (throw FormatException('$path.GeoInfo.CountyName：期望縣市名，實際缺值'));
  final (sLat, sLon) = _wgs84Of(station, path);
  return _StationCounty(normalizeCwaName(county), _distanceKm(lat, lon, sLat, sLon));
}

(double, double) _wgs84Of(Map<String, dynamic> station, String path) {
  final coords = _list(_dig(station, ['GeoInfo', 'Coordinates']), '$path.GeoInfo.Coordinates')
      .map((c) => _obj(c, '$path.GeoInfo.Coordinates[]'))
      .firstWhere(
        (c) => c['CoordinateName'] == _wgs84,
        orElse: () => throw FormatException('$path：缺少 $_wgs84 座標'),
      );
  return (
    _num(coords['StationLatitude'], '$path.StationLatitude') ??
        (throw FormatException('$path.StationLatitude：期望緯度，實際缺值')),
    _num(coords['StationLongitude'], '$path.StationLongitude') ??
        (throw FormatException('$path.StationLongitude：期望經度，實際缺值')),
  );
}

Place _nearestPlace(List<Place> places, double lat, double lon) => places.reduce((a, b) =>
    _distanceKm(lat, lon, a.latitude, a.longitude) <= _distanceKm(lat, lon, b.latitude, b.longitude) ? a : b);

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
  return _time(match.group(1), 'DatasetInfo.IssueTime');
}

/// 觀測風向的特殊值（度）：0＝靜風，990＝風向不定；其餘 1–360 為方位角（360＝北）。
const double _calmWindDegrees = 0;
const double _variableWindDegrees = 990;
const double _fullCircleDegrees = 360;

/// 觀測風向（度，字串）→ [ObservedWind]；缺值 → null；範圍外 → FormatException。
ObservedWind? _observedWind(Object? raw) {
  final deg = _num(raw, 'WindDirection');
  if (deg == null) return null;
  if (deg == _calmWindDegrees) return const ObservedWind.calm();
  if (deg == _variableWindDegrees) return const ObservedWind.variable();
  if (deg < 0 || deg > _fullCircleDegrees) {
    throw FormatException(
      'WindDirection：期望 0（靜風）、1–360 度或 990（風向不定），實際「$raw」',
    );
  }
  return ObservedWind.degrees(deg);
}

List<Place> _parseTowns(Map<String, dynamic> body, String county) {
  final group = _firstLocationGroup(body);
  final actual = normalizeCwaName(_text(group['LocationsName']) ?? '');
  if (actual != county) throw FormatException('LocationsName：期望「$county」，實際「$actual」');
  final list = _list(group['Location'], 'Location');
  if (list.isEmpty) throw FormatException('$county Location：期望至少 1 個鄉鎮，實際 0 個');
  return [
    for (var i = 0; i < list.length; i++)
      _town(_obj(list[i], 'Location[$i]'), county, 'Location[$i]'),
  ];
}

Place _town(Map<String, dynamic> loc, String county, String path) {
  final town = _text(loc['LocationName']) ?? (throw FormatException('$path.LocationName：期望鄉鎮名，實際「${loc['LocationName']}」'));
  return Place(
    county: county,
    town: normalizeCwaName(town),
    latitude: _num(loc['Latitude'], '$path.Latitude') ?? (throw FormatException('$path.Latitude：期望緯度，實際缺值')),
    longitude: _num(loc['Longitude'], '$path.Longitude') ?? (throw FormatException('$path.Longitude：期望經度，實際缺值')),
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
  final list = _list(_firstLocationGroup(body)['Location'], 'Location');
  final names = <String>[];
  for (final item in list) {
    final loc = _obj(item, 'Location[]');
    final name = _text(loc['LocationName']) ?? '';
    names.add(name);
    if (name != township) continue;
    final elements = <String, Map<DateTime, _Slot>>{};
    for (final e in _list(loc['WeatherElement'], '$name.WeatherElement')) {
      final em = _obj(e, '$name.WeatherElement[]');
      final elementName = _text(em['ElementName']) ?? '';
      final slots = <DateTime, _Slot>{};
      for (final t in _list(em['Time'], '$elementName.Time')) {
        final tm = _obj(t, '$elementName.Time[]');
        final rawStart = tm['StartTime'] ?? tm['DataTime'];
        final rawEnd = tm['EndTime'];
        final values = _list(tm['ElementValue'], '$elementName.ElementValue');
        if (values.isEmpty) throw FormatException('$elementName：ElementValue 為空');
        slots[_time(rawStart, '$elementName.StartTime')] = _Slot(
          rawEnd == null ? null : _time(rawEnd, '$elementName.EndTime'),
          _obj(values.first, '$elementName.ElementValue[0]'),
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
  final els = _parseElements(body, township);
  final weather = _element(els, '天氣現象');
  final temperature = _element(els, '溫度');
  final apparent = _element(els, '體感溫度');
  final humidity = _element(els, '相對濕度');
  final windSpeed = _element(els, '風速');
  final windDirection = _element(els, '風向');
  final pop = _element(els, '3小時降雨機率');
  final description = _element(els, '天氣預報綜合描述');
  return [
    for (final start in weather.keys)
      HourlyForecast(
        startTime: start,
        temperature: _num(temperature[start]?.value['Temperature'], '溫度@$start'),
        apparentTemperature: _num(apparent[start]?.value['ApparentTemperature'], '體感溫度@$start'),
        humidity: _int(humidity[start]?.value['RelativeHumidity'], '相對濕度@$start'),
        windSpeed: _num(windSpeed[start]?.value['WindSpeed'], '風速@$start'),
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
  final els = _parseElements(body, township);
  final maxT = _element(els, '最高溫度');
  final minT = _element(els, '最低溫度');
  final maxA = _element(els, '最高體感溫度');
  final minA = _element(els, '最低體感溫度');
  final humidity = _element(els, '平均相對濕度');
  final windSpeed = _element(els, '風速');
  final pop = _element(els, '12小時降雨機率');
  final weather = _element(els, '天氣現象');

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
      for (final s in starts) _num(element[s]?.value[key], '$key@$s'),
    ].whereType<double>();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => max ? math.max(a, b) : math.min(a, b));
  }

  final days = <DailyForecast>[];
  for (final entry in slotsByDate.entries.take(_weeklyDayCount)) {
    final starts = entry.value;
    final rep = starts.firstWhere(
      (s) => s.add(taiwanUtcOffset).hour == _daySlotStartHour && isoDate(s.add(taiwanUtcOffset)) == entry.key,
      orElse: () => starts.first,
    );
    days.add(DailyForecast(
      date: entry.key,
      maxTemperature: extreme(maxT, 'MaxTemperature', starts, true),
      minTemperature: extreme(minT, 'MinTemperature', starts, false),
      maxApparentTemperature: extreme(maxA, 'MaxApparentTemperature', starts, true),
      minApparentTemperature: extreme(minA, 'MinApparentTemperature', starts, false),
      humidity: _int(humidity[rep]?.value['RelativeHumidity'], '平均相對濕度@$rep'),
      windSpeed: _num(windSpeed[rep]?.value['WindSpeed'], '風速@$rep'),
      pop: _int(pop[rep]?.value['ProbabilityOfPrecipitation'], '12小時降雨機率@$rep'),
      weather: _text(weather[rep]?.value['Weather']),
      weatherCode: _text(weather[rep]?.value['WeatherCode']),
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
  return DateTime.parse('${date}T$text:00+08:00');
}

List<SunDay> _parseSunTimes(Map<String, dynamic> body, String county, List<String> days) {
  final locations = _list(_dig(body, ['records', 'locations', 'location']), 'records.locations.location');
  final names = <String>[];
  for (final item in locations) {
    final loc = _obj(item, 'location[]');
    final name = _text(loc['CountyName']) ?? '';
    names.add(name);
    if (name != county) continue;
    final byDate = {
      for (final t in _list(loc['time'], '$name.time'))
        _text(_obj(t, '$name.time[]')['Date']): _obj(t, '$name.time[]'),
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
