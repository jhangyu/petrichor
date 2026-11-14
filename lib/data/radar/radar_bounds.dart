import 'dart:math';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Extent of the website `CV1_3600_` frames. Same grid as open-data O-A0058-001
/// (pixel-identical image; graticule lines verified at whole degrees), see
/// docs/logs/2026-11-14/radar-impl-notes.md. The source image is linear in
/// latitude; the processor reprojects rows to Web Mercator so this box can be
/// used directly by flutter_map's `OverlayImage`.
final websiteRadarBounds = LatLngBounds(const LatLng(17.75, 115.0), const LatLng(29.25, 126.5));

const _earthRadiusKm = 6371.0088;
final _rangePattern = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*-\s*(-?\d+(?:\.\d+)?)\s*$');
final _radiusKmPattern = RegExp(r'(\d+(?:\.\d+)?)\s*公里');

/// One open-data radar image (O-A0058-00x composite or O-A0084-00x station).
class OpenDataRadarImage {
  final String imageUrl;
  final LatLngBounds bounds;
  final DateTime time;

  const OpenDataRadarImage({required this.imageUrl, required this.bounds, required this.time});

  /// Parses a `fileapi/v1/opendataapi/<id>?format=JSON` response.
  ///
  /// Composite products state `LongitudeRange`/`LatitudeRange`; station products
  /// state `StationLongitude`/`StationLatitude` and a radius such as
  /// 「距雷達150公里」, from which the corners are computed.
  factory OpenDataRadarImage.fromJson(String datasetId, Map<String, dynamic> json) {
    Never fail(String what, Object? actual) =>
        throw FormatException('$datasetId: expected $what, got ${actual ?? 'nothing'}');

    final dataset = (json['cwaopendata'] as Map?)?['dataset'] as Map? ?? fail('cwaopendata.dataset', json.keys);
    final url = (dataset['resource'] as Map?)?['ProductURL'];
    if (url is! String || url.isEmpty) fail('resource.ProductURL', url);
    final time = DateTime.tryParse('${dataset['DateTime']}') ?? fail('DateTime (ISO 8601)', dataset['DateTime']);
    final params = (dataset['datasetInfo'] as Map?)?['parameterSet'] as Map? ??
        fail('datasetInfo.parameterSet', dataset['datasetInfo']);

    LatLngBounds bounds;
    if (params.containsKey('LongitudeRange')) {
      (double, double) range(String key) {
        final m = _rangePattern.firstMatch('${params[key]}') ?? fail('$key as "<from>-<to>"', params[key]);
        return (double.parse(m.group(1)!), double.parse(m.group(2)!));
      }

      final (west, east) = range('LongitudeRange');
      final (south, north) = range('LatitudeRange');
      bounds = LatLngBounds(LatLng(south, west), LatLng(north, east));
    } else {
      double number(String key) => double.tryParse('${params[key]}') ?? fail('numeric $key', params[key]);
      final radiusText = (params['parameter'] as Map?)?['parameterValue'];
      final radius = _radiusKmPattern.firstMatch('$radiusText') ?? fail('parameter.parameterValue like 「距雷達150公里」', radiusText);
      bounds = stationRadarBounds(
        LatLng(number('StationLatitude'), number('StationLongitude')),
        radiusKm: double.parse(radius.group(1)!),
      );
    }
    return OpenDataRadarImage(imageUrl: url, bounds: bounds, time: time);
  }
}

/// Square around a station radar whose half-side is [radiusKm] (the image's
/// range ring touches the image edges). ponytail: equirectangular offsets; the
/// station image projection is not stated by CWA, so edge placement can be off
/// by about 1 km — reproject per pixel if a projection spec appears.
LatLngBounds stationRadarBounds(LatLng centre, {required double radiusKm}) {
  final dLat = radiusKm / _earthRadiusKm * 180 / pi;
  final dLon = dLat / cos(centre.latitude * pi / 180);
  return LatLngBounds(
    LatLng(centre.latitude - dLat, centre.longitude - dLon),
    LatLng(centre.latitude + dLat, centre.longitude + dLon),
  );
}
