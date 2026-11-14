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

/// Hero: forecast mm at the user's cell (「—」 when that cell has no value).
class ForecastHeroCard extends StatelessWidget {
  const ForecastHeroCard({super.key, required this.forecast, required this.placeName});

  final RainForecast forecast;
  final String placeName;

  @override
  Widget build(BuildContext context) {
    final mm = forecast.mmAtLocation;
    final umbrella = mm != null && mm >= _umbrellaMinMm;
    return AppCard(
      hero: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpace.s4,
              children: [
                Text(
                  '未來 1 小時 · ${forecastRange(forecast.grid)}',
                  style: AppType.caption1.copyWith(color: AppPalette.fg3, fontFeatures: AppType.tabular),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  spacing: AppSpace.s8,
                  children: [
                    Text(
                      formatMm(mm),
                      style: AppType.display.copyWith(color: AppPalette.fg1, fontFeatures: AppType.tabular),
                    ),
                    Text('mm', style: AppType.subtitle1.copyWith(color: AppPalette.fg2, fontWeight: FontWeight.w600)),
                  ],
                ),
                Text(
                  mm == null ? '$placeName 此格無預測值' : '$placeName預估雨量${umbrella ? ' · 出門請帶傘' : ''}',
                  style: AppType.caption1.copyWith(color: AppPalette.fg3),
                ),
              ],
            ),
          ),
          const Icon(Icons.umbrella_outlined, size: AppSize.icon64, color: AppPalette.rainBar),
        ],
      ),
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

/// `未來 1 小時雨量` grid map with legend.
class ForecastMapCard extends StatefulWidget {
  const ForecastMapCard({super.key, required this.grid, required this.latitude, required this.longitude});

  final RainForecastGrid grid;
  final double latitude;
  final double longitude;

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
    return FutureBuilder<ImageProvider>(
      future: _image,
      builder: (context, snapshot) {
        final error = snapshot.error;
        if (error != null) {
          return AppCard.error(
            title: '無法繪製雨量網格圖',
            message: '$error',
            onRetry: () => setState(() => _image = _gridImage(widget.grid)),
          );
        }
        final image = snapshot.data;
        return AppCard(
          title: '未來 1 小時雨量',
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
                overlayBuilder: image == null
                    ? null
                    : (_) => [
                          OverlayImage(
                            bounds: _bounds,
                            imageProvider: image,
                            opacity: _gridOpacity,
                            filterQuality: FilterQuality.none,
                          ),
                        ],
                me: LatLng(widget.latitude, widget.longitude),
              ),
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
                  decoration: BoxDecoration(color: _bucketTints[i], borderRadius: BorderRadius.circular(AppRadius.sm)),
                ),
                Text(_bucketLabels[i], style: AppType.caption1.copyWith(color: AppPalette.fg2)),
              ],
            ),
        ],
      ),
    );
  }
}
