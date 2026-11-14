import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/location/location_service.dart';
import '../../core/theme/glass_morphism.dart';
import '../../core/constants/app_constants.dart';
import 'radar_provider.dart';

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  String selectedRadar = AppConstants.radarTaiwan;
  double opacity = 0.6;
  late Future<LocationData> _location;

  @override
  void initState() {
    super.initState();
    _location = ref.read(locationServiceProvider).getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('雷達回波圖', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Base Map
          FutureBuilder<LocationData>(
            future: _location,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '無法取得位置：${snapshot.error}',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _location = ref.read(locationServiceProvider).getCurrentLocation();
                        }),
                        child: const Text('重試'),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final loc = snapshot.data!;
              return FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(loc.latitude, loc.longitude),
                  initialZoom: 8.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.cwbweather',
                  ),
                  // Radar Overlay
                  _buildRadarOverlay(),
                  // User Location Marker
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(loc.latitude, loc.longitude),
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          // Controls panel
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Radar Source Selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildChoice('全台', AppConstants.radarTaiwan),
                        const SizedBox(width: 8),
                        _buildChoice('樹林', AppConstants.radarShulin),
                        const SizedBox(width: 8),
                        _buildChoice('南屯', AppConstants.radarNantun),
                        const SizedBox(width: 8),
                        _buildChoice('林園', AppConstants.radarLinyuan),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Opacity Slider
                  Row(
                    children: [
                      const Icon(Icons.opacity, color: Colors.white),
                      Expanded(
                        child: Slider(
                          value: opacity,
                          min: 0.1,
                          max: 1.0,
                          activeColor: Colors.blueAccent,
                          inactiveColor: Colors.white30,
                          onChanged: (val) => setState(() => opacity = val),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoice(String label, String datasetId) {
    final isSelected = selectedRadar == datasetId;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87)),
      selected: isSelected,
      selectedColor: Colors.blueAccent,
      onSelected: (val) {
        if (val) setState(() => selectedRadar = datasetId);
      },
    );
  }

  Widget _buildRadarOverlay() {
    if (selectedRadar == AppConstants.radarTaiwan) return _buildCompositeOverlay();
    final radarAsync = ref.watch(openDataRadarProvider(selectedRadar));

    return radarAsync.when(
      data: (radar) => OverlayImageLayer(
        overlayImages: [
          OverlayImage(
            bounds: radar.bounds,
            opacity: opacity,
            imageProvider: NetworkImage(radar.imageUrl),
          ),
        ],
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  /// 全台: newest processed website frame (same image as O-A0058-001, reprojected).
  Widget _buildCompositeOverlay() {
    final decodeWidth = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).ceil();
    return ref.watch(radarFramesProvider).when(
          data: (frames) => OverlayImageLayer(
            overlayImages: [
              for (final band in frames.last.bands)
                OverlayImage(
                  bounds: band.bounds,
                  opacity: opacity,
                  imageProvider: band.imageProvider(decodeWidth: decodeWidth),
                ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
  }
}
