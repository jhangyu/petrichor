import 'dart:math';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
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
  palette: radarEchoPalette,
);

/// Processing of one station image covering [bounds]: rows kept as they are
/// (see [stationRadarBounds] for why there is no reprojection).
RadarImageGeometry stationRadarGeometry(LatLngBounds bounds) => RadarImageGeometry(
      size: radarFrameSize,
      bounds: bounds,
      rowMap: List<int>.generate(radarFrameSize, (i) => i),
      decorations: stationFrameDecorations,
      palette: radarEchoPalette,
    );

const _earthRadiusKm = 6371.0088;

/// A station radar: image-name code in the website station list, dataset id
/// (the app's source id) and site. Sites from CWA's station radar metadata
/// (StationLongitude/StationLatitude, 2026-11-15).
typedef RadarStation = ({String code, String datasetId, LatLng site});

const radarStations = <RadarStation>[
  (code: 'RCSL', datasetId: AppConstants.radarShulin, site: LatLng(25.00, 121.40)), // 樹林
  (code: 'RCNT', datasetId: AppConstants.radarNantun, site: LatLng(24.14, 120.58)), // 南屯
  (code: 'RCLY', datasetId: AppConstants.radarLinyuan, site: LatLng(22.53, 120.38)), // 林園
];

/// Website station images reach this far from the radar (their 「距雷達150公里」
/// ring); legend bar at x 3462-3525, y 2541-3572 (checked 2026-11-15).
const radarStationRangeKm = 150.0;

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
