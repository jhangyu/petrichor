import 'dart:math' as math;

import '../../core/time/taiwan_time.dart';

// ============================================================================
// JSON 邊界解析（錯誤一律為 FormatException，訊息含欄位路徑）
// ============================================================================

/// CWA 缺值標記（字串）
const String _missingMarker = '-99';

Map<String, dynamic> _map(Object? v, String path) {
  if (v is Map<String, dynamic>) return v;
  throw FormatException('expected object at $path, got ${v.runtimeType}');
}

List<dynamic> _list(Object? v, String path) {
  if (v is List<dynamic>) return v;
  throw FormatException('expected array at $path, got ${v.runtimeType}');
}

String _str(Object? v, String path) {
  if (v is String) return v;
  throw FormatException('expected string at $path, got ${v.runtimeType}');
}

/// 雨量字串；"-99" 與非數字（如微量 "T"）→ null（使用者裁決：只留數字值），非字串 → FormatException
double? _mm(Object? v, String path) {
  final s = _str(v, path);
  if (s == _missingMarker) return null;
  return double.tryParse(s);
}

double _num(Object? v, String path) {
  final s = _str(v, path);
  final n = double.tryParse(s);
  if (n == null) throw FormatException('expected number at $path, got "$s"');
  return n;
}

final _zonePattern = RegExp(r'[+-]\d\d:\d\d$');

/// "yyyy-MM-dd HH:mm:ss"（+08 本地）或 ISO 8601 → DateTime
DateTime _time(Object? v, String path) {
  final s = _str(v, path);
  final hasZone = s.endsWith('Z') || _zonePattern.hasMatch(s);
  final parsed = DateTime.tryParse(hasZone ? s : '${s.replaceFirst(' ', 'T')}$taiwanUtcOffsetText');
  if (parsed == null) throw FormatException('expected timestamp at $path, got "$s"');
  return parsed;
}

// ============================================================================
// 天氣特報（W-C0033-001 + W-C0033-002）
// ============================================================================

/// 單一縣市的一則生效特報（W-C0033-001），可附上對應公告（W-C0033-002）
class CountyWarning {
  final String phenomena;
  final String significance;
  final DateTime start;
  final DateTime end;

  /// 對應公告；兩資料集分開抓，找不到對應時為 null（不是錯誤）
  final WarningBulletin? bulletin;

  const CountyWarning({
    required this.phenomena,
    required this.significance,
    required this.start,
    required this.end,
    this.bulletin,
  });
}

/// 有生效特報的縣市
class CountyWarnings {
  final String county;
  final List<CountyWarning> warnings;
  const CountyWarnings({required this.county, required this.warnings});
}

/// 一則特報公告（W-C0033-002）
class WarningBulletin {
  /// 公告名稱，如「豪雨特報」
  final String title;
  final DateTime issueTime;

  /// CWA 最後更新此公告的時間（`datasetInfo.update`）
  final DateTime updatedAt;
  final DateTime start;
  final DateTime end;
  final String description;

  /// 公告涵蓋的縣市／區域名稱（可能含「恆春半島」等非縣市區域）
  final List<String> affectedAreas;

  const WarningBulletin({
    required this.title,
    required this.issueTime,
    required this.updatedAt,
    required this.start,
    required this.end,
    required this.description,
    required this.affectedAreas,
  });

