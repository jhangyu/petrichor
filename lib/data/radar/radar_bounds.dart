import 'dart:math';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/cwa_datasets.dart';
import '../../core/geography/earth.dart';
import 'radar_frame_processor.dart';

const radarFrameSize = 3600;

/// Decorations of the 3600 frame drawn in legend colours (measured on real frames).
const _websiteFrameDecorations = <PixelRect>[
  (left: 3419, top: 2507, right: 3488, bottom: 3572), // dBZ colour bar
  (left: 97, top: 223, right: 146, bottom: 718), // radar station status dots
];

/// Decorations of the website station frames drawn in legend colours: only
/// the dBZ colour bar (identical on all three stations, 66 x 1032 px; no other
/// legend-colour pixels outside the 150 km circle, measured 2026-11-14).
const _stationFrameDecorations = <PixelRect>[
  (left: 3461, top: 2541, right: 3527, bottom: 3573),
];

/// Extent of the 3600 frame (see [websiteRadarFrameBounds]).
const _radarFrameSouth = 17.75;
const _radarFrameNorth = 29.25;
const _radarFrameWest = 115.0;
const _radarFrameEast = 126.5;

/// Mercator row map of the 3600 frame (3748 output rows).
final _radarFrameRowMap = mercatorRowMap(sourceHeight: radarFrameSize, south: _radarFrameSouth, north: _radarFrameNorth);

/// Extent of the website `CV1_3600_` frames ([_radarFrameWest] etc.). Same grid as open-data O-A0058-001
/// (pixel-identical image; graticule lines verified at whole degrees), see
/// docs/logs/2026-11-14/radar-impl-notes.md. The source image is linear in
/// latitude; the processor reprojects rows to Web Mercator ([_radarFrameRowMap])
/// so this box can be used directly by flutter_map's `OverlayImage`.
final websiteRadarFrameBounds =
    LatLngBounds(const LatLng(_radarFrameSouth, _radarFrameWest), const LatLng(_radarFrameNorth, _radarFrameEast));

/// Processing of the website frames.
final websiteRadarGeometry = RadarImageGeometry(
  size: radarFrameSize,
  bounds: websiteRadarFrameBounds,
  rowMap: _radarFrameRowMap,
  decorations: _websiteFrameDecorations,
);

/// Processing of one station image covering [bounds]: rows kept as they are
/// (see [stationRadarBounds] for why there is no reprojection).
RadarImageGeometry stationRadarGeometry(LatLngBounds bounds) => RadarImageGeometry(
      size: radarFrameSize,
      bounds: bounds,
      rowMap: List<int>.generate(radarFrameSize, (i) => i),
      decorations: _stationFrameDecorations,
    );

/// A station radar: image-name code in the website station list, dataset id
/// (the app's source id), display name and site. Sites from CWA's station radar metadata
/// (StationLongitude/StationLatitude, 2026-11-15).
typedef RadarStation = ({String code, String datasetId, String name, LatLng site});

const radarStations = <RadarStation>[
  (code: 'RCSL', datasetId: CwaDatasets.radarShulinDatasetId, name: '樹林', site: LatLng(25.00, 121.40)),
  (code: 'RCNT', datasetId: CwaDatasets.radarNantunDatasetId, name: '南屯', site: LatLng(24.14, 120.58)),
  (code: 'RCLY', datasetId: CwaDatasets.radarLinyuanDatasetId, name: '林園', site: LatLng(22.53, 120.38)),
];

/// The station radar with dataset id [id]; null for any other id (e.g. the composite).
RadarStation? radarStationById(String id) => radarStations.where((s) => s.datasetId == id).firstOrNull;

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
  final dLat = radiusKm / earthRadiusKilometers * 180 / pi;
  final dLon = dLat / cos(centre.latitude * pi / 180);
  return LatLngBounds(
    LatLng(centre.latitude - dLat, centre.longitude - dLon),
    LatLng(centre.latitude + dLat, centre.longitude + dLon),
  );
}
