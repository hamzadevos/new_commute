import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import '../resources/commute_pop_up.dart';
import '../resources/map_widget.dart';
import '../resources/marker_icon.dart';
import '../resources/navigation_manager.dart';
import '../resources/search_bar.dart';
import '../services/app_location.dart';
import '../services/direction_service.dart';
import '../services/location_service.dart';
import '../services/station_services.dart';
import '../services/stations.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final LatLng _initialPosition = const LatLng(31.5204, 74.3587);
  final StationService _stationService = StationService();
  final MarkerIconManager _iconManager = MarkerIconManager();
  final NavigationHelper _navigationHelper = NavigationHelper();
  final LocationService _locationService = LocationService();
  final String _googleApiKey = 'AAIzaSyAF6J2_-EoNbZsJsnmpOGAjST2uPj0lJ6E';
  List<AppLocation> _locations = [];
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  String _pickupText = 'My Location';
  String _destinationText = '';
  int _stationMode = -1;
  String? _mapStyle;
  bool _isLoading = true;
  bool _showSearchBar = false;
  bool _isNavigating = false;
  bool _isRouteLoading = false;
  Set<Polyline> _polylines = {};
  Set<Marker> _routeMarkers = {};
  AnimationController? _navAnimationController;
  Animation<LatLng>? _navAnimation;
  String? _navDestination;
  String? _navDuration;
  double? _navDistance;
  GoogleMapController? _mapController;
  List<LatLng> _remainingPoints = [];
  final Map<String, List<LatLng>> _routeCache = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _navAnimationController?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      // Load stations on main thread
      await _stationService.loadLocations();
      final validLocations = _stationService.locations
          .where((loc) {
        final isValid = loc.lat != 0 &&
            loc.lng != 0 &&
            loc.lat >= 31.0 &&
            loc.lat <= 32.0 &&
            loc.lng >= 74.0 &&
            loc.lng <= 255.0; // Adjusted for broader coverage
        if (!isValid) {
          debugPrint(
              'Invalid station: ${loc.name}, lat: ${loc.lat}, lng: ${loc.lng}');
        }
        return isValid;
      })
          .take(100)
          .toList();
      if (mounted) {
        setState(() {
          _locations = validLocations;
          debugPrint(
              'MapScreen initialized with ${_locations.length} valid locations');
        });
      }

      try {
        _mapStyle =
        await DefaultAssetBundle.of(context).loadString('assets/map_styles.json');
      } catch (e) {
        debugPrint('Failed to load map style: $e');
        _mapStyle = null;
      }

      final currentLocation = await _getCurrentLocation();
      if (mounted) {
        setState(() {
          _pickupLocation = currentLocation ?? _initialPosition;
          _pickupText = currentLocation != null ? 'My Location' : 'Pickup Location';
          _isLoading = false;
        });
      }
      debugPrint('Current location: $_pickupLocation');

      await _iconManager.loadIcons(context);
      debugPrint('Marker icons initialized');
    } catch (e) {
      debugPrint('Map initialization error: $e');
      if (mounted) {
        setState(() {
          _pickupLocation = _initialPosition;
          _pickupText = 'Lahore Center';
          _isLoading = false;
        });
      }
    }
  }

  static void _loadStations(SendPort sendPort) async {
    final stationService = StationService();
    await stationService.loadLocations(); // No context needed
    final validLocations = stationService.locations
        .where((loc) {
      final isValid = loc.lat != 0 &&
          loc.lng != 0 &&
          loc.lat >= 31.0 &&
          loc.lat <= 32.0 &&
          loc.lng >= 74.0 &&
          loc.lng <= 75.0;
      if (!isValid) {
        debugPrint(
            'Invalid station: ${loc.name}, lat: ${loc.lat}, lng: ${loc.lng}');
      }
      return isValid;
    })
        .take(100)
        .toList();
    sendPort.send([validLocations]);
  }

  Future<LatLng?> _getCurrentLocation() async {
    if (!mounted) return null;
    setState(() {
      _isLoading = true;
    });
    try {
      final location = await _locationService.getCurrentLocation(context);
      if (location != null && _mapController != null && mounted) {
        // Only animate if significantly different
        if (_pickupLocation == null ||
            _navigationHelper.haversineDistance(location, _pickupLocation!) > 0.1) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: location,
                zoom: 16.0,
              ),
            ),
          );
        }
      }
      return location;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e.toString()}')),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_mapStyle != null) {
      controller.setMapStyle(_mapStyle);
    }
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _pickupLocation ?? _initialPosition,
          zoom: 16.0,
        ),
      ),
    );
  }

  void _updateStationMode(int mode) {
    setState(() {
      _stationMode = _stationMode == mode ? -1 : mode;
      _polylines.clear();
      _routeMarkers.clear();
      debugPrint('Station mode updated: $_stationMode');
      if (mode != -1) {
        showNearestStationRoutes();
      }
    });
  }

  void _updatePickup(LatLng location, String text) {
    setState(() {
      _pickupLocation = location;
      _pickupText = text;
      _polylines.clear();
      _routeMarkers.clear();
    });
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: 16.0,
          ),
        ),
      );
    }
  }

  void _updateDestination(LatLng? location, String text) {
    setState(() {
      _destinationLocation = location;
      _destinationText = text;
      _polylines.clear();
      _routeMarkers.clear();
    });
  }

  void showSearchBarWidget() {
    setState(() {
      _showSearchBar = true;
    });
  }

  void _stopNavigation() {
    if (_navAnimationController != null) {
      _navAnimationController!.stop();
      _navAnimationController!.dispose();
      _navAnimationController = null;
    }
    setState(() {
      _isNavigating = false;
      _navDestination = null;
      _navDuration = null;
      _navDistance = null;
      _remainingPoints.clear();
      _routeMarkers.clear();
      _polylines.clear();
    });
  }

  Future<void> _startNavigation(
      LatLng pickup,
      LatLng station,
      LatLng destination,
      String transportType,
      String stationName) async {
    setState(() {
      _isRouteLoading = true;
    });
    debugPrint(
        'Starting navigation: $transportType to $stationName ($station) from $pickup to $destination');
    final directionsService = DirectionsService();
    final cacheKey =
        '${pickup.latitude},${pickup.longitude}_${station.latitude},${station.longitude}_${destination.latitude},${destination.longitude}_${transportType}';

    List<LatLng>? points;
    String? distance, duration;
    try {
      if (_routeCache.containsKey(cacheKey)) {
        debugPrint('Using cached route for $cacheKey');
        points = _routeCache[cacheKey];
      } else {
        if (!_isValidCoordinate(pickup) ||
            !_isValidCoordinate(station) ||
            !_isValidCoordinate(destination)) {
          debugPrint(
              'Invalid coordinates: pickup=$pickup, station=$station, destination=$destination');
          throw Exception('Invalid coordinates');
        }

        // Fetch both segments concurrently
        final results = await Future.wait([
          directionsService.getRoute(pickup, station),
          directionsService.getRoute(station, destination),
        ], eagerError: true);

        final route1 = results[0];
        final route2 = results[1];

        if (route1 == null || route2 == null) {
          debugPrint('Route fetch failed for $stationName ($station)');
          throw Exception('Unable to fetch route');
        }

        points = [
          ...route1['points'] as List<LatLng>,
          ...route2['points'] as List<LatLng>,
        ];
        distance = route1['distance'] as String;
        duration = route1['duration'] as String;
        _routeCache[cacheKey] = points;
        debugPrint('Cached route for $cacheKey with ${points.length} points');
      }

      if (points == null || points.isEmpty) {
        throw Exception('No valid route points');
      }

      _renderNavigation(pickup, station, destination, transportType, stationName,
          points, distance ?? 'Unknown', duration ?? 'Unknown');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load route: $e')),
        );
      }
    } finally {
      setState(() {
        _isRouteLoading = false;
      });
    }
  }

  void _renderNavigation(LatLng pickup, LatLng station, LatLng destination,
      String transportType, String stationName, List<LatLng> points,
      String distanceText, String durationText) {
    debugPrint('Rendering navigation with ${points.length} points');
    final bounds = _getBounds(points);
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));

    final distance = _navigationHelper.haversineDistance(pickup, destination);
    final duration = durationText;

    setState(() {
      _isNavigating = true;
      _navDestination = _destinationText.isNotEmpty ? _destinationText : stationName;
      _navDuration = duration;
      _navDistance = distance;
      _remainingPoints = List.from(points);
      _routeMarkers = {
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          infoWindow: const InfoWindow(title: 'Pickup'),
          icon: _iconManager.myLocationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
        Marker(
          markerId: const MarkerId('station'),
          position: station,
          infoWindow: InfoWindow(title: '$transportType Station'),
          icon: _iconManager.getIconForType(transportType) ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: destination,
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: _iconManager.destinationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
      _polylines = {
        Polyline(
          polylineId: const PolylineId('nav_route'),
          points: points,
          color: Colors.red,
          width: 6,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          zIndex: 1,
        ),
      };
    });

    _navAnimationController?.dispose();
    _navAnimationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    final animation = LatLngTween(
      begin: points.first,
      end: points.last,
    ).animate(CurvedAnimation(
      parent: _navAnimationController!,
      curve: Curves.easeInOut,
    ));

    _navAnimation = animation;

    int frameCounter = 0;
    _navAnimationController!.addListener(() {
      if (!mounted) return;
      frameCounter++;
      if (frameCounter % 3 != 0) return;
      final currentPos = _navAnimation!.value;
      final newRemainingPoints = _remainingPoints
          .skipWhile((p) => _distanceBetween(p, currentPos) < 0.0001)
          .toList();
      setState(() {
        _remainingPoints = newRemainingPoints;
        _routeMarkers = {
          Marker(
            markerId: const MarkerId('pickup'),
            position: pickup,
            infoWindow: const InfoWindow(title: 'Pickup'),
            icon: _iconManager.myLocationIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
          Marker(
            markerId: const MarkerId('station'),
            position: station,
            infoWindow: InfoWindow(title: '$transportType Station'),
            icon: _iconManager.getIconForType(transportType) ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
          Marker(
            markerId: const MarkerId('destination'),
            position: destination,
            infoWindow: const InfoWindow(title: 'Destination'),
            icon: _iconManager.destinationIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
          Marker(
            markerId: const MarkerId('nav_marker'),
            position: currentPos,
            icon: _iconManager.myLocationIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        };
        _polylines = {
          Polyline(
            polylineId: const PolylineId('nav_route'),
            points: [currentPos, ..._remainingPoints],
            color: Colors.red,
            width: 6,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            zIndex: 1,
          ),
        };
      });
    });

    _navAnimationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _stopNavigation();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Navigation completed for $transportType to $stationName'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });

    _navAnimationController!.forward();
    debugPrint('Navigation animation started');
  }

  Future<void> showNearestStationRoutes() async {
    setState(() {
      _isRouteLoading = true;
    });
    if (_pickupLocation == null) {
      setState(() {
        _isRouteLoading = false;
      });
      return;
    }

    try {
      final stations = _locations.whereType<Station>().toList();
      final nearestStations = stations
          .asMap()
          .entries
          .map((e) => {
        'station': e.value,
        'distance': _navigationHelper.haversineDistance(
          _pickupLocation!,
          LatLng(e.value.lat, e.value.lng),
        ),
      })
          .toList()
        ..sort((a, b) =>
            (a['distance'] as double).compareTo(b['distance'] as double));

      final topTwo = nearestStations.take(2).toList();
      final directionsService = DirectionsService();
      Set<Polyline> newPolylines = {};
      Set<Marker> newMarkers = {};

      final routeFutures = topTwo.map((station) async {
        final stationLoc =
        LatLng((station['station'] as Station).lat, (station['station'] as Station).lng);
        final cacheKey =
            '${_pickupLocation!.latitude},${_pickupLocation!.longitude}_${stationLoc.latitude},${stationLoc.longitude}_driving';

        List<LatLng> points;
        if (_routeCache.containsKey(cacheKey)) {
          debugPrint('Using cached route for $cacheKey');
          points = _routeCache[cacheKey]!;
        } else {
          if (!_isValidCoordinate(stationLoc)) {
            debugPrint(
                'Invalid station coordinates: ${(station['station'] as Station).name}, $stationLoc');
            throw Exception('Invalid coordinates');
          }
          final route = await directionsService.getRoute(_pickupLocation!, stationLoc);
          if (route == null) {
            debugPrint(
                'Route fetch failed for ${(station['station'] as Station).name} ($stationLoc)');
            throw Exception('Unable to fetch route');
          }
          points = route['points'] as List<LatLng>;
          _routeCache[cacheKey] = points;
          debugPrint('Cached route for $cacheKey with ${points.length} points');
        }

        return {
          'polyline': Polyline(
            polylineId: PolylineId('route_${(station['station'] as Station).name}'),
            points: points,
            color: Colors.red,
            width: 6,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            zIndex: 1,
          ),
          'marker': Marker(
            markerId: MarkerId('station_${(station['station'] as Station).name}'),
            position: stationLoc,
            infoWindow: InfoWindow(title: (station['station'] as Station).name),
            icon: _iconManager.getIconForType('Station') ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        };
      }).toList();

      final results = await Future.wait(routeFutures);
      for (var result in results) {
        newPolylines.add(result['polyline'] as Polyline);
        newMarkers.add(result['marker'] as Marker); // Explicit cast
      }

      if (newPolylines.isNotEmpty) {
        setState(() {
          _polylines = newPolylines;
          _routeMarkers = newMarkers;
        });

        final bounds = _getBounds(newPolylines.expand((p) => p.points));
        _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      } else {
        throw Exception('No valid routes found');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load routes: $e')),
        );
      }
    } finally {
      setState(() {
        _isRouteLoading = false;
      });
    }
  }

  bool _isValidCoordinate(LatLng coord) {
    return coord.latitude != 0 &&
        coord.longitude != 0 &&
        coord.latitude >= 31.0 &&
        coord.latitude <= 32.0 &&
        coord.longitude >= 74.0 &&
        coord.longitude <= 75.0;
  }

  double _distanceBetween(LatLng p1, LatLng p2) {
    return math.sqrt(
        math.pow(p1.latitude - p2.latitude, 2) +
            math.pow(p1.longitude - p2.longitude, 2));
  }

  LatLngBounds _getBounds(Iterable<LatLng> points) {
    double minLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLat = points.first.latitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  String _estimateTravelTime(double distance, String mode) {
    double speed = mode == 'SpeedoBus' ? 20 : mode == 'MetroBus' ? 30 : 40;
    double timeHours = distance / speed;
    int timeMinutes = (timeHours * 60).round();
    return timeMinutes == 0 ? '1 min' : '$timeMinutes min';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            initialPosition: _initialPosition,
            locations: _locations,
            pickupLocation: _pickupLocation,
            destinationLocation: _destinationLocation,
            stationMode: _stationMode,
            mapStyle: _mapStyle,
            iconManager: _iconManager,
            polylines: _polylines,
            routeMarkers: _routeMarkers,
            onMapCreated: _onMapCreated,
          ),
          if (_showSearchBar)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: SearchBarWidget(
                locations: _locations,
                pickupLocation: _pickupLocation,
                pickupText: _pickupText,
                destinationLocation: _destinationLocation,
                destinationText: _destinationText,
                onPickupChanged: _updatePickup,
                onDestinationChanged: _updateDestination,
                onCommute: () async {
                  if (_pickupLocation == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pickup location not set'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  final result = await CommuteServiceDialog.show(
                    context,
                    pickupLocation: _pickupLocation,
                    destinationLocation: _destinationLocation,
                    pickupText: _pickupText,
                    destinationText: _destinationText,
                    stations: _locations.whereType<Station>().cast<Station>().toList(),
                    navigationHelper: _navigationHelper,
                    googleApiKey: _googleApiKey,
                  );
                  if (result != null &&
                      _pickupLocation != null &&
                      _destinationLocation != null) {
                    final action = result['action'] as String;
                    if (action == 'start' ||
                        action == 'route' ||
                        action == 'dummy_navigate') {
                      debugPrint(
                          'Commute action: $action for ${result['type']} to ${result['stationName']}');
                      await _startNavigation(
                        _pickupLocation!,
                        result['station'] as LatLng,
                        _destinationLocation!,
                        result['type'] as String,
                        result['stationName'] as String,
                      );
                    }
                  }
                },
                locationService: _locationService,
              ),
            ),
          if (_isRouteLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.redAccent,
                strokeWidth: 5,
              ),
            ),
          if (!_isNavigating)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height * 0.45,
              child: Column(
                children: [
                  _StationIcon(
                    icon: Icons.directions_bus,
                    label: 'Speedo',
                    mode: 2,
                    isSelected: _stationMode == 2,
                    onTap: () => _updateStationMode(2),
                  ),
                  const SizedBox(height: 16),
                  _StationIcon(
                    icon: Icons.directions_bus_filled,
                    label: 'Metro',
                    mode: 3,
                    isSelected: _stationMode == 3,
                    onTap: () => _updateStationMode(3),
                  ),
                  const SizedBox(height: 16),
                  _StationIcon(
                    icon: Icons.train,
                    label: 'Orange',
                    mode: 4,
                    isSelected: _stationMode == 4,
                    onTap: () => _updateStationMode(4),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: _isNavigating
          ? null
          : FloatingActionButton(
        onPressed: showSearchBarWidget,
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.search),
      ),
      bottomSheet: _isNavigating
          ? Container(
        color: Colors.white.withOpacity(0.9),
        padding: const EdgeInsets.all(16.0),
        child: Card(
          color: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.navigation,
                        color: Colors.red, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Navigation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'To: ${_navDestination ?? '--'}',
                        style: const TextStyle(
                            fontFamily: 'Outfit', fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.directions,
                        color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Distance: ${_navDistance?.toStringAsFixed(1) ?? '--'} km',
                        style: const TextStyle(
                            fontFamily: 'Outfit', fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ETA: ${_navDuration ?? '--'}',
                        style: const TextStyle(
                            fontFamily: 'Outfit', fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _remainingPoints.isNotEmpty
                      ? 1 -
                      (_remainingPoints.length /
                          (_remainingPoints.length + 1))
                      : 0,
                  backgroundColor: Colors.grey[200],
                  color: Colors.red,
                  minHeight: 6,
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _stopNavigation,
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text(
                      'Stop Navigation',
                      style:
                      TextStyle(fontFamily: 'Outfit', fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      )
          : null,
    );
  }
}

class _StationIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final int mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _StationIcon({
    required this.icon,
    required this.label,
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected ? Colors.red[800] : Colors.redAccent.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? Border.all(color: Colors.grey[200]!, width: 2) : null,
            ),
            child: Icon(icon, size: 24, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.black : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class LatLngTween extends Tween<LatLng> {
  LatLngTween({super.begin, super.end});

  @override
  LatLng lerp(double t) {
    final lat = begin!.latitude + (end!.latitude - begin!.latitude) * t;
    final lng = begin!.longitude + (end!.longitude - begin!.longitude) * t;
    return LatLng(lat, lng);
  }
}