import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/hazard_models.dart';
import '../../../core/time/taiwan_time.dart';
import '../../radar/widgets/radar_map_view.dart';
import 'rain_map_card.dart';
import 'rainfall_logic.dart';

/// Forecast window length (F-B0046-001 is the next 1 hour).
const _forecastWindow = Duration(hours: 1);

/// The umbrella in the 此處預估 pill turns rain-blue from this much rain: visible rain on the map.
const _umbrellaMinimumMillimeters = forecastVisibleMinimumMillimeters;

/// Bucket 1–4 colours (light → dark = more rain) and legend labels.
const _bucketTints = [AppPalette.brand150, AppPalette.brand120, AppPalette.brand90, AppPalette.brand60];
const _bucketMarks = [(0, '1–5'), (1, '5–10'), (2, '10–20'), (3, '≥ 20')];

const _rgbaChannels = 4;
const _channelMax = 255;

String forecastRange(RainForecastGrid grid) =>
    '${clockText(grid.baseTime)} – ${clockText(grid.baseTime.add(_forecastWindow))}';

/// Renders the forecast grid as one image: 1 px per cell, north up, blank where
/// [forecastBuckets] is 0. The image is built once per grid.
Future<ImageProvider> _gridImage(RainForecastGrid grid) async {
  final buckets = forecastBuckets(grid);
  final pixels = Uint8List(buckets.length * _rgbaChannels);
  for (var y = 0; y < grid.rows; y++) {
    final row = grid.rows - 1 - y; // grid row 0 is the southern edge
    for (var x = 0; x < grid.columns; x++) {
      final bucket = buckets[y * grid.columns + x];
      if (bucket == 0) continue;
      final c = _bucketTints[bucket - 1];
      final o = (row * grid.columns + x) * _rgbaChannels;
      pixels[o] = (c.r * _channelMax).round();
      pixels[o + 1] = (c.g * _channelMax).round();
      pixels[o + 2] = (c.b * _channelMax).round();
      pixels[o + 3] = _channelMax;
    }
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, grid.columns, grid.rows, ui.PixelFormat.rgba8888, done.complete);
  final image = await done.future;
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (png == null) throw StateError('encoding the ${grid.columns}x${grid.rows} rain grid to PNG returned no data');
  return MemoryImage(png.buffer.asUint8List());
}

/// `未來 1hr 預測` grid map with the value at the user's place (the map's top-left pill) and the legend.
class ForecastMapCard extends StatefulWidget {
  const ForecastMapCard({super.key, required this.grid, required this.currentPlaceForecast, this.cameraLink, required this.wide});

  final RainForecastGrid grid;

  /// The current place and the forecast at it; null = no place (no pin, the pill shows the time range).
  final ({LatLng point, double? millimeters})? currentPlaceForecast;

  /// Camera shared with the 累積雨量 map; only links the cameras.
  final RadarCameraLink? cameraLink;

  /// Map free and sized by the card; false = square locked map.
  final bool wide;

  @override
  State<ForecastMapCard> createState() => _ForecastMapCardState();
}

class _ForecastMapCardState extends State<ForecastMapCard> {
  late Future<ImageProvider> _image = _gridImage(widget.grid);

  @override
  void didUpdateWidget(ForecastMapCard old) {
    super.didUpdateWidget(old);
    if (!identical(old.grid, widget.grid)) _image = _gridImage(widget.grid);
  }

  LatLngBounds get _bounds {
    final g = widget.grid;
    final half = g.resolution / 2;
    return LatLngBounds(
      LatLng(g.startLatitude - half, g.startLongitude - half),
      LatLng(g.startLatitude + (g.rows - 1) * g.resolution + half, g.startLongitude + (g.columns - 1) * g.resolution + half),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = forecastRange(widget.grid);
    final currentPlaceForecast = widget.currentPlaceForecast;
    return FutureBuilder<ImageProvider>(
      future: _image,
      builder: (context, snapshot) {
        final error = snapshot.error;
        if (error != null) {
          return AppCard.error(title: '無法繪製雨量網格圖', message: '$error', onRetry: () => setState(() => _image = _gridImage(widget.grid)));
        }
        final image = snapshot.data;
        final millimeters = currentPlaceForecast?.millimeters;
        return RainMapCard(
          title: '未來 1hr 預測',
          meta: range,
          legend: const RainLegend(title: 'mm / 1hr', semanticsLabel: '1 小時雨量圖例（毫米）', colours: _bucketTints, marks: _bucketMarks, compact: true),
          wide: widget.wide,
          map: RainMapView(
            wide: widget.wide,
            cameraLink: widget.cameraLink,
            loading: image == null,
            muted: image == null,
            chipIcon: currentPlaceForecast == null ? Icons.schedule : Icons.umbrella_outlined,
            chipIconColor: millimeters != null && millimeters >= _umbrellaMinimumMillimeters ? AppPalette.rainBar : AppPalette.foreground1,
            chipText: image == null
                ? null
                : currentPlaceForecast == null
                    ? range
                    : '此處預估 ${millimetersText(millimeters)}${millimeters == null ? '' : ' mm'}',
            semanticsLabel: '未來 1 小時雨量網格圖',
            overlayImages: image == null
                ? const []
                : [OverlayImage(bounds: _bounds, imageProvider: image, opacity: rainMapOverlayOpacity, filterQuality: FilterQuality.none)],
            currentPlacePoint: currentPlaceForecast?.point,
          ),
        );
      },
    );
  }
}
