import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/stations.dart';

class NavigationHelper {
  Future<LatLng?> getCurrentLocation(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.')),
        );
      }
      return null;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      return null;
    }
  }

  Station? findNearestStation(LatLng? location, List<Station> stations, {String? type}) {
    if (location == null || stations.isEmpty) return null;

    List<Station> filteredStations = type != null
        ? stations.where((s) => s.type == type).toList()
        : stations;

    if (filteredStations.isEmpty) return null;

    return filteredStations.reduce((a, b) {
      double distA = haversineDistance(location, LatLng(a.lat, a.lng));
      double distB = haversineDistance(location, LatLng(b.lat, b.lng));
      return distA < distB ? a : b;
    });
  }

  double haversineDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // km
    double lat1 = start.latitude * math.pi / 180;
    double lat2 = end.latitude * math.pi / 180;
    double deltaLat = (end.latitude - start.latitude) * math.pi / 180;
    double deltaLng = (end.longitude - start.longitude) * math.pi / 180;

    double a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  Future<bool> launchGoogleMaps(
      BuildContext context,
      LatLng origin,
      LatLng destination,
      String mode,
      String originText,
      String destinationText,
      ) async {
    final String originStr = '${origin.latitude},${origin.longitude}';
    final String destStr = '${destination.latitude},${destination.longitude}';
    final String travelMode = mode.toLowerCase();
    final String googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&origin=$originStr&destination=$destStr&travelmode=$travelMode';

    try {
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl));
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Google Maps.')),
          );
        }
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening Google Maps.')),
        );
      }
      return false;
    }
  }

  Future<void> launchGoogleMapsPoiQuery(
      BuildContext context,
      LatLng location,
      String query,
      ) async {
    final Map<String, String> queryMapping = {
      'hospital': 'hospitals',
      'bank': 'banks',
      'car park': 'parking',
      'restaurant': 'restaurants',
      'power unit': 'power stations',
      'oil station': 'gas stations',
    };

    final searchQuery = queryMapping[query.toLowerCase()] ?? query;
    final String locationStr = '${location.latitude},${location.longitude}';
    final String googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$searchQuery+near+Lahore&ll=$locationStr';

    try {
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl));
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Google Maps.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $searchQuery')),
        );
      }
    }
  }
}