import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/hazard_models.dart';
import '../../radar/radar_playback.dart';
import '../../radar/widgets/radar_map_view.dart';
import 'rainfall_logic.dart';

/// Forecast window length (F-B0046-001 is the next 1 hour).
const _forecastWindow = Duration(hours: 1);

/// Bring-an-umbrella hint threshold: visible rain on the map.
const _umbrellaMinMm = forecastVisibleMinMm;

const _gridOpacity = 0.8;

/// Bucket 1–4 colours (light → dark = more rain) and legend labels.
const _bucketTints = [AppPalette.brand150, AppPalette.brand120, AppPalette.brand90, AppPalette.brand60];
const _bucketLabels = ['1–5 mm', '5–10', '10–20', '≥ 20'];

const _rgbaChannels = 4;
const _channelMax = 255;

String forecastRange(RainForecastGrid grid) =>
    '${formatTaiwanClock(grid.baseTime)} – ${formatTaiwanClock(grid.baseTime.add(_forecastWindow))}';

/// 「此處」 row under the map: forecast mm at the user's cell (「—」 when that cell has no value).
class _HereRow extends StatelessWidget {
  const _HereRow({required this.mm, required this.placeName});

  final double? mm;
  final String placeName;

  @override
  Widget build(BuildContext context) {
    final value = mm;
    final umbrella = value != null && value >= _umbrellaMinMm;
    return Row(
      children: [
        const Icon(Icons.umbrella_outlined, size: AppSize.icon24, color: AppPalette.rainBar),
        const SizedBox(width: AppSpace.s8),
        Expanded(
          child: Text(
            value == null ? '$placeName 此格無有效預測（雷達無回波或無資料）' : '$placeName預估雨量${umbrella ? ' · 出門請帶傘' : ''}',
            style: AppType.caption1.copyWith(color: AppPalette.fg3),
          ),
        ),
        Text(
          formatMm(value),
          style: AppType.subtitle1.copyWith(color: AppPalette.fg1, fontWeight: FontWeight.w600, fontFeatures: AppType.tabular),
        ),
        const SizedBox(width: AppSpace.s4),
        Text('mm', style: AppType.caption1.copyWith(color: AppPalette.fg2)),
      ],
    );
  }
}

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

/// `未來 1hr 預測` grid map with the value at the user's place and the legend.
class ForecastMapCard extends StatefulWidget {
  const ForecastMapCard({
    super.key,
    required this.forecast,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    this.cameraLink,
  });

  final RainForecast forecast;
  final String placeName;
  final double latitude;
  final double longitude;

  /// Camera shared with the 累積雨量 map (side by side); null = stacked: square, locked until unlocked.
  final RadarCameraLink? cameraLink;

  @override
  State<ForecastMapCard> createState() => _ForecastMapCardState();
}

class _ForecastMapCardState extends State<ForecastMapCard> {
  late Future<ImageProvider> _image = _gridImage(widget.forecast.grid);

  @override
  void didUpdateWidget(ForecastMapCard old) {
    super.didUpdateWidget(old);
    if (!identical(old.forecast.grid, widget.forecast.grid)) _image = _gridImage(widget.forecast.grid);
  }

  LatLngBounds get _bounds {
    final g = widget.forecast.grid;
    final half = g.resolution / 2;
    return LatLngBounds(
      LatLng(g.startLatitude - half, g.startLongitude - half),
      LatLng(g.startLatitude + (g.rows - 1) * g.resolution + half, g.startLongitude + (g.columns - 1) * g.resolution + half),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = forecastRange(widget.forecast.grid);
    return FutureBuilder<ImageProvider>(
      future: _image,
      builder: (context, snapshot) {
        final error = snapshot.error;
        if (error != null) {
          return AppCard.error(
            title: '無法繪製雨量網格圖',
            message: '$error',
            onRetry: () => setState(() => _image = _gridImage(widget.forecast.grid)),
          );
        }
        final image = snapshot.data;
        return AppCard(
          title: '未來 1hr 預測',
          meta: range,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpace.s16,
            children: [
              RadarMapView(
                loading: image == null,
                muted: image == null,
                chipIcon: image == null ? null : Icons.schedule,
                chipText: image == null ? null : range,
                semanticsLabel: '未來 1 小時雨量網格圖',
                aspectRatio: widget.cameraLink == null ? 1 : radarMapDefaultAspectRatio,
                startLocked: widget.cameraLink == null,
                cameraLink: widget.cameraLink,
                overlayImages: image == null
                    ? const []
                    : [
                        OverlayImage(
                          bounds: _bounds,
                          imageProvider: image,
                          opacity: _gridOpacity,
                          filterQuality: FilterQuality.none,
                        ),
                      ],
                me: LatLng(widget.latitude, widget.longitude),
              ),
              _HereRow(mm: widget.forecast.mmAtLocation, placeName: widget.placeName),
              const _ForecastLegend(),
              Text(
                '空白格表示預估雨量小於 1 mm 或無資料。',
                style: AppType.caption1.copyWith(color: AppPalette.fg3),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ForecastLegend extends StatelessWidget {
  const _ForecastLegend();

  static const _swatchSize = AppSize.icon16;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '1 小時雨量圖例（毫米）',
      child: Wrap(
        spacing: AppSpace.s12,
        runSpacing: AppSpace.s8,
        children: [
          for (var i = 0; i < _bucketTints.length; i++)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpace.s4,
              children: [
                Container(
                  width: _swatchSize,
                  height: _swatchSize,
                  decoration: BoxDecoration(color: _bucketTints[i], borderRadius: BorderRadius.circular(AppRadius.extraSmall)),
                ),
                Text(_bucketLabels[i], style: AppType.caption1.copyWith(color: AppPalette.fg2)),
              ],
            ),
        ],
      ),
    );
  }
}
