import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final locationServiceProvider = Provider((ref) => LocationService());

class LocationData {
  final double latitude;
  final double longitude;
  final String city;
  final String district;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.district,
  });
}

class LocationService {
  // Default to Taipei City, Xinyi District
  final defaultLocation = LocationData(
    latitude: 25.0330,
    longitude: 121.5654,
    city: '臺北市',
    district: '信義區',
  );

  Future<LocationData> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return defaultLocation;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return defaultLocation;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return defaultLocation;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        String city = place.administrativeArea ?? '';
        String district = place.locality ?? place.subLocality ?? '';
        
        // CWA uses specific naming, ensure it matches if needed.
        // For simplicity, fallback to default if empty
        if (city.isEmpty || district.isEmpty) {
          return defaultLocation;
        }

        return LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          city: city,
          district: district,
        );
      }
    } catch (e) {
      // Ignored, fallback to default
    }

    return defaultLocation;
  }
}
