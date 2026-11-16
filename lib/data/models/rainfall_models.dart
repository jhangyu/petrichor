part of 'hazard_models.dart';

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
  final DateTime observedAt;

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
    required this.observedAt,
  });

  factory RainStation.fromJson(Object? json, String path) {
    final m = _asObject(json, path);
    final geo = _asObject(m['GeoInfo'], '$path.GeoInfo');
    final coords = _asList(geo['Coordinates'], '$path.GeoInfo.Coordinates');
    final wgs84 = coords.map((c) => _asObject(c, '$path.GeoInfo.Coordinates[]')).where((c) => c['CoordinateName'] == 'WGS84');
    if (wgs84.isEmpty) throw FormatException('no WGS84 coordinate at $path.GeoInfo.Coordinates');
    final c = wgs84.first;
    final element = _asObject(m['RainfallElement'], '$path.RainfallElement');
    double? precipitation(String key) {
      final p = '$path.RainfallElement.$key';
      return _rainMillimeters(_asObject(element[key], p)['Precipitation'], '$p.Precipitation');
    }

    return RainStation(
      id: _asString(m['StationId'], '$path.StationId'),
      name: _asString(m['StationName'], '$path.StationName'),
      county: _asString(geo['CountyName'], '$path.GeoInfo.CountyName'),
      town: _asString(geo['TownName'], '$path.GeoInfo.TownName'),
      latitude: _asNumber(c['StationLatitude'], '$path.WGS84.StationLatitude'),
      longitude: _asNumber(c['StationLongitude'], '$path.WGS84.StationLongitude'),
      todayMillimeters: precipitation('Now'),
      past1HourMillimeters: precipitation('Past1hr'),
      past3HoursMillimeters: precipitation('Past3hr'),
      past10MinutesMillimeters: precipitation('Past10Min'),
      observedAt: _asInstant(_asObject(m['ObsTime'], '$path.ObsTime')['DateTime'], '$path.ObsTime.DateTime'),
    );
  }

  /// 與 (latitude, longitude) 的等距矩形近似距離平方（度²，經度已乘 cos 緯度）
  double squaredDistanceTo(double latitude, double longitude) {
    final latitudeDelta = this.latitude - latitude;
    final longitudeDelta = (this.longitude - longitude) * math.cos(latitude * math.pi / 180);
    return latitudeDelta * latitudeDelta + longitudeDelta * longitudeDelta;
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
  final stations = _asList(_asObject(records, 'records')['Station'], 'records.Station');
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
    final dataset = _asObject(_asObject(root, 'cwaopendata')['dataset'], base);
    final parameterSet = _asObject(_asObject(dataset['datasetInfo'], '$base.datasetInfo')['parameterSet'], '$base.datasetInfo.parameterSet');
    const parameterSetPath = '$base.datasetInfo.parameterSet';
    final raw = _asString(_asObject(dataset['contents'], '$base.contents')['content'], '$base.contents.content');
    final values = [for (final s in raw.split(',')) _gridValue(s.trim())];
    return RainForecastGrid(
      baseTime: _asInstant(parameterSet['DateTime'], '$parameterSetPath.DateTime'),
      issuedAt: _asInstant(_asObject(root, 'cwaopendata')['sent'], 'cwaopendata.sent'),
      startLongitude: _asNumber(parameterSet['StartPointLongitude'], '$parameterSetPath.StartPointLongitude'),
      startLatitude: _asNumber(parameterSet['StartPointLatitude'], '$parameterSetPath.StartPointLatitude'),
      resolution: _asNumber(parameterSet['GridResolution'], '$parameterSetPath.GridResolution'),
      columns: _asNumber(parameterSet['GridDimensionX'], '$parameterSetPath.GridDimensionX').toInt(),
      rows: _asNumber(parameterSet['GridDimensionY'], '$parameterSetPath.GridDimensionY').toInt(),
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
