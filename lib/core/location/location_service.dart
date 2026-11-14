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

enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  positionUnavailable,
  addressUnresolved,
}

/// Thrown when the device location cannot be obtained. Never replaced by a default location.
class LocationException implements Exception {
  final LocationFailure failure;
  final String message;
  final Object? cause;

  LocationException(this.failure, this.message, {this.cause});

  @override
  String toString() => 'LocationException(${failure.name}): $message';
}

class LocationService {
  static const _positionSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
  );

  Future<LocationData> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException(
        LocationFailure.serviceDisabled,
        'Device location service is disabled; expected enabled.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
        throw LocationException(
          LocationFailure.permissionDenied,
          'Location permission denied by user.',
        );
      case LocationPermission.deniedForever:
        throw LocationException(
          LocationFailure.permissionDeniedForever,
          'Location permission permanently denied; enable it in system settings.',
        );
      case LocationPermission.unableToDetermine:
        throw LocationException(
          LocationFailure.permissionDenied,
          'Location permission state could not be determined.',
        );
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        break;
    }

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: _positionSettings,
      );
    } on Exception catch (e) {
      throw LocationException(
        LocationFailure.positionUnavailable,
        'Failed to read current position: $e',
        cause: e,
      );
    }

    final List<Placemark> placemarks;
    try {
      placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
    } on Exception catch (e) {
      throw LocationException(
        LocationFailure.addressUnresolved,
        'Reverse geocoding failed for (${position.latitude}, ${position.longitude}): $e',
        cause: e,
      );
    }

    final place = placemarks.isEmpty ? null : placemarks.first;
    final city = place?.administrativeArea ?? '';
    final district = place?.locality ?? place?.subLocality ?? '';
    if (city.isEmpty || district.isEmpty) {
      throw LocationException(
        LocationFailure.addressUnresolved,
        'Reverse geocoding returned no city/district for (${position.latitude}, ${position.longitude}); got city="$city", district="$district".',
      );
    }

    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      city: city,
      district: district,
    );
  }
}
