import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/place.dart';
import '../api/result.dart';
import '../../data/repositories/weather_repository.dart';

final locationServiceProvider =
    Provider((ref) => LocationService(ref.watch(weatherRepositoryProvider).nearestTown));

class LocationData {
  final double latitude;
  final double longitude;
  final String city;
  final String district;

  /// GPS 定位時刻（定位結果的時間戳）；非 GPS 來源（手動地點查詢）為 null
  final DateTime? fixedAt;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.district,
    this.fixedAt,
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

/// 使用者決定：10 秒內沒有定位結果就視為失敗並返回，讓使用者手動選地點（macOS 定位可能永不回應）。
const locationTimeout = Duration(seconds: 10);

class LocationService {
  final Future<Result<Place>> Function(double latitude, double longitude) _nearestTown;
  final Duration timeout;

  LocationService(this._nearestTown, {this.timeout = locationTimeout});

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
      ).timeout(timeout);
    } on TimeoutException catch (e) {
      // 逾時只計「取得座標」這一步；權限詢問是使用者在回答的系統對話框，不計時。
      throw LocationException(
        LocationFailure.positionUnavailable,
        '${timeout.inSeconds} 秒內未取得位置（getCurrentPosition 無回應，權限狀態 $permission）',
        cause: e,
      );
    } on Exception catch (e) {
      throw LocationException(
        LocationFailure.positionUnavailable,
        'Step getCurrentPosition failed after permission was granted ($permission); expected a position, got: $e',
        cause: e,
      );
    }

    final town = await _nearestTown(position.latitude, position.longitude);
    if (town is Failure<Place>) {
      throw LocationException(
        LocationFailure.addressUnresolved,
        'Cannot resolve county/town for (${position.latitude}, ${position.longitude}): ${town.message}',
      );
    }
    final place = town.data;

    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      city: place.county,
      district: place.town,
      fixedAt: position.timestamp,
    );
  }
}
