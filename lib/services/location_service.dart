import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  Future<LatLng?> getCurrentLocation(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.', style: TextStyle(fontFamily: 'Outfit'))),
      );
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied.', style: TextStyle(fontFamily: 'Outfit'))),
        );
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Location permissions are permanently denied.', style: TextStyle(fontFamily: 'Outfit'))),
      );
      return null;
    }

    Position position = await Geolocator.getCurrentPosition();
    LatLng location = LatLng(position.latitude, position.longitude);
    debugPrint('Current location: $location');
    // Validate location (Lahore bounds: 31.0-32.0, 74.0-75.0)
    if (position.latitude < 31.0 || position.latitude > 32.0 || position.longitude < 74.0 || position.longitude > 75.0) {
      debugPrint('Invalid location detected: $location, likely emulator issue');
      return null;
    }
    return location;
  }
}