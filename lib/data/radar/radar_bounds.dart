import 'dart:math';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'radar_frame_processor.dart';

/// Extent of the website `CV1_3600_` frames ([radarFrameWest] etc.). Same grid as open-data O-A0058-001
/// (pixel-identical image; graticule lines verified at whole degrees), see
/// docs/logs/2026-11-14/radar-impl-notes.md. The source image is linear in
/// latitude; the processor reprojects rows to Web Mercator ([radarFrameRowMap])
/// so this box can be used directly by flutter_map's `OverlayImage`.
final websiteRadarFrameBounds =
    LatLngBounds(const LatLng(radarFrameSouth, radarFrameWest), const LatLng(radarFrameNorth, radarFrameEast));

/// Processing of the website frames.
final websiteRadarGeometry = RadarImageGeometry(
  size: radarFrameSize,
  bounds: websiteRadarFrameBounds,
  rowMap: radarFrameRowMap,
  decorations: websiteFrameDecorations,
);

/// Processing of one station image covering [bounds]: rows kept as they are
/// (see [stationRadarBounds] for why there is no reprojection).
RadarImageGeometry stationRadarGeometry(LatLngBounds bounds) => RadarImageGeometry(
      size: radarFrameSize,
      bounds: bounds,
      rowMap: List<int>.generate(radarFrameSize, (i) => i),
      decorations: stationFrameDecorations,
    );

const _earthRadiusKm = 6371.0088;
final _radiusKmPattern = RegExp(r'(\d+(?:\.\d+)?)\s*公里');

/// One open-data station radar image (O-A0084-001..003). The composite
/// (全台) layer is not taken from open data: O-A0058-001 is pixel-identical to
/// the newest website frame, which is shown reprojected instead.
class OpenDataRadarImage {
  final String imageUrl;
  final LatLngBounds bounds;
  final DateTime time;

  const OpenDataRadarImage({required this.imageUrl, required this.bounds, required this.time});

  /// Parses a `fileapi/v1/opendataapi/<id>?format=JSON` response: corners from
  /// `StationLongitude`/`StationLatitude` and a radius such as 「距雷達150公里」.
  factory OpenDataRadarImage.fromJson(String datasetId, Map<String, dynamic> json) {
    Never fail(String what, Object? actual) =>
        throw FormatException('$datasetId: expected $what, got ${actual ?? 'nothing'}');

    final dataset = (json['cwaopendata'] as Map?)?['dataset'] as Map? ?? fail('cwaopendata.dataset', json.keys);
    final url = (dataset['resource'] as Map?)?['ProductURL'];
    if (url is! String || url.isEmpty) fail('resource.ProductURL', url);
    final time = DateTime.tryParse('${dataset['DateTime']}') ?? fail('DateTime (ISO 8601)', dataset['DateTime']);
    final params = (dataset['datasetInfo'] as Map?)?['parameterSet'] as Map? ??
        fail('datasetInfo.parameterSet', dataset['datasetInfo']);
    double number(String key) => double.tryParse('${params[key]}') ?? fail('numeric $key', params[key]);
    final radiusText = (params['parameter'] as Map?)?['parameterValue'];
    final radius = _radiusKmPattern.firstMatch('$radiusText') ??
        fail('parameter.parameterValue like 「距雷達150公里」', radiusText);
    return OpenDataRadarImage(
      imageUrl: url,
      time: time,
      bounds: stationRadarBounds(
        LatLng(number('StationLatitude'), number('StationLongitude')),
        radiusKm: double.parse(radius.group(1)!),
      ),
    );
  }
}

/// Square around a station radar whose half-side is [radiusKm] (the image's
/// range ring touches the image edges). ponytail: equirectangular offsets and
/// no row reprojection: CWA does not state the station image projection, and
/// the Mercator-vs-linear difference over ±150 km is ≤ 0.83 km (10 px of 3600),
/// so a reprojection could not be shown to be more correct. Revisit if CWA
/// publishes the projection.
LatLngBounds stationRadarBounds(LatLng centre, {required double radiusKm}) {
  final dLat = radiusKm / _earthRadiusKm * 180 / pi;
  final dLon = dLat / cos(centre.latitude * pi / 180);
  return LatLngBounds(
    LatLng(centre.latitude - dLat, centre.longitude - dLon),
    LatLng(centre.latitude + dLat, centre.longitude + dLon),
  );
}
