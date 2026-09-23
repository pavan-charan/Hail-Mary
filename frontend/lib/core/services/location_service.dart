import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';

class LocationService {
  static const LatLng defaultKochiLocation = LatLng(AppConfig.defaultLat, AppConfig.defaultLon);

  /// Requests user location permission with full error resilience across Web, Android, and iOS.
  static Future<LocationPermission> requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[LocationService] Location services are disabled.');
      return LocationPermission.denied;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Gets the single current GPS position of the citizen
  static Future<LatLng> getCurrentPosition() async {
    try {
      final permission = await requestLocationPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Permission denied, using Kochi default location.');
        return defaultKochiLocation;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('[LocationService] Failed to acquire GPS position: $e');
      return defaultKochiLocation;
    }
  }

  /// Returns a stream of real-time GPS location updates
  static Stream<LatLng> getPositionStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, // notify every 2 meters moved
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings).map(
      (pos) => LatLng(pos.latitude, pos.longitude),
    ).handleError((error) {
      debugPrint('[LocationService] Stream error: $error');
    });
  }
}
