import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/location/location_service.dart';
import '../../core/theme/glass_morphism.dart';
import '../../data/repositories/weather_repository.dart';
import '../../core/constants/app_constants.dart';

final radarImageProvider = FutureProvider.family<String?, String>((ref, datasetId) async {
  final repo = ref.watch(weatherRepositoryProvider);
  final result = await repo.getRadarImageUrl(datasetId: datasetId);
  return result.fold(
    onSuccess: (url) => url,
    onFailure: (_, __) => null,
  );
});

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  String selectedRadar = AppConstants.radarTaiwan;
  double opacity = 0.6;

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(locationServiceProvider).getCurrentLocation();

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
            future: locationAsync,
            builder: (context, snapshot) {
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
    final radarAsync = ref.watch(radarImageProvider(selectedRadar));
    
    return radarAsync.when(
      data: (url) {
        if (url == null) return const SizedBox.shrink();
        
        // Note: The exact bounds (south, west, north, east) depend heavily on the specific CWA radar.
        // For demonstration, we assume a bounding box covering Taiwan roughly.
        // In real app, we extract bounds from CWA metadata or hardcode per radar.
        final bounds = LatLngBounds(
          const LatLng(21.0, 119.0), // SouthWest
          const LatLng(26.0, 123.0), // NorthEast
        );

        return OverlayImageLayer(
          overlayImages: [
            OverlayImage(
              bounds: bounds,
              opacity: opacity,
              imageProvider: NetworkImage(url),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(), // Or show a small indicator in corner
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
