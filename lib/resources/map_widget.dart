import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/app_location.dart';
import '../services/stations.dart';
import 'marker_icon.dart';

class MapWidget extends StatefulWidget {
  final LatLng initialPosition;
  final List<AppLocation> locations;
  final LatLng? pickupLocation;
  final LatLng? destinationLocation;
  final int stationMode;
  final String? mapStyle;
  final MarkerIconManager iconManager;
  final Set<Polyline> polylines;
  final Set<Marker> routeMarkers;
  final Function(GoogleMapController)? onMapCreated;

  const MapWidget({
    super.key,
    required this.initialPosition,
    required this.locations,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.stationMode,
    this.mapStyle,
    required this.iconManager,
    required this.polylines,
    required this.routeMarkers,
    this.onMapCreated,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  List<AppLocation> _visibleLocations = [];
  LatLngBounds? _visibleBounds;
  String? _lastStationType;

  @override
  void initState() {
    super.initState();
    _updateMarkersAndLocations();
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stationMode != widget.stationMode ||
        oldWidget.pickupLocation != widget.pickupLocation ||
        oldWidget.destinationLocation != widget.destinationLocation ||
        oldWidget.polylines != widget.polylines ||
        oldWidget.routeMarkers != widget.routeMarkers ||
        oldWidget.locations != widget.locations) {
      _updateMarkersAndLocations();
      _updateCamera();
    }
  }

  void _updateMarkersAndLocations() {
    final currentStationType = _getStationType();
    if (_lastStationType != currentStationType ||
        widget.pickupLocation != null ||
        widget.destinationLocation != null ||
        widget.routeMarkers.isNotEmpty) {
      _markers = {...widget.routeMarkers};

      if (widget.stationMode >= 2) {
        final stationsToShow = widget.locations
            .whereType<Station>()
            .where((s) => s.type == currentStationType)
            .take(50)
            .toList();

        _markers.addAll(stationsToShow.map((station) {
          final icon = station.type == 'SpeedoBus'
              ? widget.iconManager.speedoIcon
              : station.type == 'MetroBus'
              ? widget.iconManager.metroIcon
              : widget.iconManager.trainIcon;
          return Marker(
            markerId: MarkerId(station.id),
            position: LatLng(station.lat, station.lng),
            infoWindow: InfoWindow(title: station.name),
            icon: icon ?? BitmapDescriptor.defaultMarker,
          );
        }));
        debugPrint('Added ${stationsToShow.length} station markers for type: $currentStationType');
      }

      _lastStationType = currentStationType;
    }

    _visibleLocations = _getVisibleLocations();
  }

  String _getStationType() {
    switch (widget.stationMode) {
      case 2:
        return 'SpeedoBus';
      case 3:
        return 'MetroBus';
      case 4:
        return 'OrangeTrain';
      default:
        return '';
    }
  }

  List<AppLocation> _getVisibleLocations() {
    if (_visibleBounds == null) {
      return widget.locations.take(30).toList();
    }
    return widget.locations
        .where((location) => _visibleBounds!.contains(LatLng(location.lat, location.lng)))
        .take(30)
        .toList();
  }

  void _updateCamera() {
    if (_mapController == null || widget.routeMarkers.isEmpty) return;

    List<LatLng> points = [];
    if (widget.pickupLocation != null) points.add(widget.pickupLocation!);
    if (widget.destinationLocation != null) points.add(widget.destinationLocation!);
    for (var marker in widget.routeMarkers) {
      points.add(marker.position);
    }

    if (points.isNotEmpty) {
      double south = points[0].latitude;
      double north = points[0].latitude;
      double west = points[0].longitude;
      double east = points[0].longitude;

      for (var point in points) {
        if (point.latitude < south) south = point.latitude;
        if (point.latitude > north) north = point.latitude;
        if (point.longitude < west) west = point.longitude;
        if (point.longitude > east) east = point.longitude;
      }

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(south, west),
            northeast: LatLng(north, east),
          ),
          50,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.initialPosition,
            zoom: 16.0,
          ),
          markers: _markers,
          polylines: widget.polylines,
          mapType: MapType.normal,
          onMapCreated: (controller) {
            _mapController = controller;
            if (widget.mapStyle != null) {
              controller.setMapStyle(widget.mapStyle);
            }
            widget.onMapCreated?.call(controller);
            _updateCamera();
          },
          onCameraMove: (position) async {
            final bounds = await _mapController?.getVisibleRegion();
            if (bounds != null && bounds != _visibleBounds) {
              setState(() {
                _visibleBounds = bounds;
                _visibleLocations = _getVisibleLocations();
              });
            }
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
            Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
          },
        ),
        if (widget.stationMode == -1)
          for (var i = 0; i < _visibleLocations.length; i++)
            FutureBuilder<ScreenCoordinate>(
              key: ValueKey('${_visibleLocations[i].name}_$i'),
              future: _mapController?.getScreenCoordinate(
                  LatLng(_visibleLocations[i].lat, _visibleLocations[i].lng)),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == null) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  left: snapshot.data!.x.toDouble() - 50,
                  top: snapshot.data!.y.toDouble() - 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _visibleLocations[i].name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                );
              },
            ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}