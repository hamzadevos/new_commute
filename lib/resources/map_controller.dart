import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/stations.dart';

class MapController {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  Map<String, Polyline>? _polylines;
  final VoidCallback onMapCreated;

  MapController({required this.onMapCreated});

  Set<Marker> get markers => _markers;
  Map<String, Polyline>? get polylines => _polylines;

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> loadMapStyle(BuildContext context) async {
    try {
      final String style = await DefaultAssetBundle.of(context).loadString('assets/map_style.json');
      await _mapController?.setMapStyle(style);
      debugPrint('Map style loaded from map_style.json');
    } catch (e) {
      debugPrint('Error loading map style: $e');
    }
  }

  void updateMapData({
    LatLng? pickupLocation,
    LatLng? destinationLocation,
    String? destinationText,
    List<Station>? stations,
    int? stationMode,
    Station? nearestStation,
    int? selectedIndex,
    Map<String, Polyline>? polylines,
  }) {
    _markers.clear();
    if (pickupLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: pickupLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
    if (destinationLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destinationLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
    if (stations != null && stationMode != null && stationMode == 1) {
      for (var station in stations) {
        _markers.add(Marker(
          markerId: MarkerId(station.id),
          position: LatLng(station.lat, station.lng),
          infoWindow: InfoWindow(title: station.name, snippet: station.type),
        ));
      }
    }
    if (nearestStation != null) {
      _markers.add(Marker(
        markerId: MarkerId(nearestStation.id),
        position: LatLng(nearestStation.lat, nearestStation.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: nearestStation.name, snippet: 'Nearest Station'),
      ));
    }
    _polylines = polylines;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            pickupLocation!.latitude < destinationLocation!.latitude
                ? pickupLocation.latitude
                : destinationLocation.latitude,
            pickupLocation.longitude < destinationLocation.longitude
                ? pickupLocation.longitude
                : destinationLocation.longitude,
          ),
          northeast: LatLng(
            pickupLocation.latitude > destinationLocation.latitude
                ? pickupLocation.latitude
                : destinationLocation.latitude,
            pickupLocation.longitude > destinationLocation.longitude
                ? pickupLocation.longitude
                : destinationLocation.longitude,
          ),
        ),
        100,
      ),
    );
  }
}