import 'package:geolocator/geolocator.dart';

enum LocationStatus {
  ok,
  denied,
  deniedForever,
  serviceDisabled,
  timeout,
  error,
}

class LocationResult {
  const LocationResult(
    this.status, {
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.capturedAt,
  });

  final LocationStatus status;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? capturedAt;

  bool get hasFix =>
      status == LocationStatus.ok && latitude != null && longitude != null;

  /// Human explanation; real coordinates are never fabricated when there is no fix.
  String get message {
    switch (status) {
      case LocationStatus.ok:
        return 'Location found (accuracy ~${accuracyMeters?.round() ?? '?'} m).';
      case LocationStatus.denied:
        return 'Location permission was not granted. Responders will not receive your position.';
      case LocationStatus.deniedForever:
        return 'Location permission is blocked. Enable it in system settings to share your position.';
      case LocationStatus.serviceDisabled:
        return 'Location services are turned off on this device.';
      case LocationStatus.timeout:
        return 'Could not get a GPS fix in time.';
      case LocationStatus.error:
        return 'Location is unavailable right now.';
    }
  }
}

abstract class LocationProvider {
  Future<LocationResult> current({bool requestPermission = true});
  Future<bool> openSettings();
}

class DeviceLocationProvider implements LocationProvider {
  @override
  Future<LocationResult> current({bool requestPermission = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationStatus.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationStatus.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(LocationStatus.denied);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocationResult(
        LocationStatus.ok,
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyMeters: pos.accuracy,
        capturedAt: pos.timestamp,
      );
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return const LocationResult(LocationStatus.timeout);
      }
      return const LocationResult(LocationStatus.error);
    }
  }

  @override
  Future<bool> openSettings() => Geolocator.openAppSettings();
}
