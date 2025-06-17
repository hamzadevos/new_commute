import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DirectionsService {
  static const _apiKey = 'AIzaSyAF6J2_-EoNbZsJsnmpOGAjST2uPj0lJ6E';
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  Future<Map<String, dynamic>?> getRoute(LatLng origin, LatLng destination,
      {String mode = 'driving'}) async {
    if (!_isValidCoordinate(origin) || !_isValidCoordinate(destination)) {
      debugPrint('Invalid coordinates: origin=$origin, destination=$destination');
      return null;
    }

    final url = Uri.parse('$_baseUrl?'
        'origin=${origin.latitude},${origin.longitude}&'
        'destination=${destination.latitude},${destination.longitude}&'
        'mode=$mode&'
        'key=$_apiKey');

    try {
      debugPrint('Fetching route: $url');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      debugPrint('Route response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Directions API status: ${data['status']}');
        if (data['status'] == 'OK') {
          final polyline = data['routes'][0]['overview_polyline']['points'];
          final points = _decodePolyline(polyline);
          final distance = data['routes'][0]['legs'][0]['distance']['text'];
          final duration = data['routes'][0]['legs'][0]['duration']['text'];
          return {
            'points': points,
            'distance': distance,
            'duration': duration,
          };
        } else {
          debugPrint('API error: ${data['status']} ${data['error_message'] ?? ''}');
        }
      } else {
        debugPrint('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
    }
    return null;
  }

  bool _isValidCoordinate(LatLng coord) {
    return coord.latitude != 0 &&
        coord.longitude != 0 &&
        coord.latitude >= 31.0 &&
        coord.latitude <= 32.0 &&
        coord.longitude >= 74.0 &&
        coord.longitude <= 75.0;
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}