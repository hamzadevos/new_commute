import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'app_location.dart';
import 'stations.dart';

class StationService {
  List<AppLocation> locations = [];

  Future<void> loadLocations() async {
    try {
      // Load stations
      final String stationResponse =
      await rootBundle.loadString('assets/stations.json');
      final List<dynamic> stationData = jsonDecode(stationResponse);
      final List<Station> stations =
      stationData.map((json) => Station.fromJson(json)).toList();

      // Load famous locations
      final String locationResponse =
      await rootBundle.loadString('assets/locations.json');
      final List<dynamic> locationData = jsonDecode(locationResponse);
      final List<Location> famousLocations =
      locationData.map((json) => Location.fromJson(json)).toList();

      // Combine into a single list
      locations = [...stations, ...famousLocations];
      debugPrint(
          'StationService loaded: ${stations.length} stations, ${famousLocations.length} locations');
      debugPrint('StationService raw: ${locations.length} locations');
    } catch (e) {
      debugPrint('Error loading locations: $e');
      throw Exception('Failed to load locations');
    }
  }
}