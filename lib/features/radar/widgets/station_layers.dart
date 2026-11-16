import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_tokens.dart';

/// Station coverage ring (dashed): points on the circle and dash pattern in px.
const _ringPoints = 72;
const _ringStrokeWidth = 1.5;
const _ringDash = [4.0, 4.0];
const _stationDotRadius = 3.5;
const _fullCircleDegrees = 360;

/// Dashed coverage ring and station dot of a station image covering [bounds].
List<Widget> radarStationLayers(LatLngBounds bounds) {
  final center = bounds.center;
  final radius = const Distance().as(LengthUnit.Meter, center, LatLng(bounds.north, center.longitude));
  return [
    PolygonLayer(
      polygons: [
        Polygon(
          points: [
            for (var i = 0; i < _ringPoints; i++)
              const Distance().offset(center, radius, i * _fullCircleDegrees / _ringPoints),
          ],
          borderColor: AppPalette.brandStroke,
          borderStrokeWidth: _ringStrokeWidth,
          pattern: StrokePattern.dashed(segments: _ringDash),
        ),
      ],
    ),
    MarkerLayer(
      markers: [
        Marker(
          point: center,
          width: _stationDotRadius * 2,
          height: _stationDotRadius * 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPalette.brandBackground,
              border: Border.all(color: AppPalette.background1, width: _ringStrokeWidth),
            ),
          ),
        ),
      ],
    ),
  ];
}