  factory WarningBulletin.fromJson(Object? json, String path) {
    final m = _map(json, path);
    final info = _map(m['datasetInfo'], '$path.datasetInfo');
    final valid = _map(info['validTime'], '$path.datasetInfo.validTime');
    final hazards = _list(
      _map(_map(m['hazardConditions'], '$path.hazardConditions')['hazards'], '$path.hazardConditions.hazards')['hazard'],
      '$path.hazardConditions.hazards.hazard',
    );
    final areas = <String>[
      for (var i = 0; i < hazards.length; i++)
        for (final loc in _list(
          _map(_map(_map(hazards[i], '$path.hazard[$i]')['info'], '$path.hazard[$i].info')['affectedAreas'],
              '$path.hazard[$i].info.affectedAreas')['location'],
          '$path.hazard[$i].info.affectedAreas.location',
        ))
          _str(_map(loc, '$path.hazard[$i].location')['locationName'], '$path.hazard[$i].location.locationName'),
    ];
    final content = _map(_map(m['contents'], '$path.contents')['content'], '$path.contents.content');
    return WarningBulletin(
      title: _str(info['datasetDescription'], '$path.datasetInfo.datasetDescription'),
      issueTime: _time(info['issueTime'], '$path.datasetInfo.issueTime'),
      updatedAt: _time(info['update'], '$path.datasetInfo.update'),
      start: _time(valid['startTime'], '$path.datasetInfo.validTime.startTime'),
      end: _time(valid['endTime'], '$path.datasetInfo.validTime.endTime'),
      description: _str(content['contentText'], '$path.contents.content.contentText').trim(),
      affectedAreas: areas,
    );
  }
}

/// 目前生效的特報。[counties] 為空是合法結果（無生效特報）。
class ActiveWarnings {
  final List<CountyWarnings> counties;
  final List<WarningBulletin> bulletins;

  /// App 取得此資料的時刻（W-C0033-001 的 datastore 回應不含發布時間）
  final DateTime fetchedAt;
  const ActiveWarnings({required this.counties, required this.bulletins, required this.fetchedAt});

