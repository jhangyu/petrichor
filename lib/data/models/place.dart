import '../../core/constants/cwa_names.dart';
import '../../core/location/location_service.dart';

/// 一個鄉鎮地點：縣市＋鄉鎮名（CWA 寫法，用「臺」）與經緯度。
class Place {
  final String county;
  final String town;
  final double latitude;
  final double longitude;

  const Place({
    required this.county,
    required this.town,
    required this.latitude,
    required this.longitude,
  });

  /// 由 GPS 定位結果建立（縣市／鄉鎮名正規化成「臺」）。
  factory Place.fromLocation(LocationData location) => Place(
        county: normalizeCwaName(location.city),
        town: normalizeCwaName(location.district),
        latitude: location.latitude,
        longitude: location.longitude,
      );

  /// 本機儲存格式 → Place；欄位缺漏或型別不符丟 [FormatException]（[path] 標出位置）。
  factory Place.fromJson(Object? json, String path) {
    if (json is! Map<String, dynamic>) {
      throw FormatException('$path：期望物件，實際 ${json.runtimeType}');
    }
    String text(String key) => json[key] is String && (json[key] as String).isNotEmpty
        ? json[key] as String
        : throw FormatException('$path.$key：期望非空字串，實際「${json[key]}」');
    double number(String key) =>
        json[key] is num ? (json[key] as num).toDouble() : throw FormatException('$path.$key：期望數字，實際「${json[key]}」');
    return Place(
      county: text('county'),
      town: text('town'),
      latitude: number('latitude'),
      longitude: number('longitude'),
    );
  }

  Map<String, Object> toJson() => {
        'county': county,
        'town': town,
        'latitude': latitude,
        'longitude': longitude,
      };

  /// Stable identity of the area, e.g. '臺北市/中正區' (names normalized to 「臺」).
  String get areaKey => '$county/$town';

  /// 顯示名，如「臺北市中正區」
  String get name => '$county$town';

  /// 雨量／警特報頁用的位置（與 hazard_provider.dart 的 HazardLocation 同型）
  ({String county, double latitude, double longitude}) get hazardLocation =>
      (county: county, latitude: latitude, longitude: longitude);

  /// WeatherRepository 查詢用
  LocationData toLocationData() =>
      LocationData(latitude: latitude, longitude: longitude, city: county, district: town);

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.county == county &&
      other.town == town &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(county, town, latitude, longitude);

  @override
  String toString() => 'Place($name, $latitude, $longitude)';
}