  /// 公告中最新的 CWA 更新時間；無公告（無生效特報）為 null
  DateTime? get updatedAt {
    if (bulletins.isEmpty) return null;
    return bulletins.map((b) => b.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// 解析 W-C0033-001（[warningsByCountyRecords] = `records`）；缺 `location` 陣列視為格式錯誤，
  /// 因為此資料集無特報時仍列出全部縣市（hazards 為空陣列）。
  /// [bulletins] 為已解析的 W-C0033-002 公告。
  factory ActiveWarnings.fromJson(Object? warningsByCountyRecords, List<WarningBulletin> bulletins, DateTime fetchedAt) {
    final locations = _list(_map(warningsByCountyRecords, 'records')['location'], 'records.location');
    final counties = <CountyWarnings>[];
    for (var i = 0; i < locations.length; i++) {
      final p = 'records.location[$i]';
      final loc = _map(locations[i], p);
      final name = _str(loc['locationName'], '$p.locationName');
      final hazards = _list(_map(loc['hazardConditions'], '$p.hazardConditions')['hazards'], '$p.hazardConditions.hazards');
      if (hazards.isEmpty) continue;
      final warnings = <CountyWarning>[];
      for (var j = 0; j < hazards.length; j++) {
        final hp = '$p.hazards[$j]';
        final h = _map(hazards[j], hp);
        final info = _map(h['info'], '$hp.info');
        final valid = _map(h['validTime'], '$hp.validTime');
        final start = _time(valid['startTime'], '$hp.validTime.startTime');
        final end = _time(valid['endTime'], '$hp.validTime.endTime');
        warnings.add(CountyWarning(
          phenomena: _str(info['phenomena'], '$hp.info.phenomena'),
          significance: _str(info['significance'], '$hp.info.significance'),
          start: start,
          end: end,
          bulletin: _matchBulletin(bulletins, name, start, end),
        ));
      }
      counties.add(CountyWarnings(county: name, warnings: warnings));
    }
    return ActiveWarnings(counties: counties, bulletins: bulletins, fetchedAt: fetchedAt);
  }

  /// 以「縣市在公告區域內＋有效期間完全相同」配對。
  /// 不比對現象名稱：-001 把「大雨」標為「豪雨」，-002 標為「大雨」。
  static WarningBulletin? _matchBulletin(List<WarningBulletin> bulletins, String county, DateTime start, DateTime end) {
    for (final b in bulletins) {
      if (b.affectedAreas.contains(county) && b.start == start && b.end == end) return b;
    }
    return null;
  }
}

// ============================================================================
// 雨量觀測（O-A0002-001）
// ============================================================================

/// 雨量站：今日累積雨量 [todayMillimeters]、近 1／3 小時 [past1HourMillimeters]／[past3HoursMillimeters]（null = 缺值或非數字）
class RainStation {
  final String id;
  final String name;
  final String county;
  final String town;
  final double latitude;
  final double longitude;
  final double? todayMillimeters;
  final double? past1HourMillimeters;
  final double? past3HoursMillimeters;

  /// 近 10 分鐘雨量（`Past10Min`）
  final double? past10MinutesMillimeters;
  final DateTime obsTime;

  const RainStation({
    required this.id,
    required this.name,
    required this.county,
    required this.town,
    required this.latitude,
    required this.longitude,
    required this.todayMillimeters,
    this.past1HourMillimeters,
    this.past3HoursMillimeters,
    this.past10MinutesMillimeters,
    required this.obsTime,
  });

  factory RainStation.fromJson(Object? json, String path) {
    final m = _map(json, path);
    final geo = _map(m['GeoInfo'], '$path.GeoInfo');
    final coords = _list(geo['Coordinates'], '$path.GeoInfo.Coordinates');
    final wgs84 = coords.map((c) => _map(c, '$path.GeoInfo.Coordinates[]')).where((c) => c['CoordinateName'] == 'WGS84');
    if (wgs84.isEmpty) throw FormatException('no WGS84 coordinate at $path.GeoInfo.Coordinates');
    final c = wgs84.first;
    final element = _map(m['RainfallElement'], '$path.RainfallElement');
    double? precipitation(String key) {
      final p = '$path.RainfallElement.$key';
      return _mm(_map(element[key], p)['Precipitation'], '$p.Precipitation');
    }

    return RainStation(
      id: _str(m['StationId'], '$path.StationId'),
      name: _str(m['StationName'], '$path.StationName'),
      county: _str(geo['CountyName'], '$path.GeoInfo.CountyName'),
      town: _str(geo['TownName'], '$path.GeoInfo.TownName'),
      latitude: _num(c['StationLatitude'], '$path.WGS84.StationLatitude'),
      longitude: _num(c['StationLongitude'], '$path.WGS84.StationLongitude'),
      todayMillimeters: precipitation('Now'),
      past1HourMillimeters: precipitation('Past1hr'),
      past3HoursMillimeters: precipitation('Past3hr'),
      past10MinutesMillimeters: precipitation('Past10Min'),
      obsTime: _time(_map(m['ObsTime'], '$path.ObsTime')['DateTime'], '$path.ObsTime.DateTime'),
    );
  }

  /// 與 (latitude, longitude) 的等距矩形近似距離平方（度²，經度已乘 cos 緯度）
  double squaredDistanceTo(double latitude, double longitude) {
    final dLat = this.latitude - latitude;
    final dLon = (this.longitude - longitude) * math.cos(latitude * math.pi / 180);
    return dLat * dLat + dLon * dLon;
  }
}

/// 某縣市的雨量觀測：該縣市所有雨量站與最近的有值測站，另附全臺測站供切換縣市
class CountyRainfall {
  final String county;
  final List<RainStation> stations;

  /// 資料集內全部測站（所有縣市）
  final List<RainStation> allStations;

  /// 離使用者最近且今日累積有值的測站
  final RainStation nearest;

  const CountyRainfall({required this.county, required this.stations, required this.allStations, required this.nearest});
}

/// 解析 O-A0002-001 的 `records.Station[]` 全部測站
List<RainStation> parseRainStations(Object? records) {
  final stations = _list(_map(records, 'records')['Station'], 'records.Station');
  return [for (var i = 0; i < stations.length; i++) RainStation.fromJson(stations[i], 'records.Station[$i]')];
}

// ============================================================================
// 1 小時雨量預測格點（F-B0046-001）
// ============================================================================

/// 格點資料。排列：左下角 (startLongitude, startLatitude) 為第 0 點，
/// 先經向遞增（x 最快），再緯向遞增；index = y * columns + x。
/// 值為 mm，null = 無效值（-99，雷達無回波覆蓋或無資料）。
class RainForecastGrid {
  /// 預報起算時間（`parameterSet.DateTime`）
  final DateTime baseTime;

  /// CWA 發布時間（回應 `sent`），晚於 [baseTime]
  final DateTime issuedAt;
  final double startLongitude;
  final double startLatitude;

  /// 格距（度）
  final double resolution;
  final int columns;
  final int rows;
  final List<double?> values;

  RainForecastGrid({
    required this.baseTime,
    required this.issuedAt,
    required this.startLongitude,
    required this.startLatitude,
    required this.resolution,
    required this.columns,
    required this.rows,
    required this.values,
  }) {
    if (values.length != columns * rows) {
      throw FormatException('grid value count ${values.length} != columns*rows ${columns * rows}');
    }
  }

  /// [root] = fileapi 回應的 `cwaopendata`
  factory RainForecastGrid.fromJson(Object? root) {
    const base = 'cwaopendata.dataset';
    final ds = _map(_map(root, 'cwaopendata')['dataset'], base);
    final ps = _map(_map(ds['datasetInfo'], '$base.datasetInfo')['parameterSet'], '$base.datasetInfo.parameterSet');
    const pp = '$base.datasetInfo.parameterSet';
    final raw = _str(_map(ds['contents'], '$base.contents')['content'], '$base.contents.content');
    final values = [for (final s in raw.split(',')) _gridValue(s.trim())];
    return RainForecastGrid(
      baseTime: _time(ps['DateTime'], '$pp.DateTime'),
      issuedAt: _time(_map(root, 'cwaopendata')['sent'], 'cwaopendata.sent'),
      startLongitude: _num(ps['StartPointLongitude'], '$pp.StartPointLongitude'),
      startLatitude: _num(ps['StartPointLatitude'], '$pp.StartPointLatitude'),
      resolution: _num(ps['GridResolution'], '$pp.GridResolution'),
      columns: _num(ps['GridDimensionX'], '$pp.GridDimensionX').toInt(),
      rows: _num(ps['GridDimensionY'], '$pp.GridDimensionY').toInt(),
      values: values,
    );
  }

  static double? _gridValue(String s) {
    final n = double.tryParse(s);
    if (n == null) throw FormatException('expected scientific-notation number in grid, got "$s"');
    return n == double.parse(_missingMarker) ? null : n;
  }

  /// 座標是否落在格點範圍內
  bool contains(double latitude, double longitude) {
    final x = _cell(longitude, startLongitude);
    final y = _cell(latitude, startLatitude);
    return x >= 0 && x < columns && y >= 0 && y < rows;
  }

  /// 最近格點的預測雨量 mm；null = 該格無效。呼叫前須 [contains] 為 true。
  double? valueAt(double latitude, double longitude) {
    if (!contains(latitude, longitude)) {
      throw RangeError('($latitude, $longitude) outside grid lon $startLongitude+$columns*$resolution, lat $startLatitude+$rows*$resolution');
    }
    return values[_cell(latitude, startLatitude) * columns + _cell(longitude, startLongitude)];
  }

  int _cell(double coord, double start) => ((coord - start) / resolution).round();
}

/// 使用者位置的 1 小時雨量預測，附整張格點供繪圖
class RainForecast {
  final RainForecastGrid grid;

  /// 使用者所在格的預測 mm；null = 該格無效值
  final double? millimetersAtLocation;

  const RainForecast({required this.grid, required this.millimetersAtLocation});
}
