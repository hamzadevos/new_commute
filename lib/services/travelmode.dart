import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/direction_service.dart';
import '../services/station_services.dart';
import '../services/stations.dart';
import '../resources/navigation_manager.dart';
import '../resources/marker_icon.dart';
import 'app_location.dart';

class TravelModeWidget extends StatefulWidget {
  final VoidCallback onGetMeSomewhereTapped;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onSeeAllRoutesTapped;
  final GoogleMapController? mapController;
  final bool isNavigating;
  final Function(Set<Polyline>, Set<Marker>, LatLngBounds?)? onUpdateRoute;
  final LatLng? pickupLocation;
  final List<AppLocation> locations;
  final String googleApiKey;

  const TravelModeWidget({
    super.key,
    required this.onGetMeSomewhereTapped,
    this.onToggleVisibility,
    this.onSeeAllRoutesTapped,
    this.mapController,
    this.isNavigating = false,
    this.onUpdateRoute,
    this.pickupLocation,
    required this.locations,
    required this.googleApiKey,
  });

  @override
  _TravelModeWidgetState createState() => _TravelModeWidgetState();
}

class _TravelModeWidgetState extends State<TravelModeWidget> {
  String? _selectedTravelMode;
  bool _isLoadingSpeedo = false;
  bool _isLoadingMetro = false;
  bool _isLoadingOrange = false;
  LatLng? _lastLocation;
  final Map<String, List<LatLng>> _routeCache = {};
  final Set<String> _fetchingRoutes = {};
  final Map<String, bool> _errorShown = {};
  final NavigationHelper _navigationHelper = NavigationHelper();
  final MarkerIconManager _iconManager = MarkerIconManager();
  final StationService _stationService = StationService();
  final Map<String, List<Station>> _stationCache = {};
  DateTime? _lastTapTime;

  static const Map<String, String> _transportTypes = {
    'Speedo': 'SpeedoBus',
    'Metro': 'MetroBus',
    'OrangeTrain': 'OrangeTrain',
  };

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _iconManager.loadIcons(context);
      debugPrint('All icons loaded successfully');
    } catch (e) {
      debugPrint('Error loading icons: $e');
      _showError('icon_load', 'Failed to load map icons.');
    }

    try {
      await _stationService.loadLocations();
      debugPrint('StationService loaded: ${_stationService.locations.length} locations');
      for (var entry in _transportTypes.entries) {
        _stationCache[entry.key] = _stationService.locations
            .whereType<Station>()
            .where((s) => s.type == entry.value)
            .where((s) => _isValidCoordinate(LatLng(s.lat, s.lng)))
            .toList();
        debugPrint('Cached ${_stationCache[entry.key]!.length} ${entry.key} stations');
      }
    } catch (e) {
      debugPrint('Error loading stations: $e');
      _showError('station_load', 'Failed to load station data.');
    }

    _lastLocation = await _getCurrentLocation(silent: true);
  }

  void _toggleSelection(String tileName) {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 500) {
      debugPrint('Tap debounced: $tileName');
      return;
    }
    _lastTapTime = now;

    if (["Speedo", "Metro", "OrangeTrain"].contains(tileName) &&
        (_isLoadingSpeedo || _isLoadingMetro || _isLoadingOrange)) {
      debugPrint('Tap ignored: loading in progress for $tileName');
      return;
    }

    setState(() {
      if (tileName == "GetMeSomewhere") {
        if (_selectedTravelMode != tileName) {
          _clearRoute();
          _selectedTravelMode = tileName;
        } else {
          _selectedTravelMode = null;
        }
        debugPrint('Get Me Somewhere tapped');
        widget.onGetMeSomewhereTapped();
      } else if (tileName == "SeeAllRoutes") {
        if (_selectedTravelMode != tileName) {
          _clearRoute();
          _selectedTravelMode = tileName;
        } else {
          _selectedTravelMode = null;
        }
        debugPrint('See All Routes tapped');
        widget.onSeeAllRoutesTapped?.call();
      } else if (["Speedo", "Metro", "OrangeTrain"].contains(tileName)) {
        if (_selectedTravelMode == tileName) {
          _clearRoute();
          _selectedTravelMode = null;
        } else {
          _clearRoute();
          _selectedTravelMode = tileName;
          if (tileName == "Speedo") _isLoadingSpeedo = true;
          if (tileName == "Metro") _isLoadingMetro = true;
          if (tileName == "OrangeTrain") _isLoadingOrange = true;
          _showNearestStationRouteForMode(tileName);
        }
      }
    });
  }

  void _clearRoute() {
    debugPrint('Clearing route');
    widget.onUpdateRoute?.call({}, {}, null);
  }

  Future<void> _showNearestStationRouteForMode(String transportMode) async {
    if (widget.isNavigating) {
      _showError('navigating', 'Cannot display routes while navigation is active.');
      setState(() {
        if (transportMode == "Speedo") _isLoadingSpeedo = false;
        if (transportMode == "Metro") _isLoadingMetro = false;
        if (transportMode == "OrangeTrain") _isLoadingOrange = false;
      });
      return;
    }

    final currentLocation = widget.pickupLocation ?? await _getCurrentLocation();
    if (currentLocation == null) {
      _showError('location', 'Unable to determine your current location.');
      setState(() {
        if (transportMode == "Speedo") _isLoadingSpeedo = false;
        if (transportMode == "Metro") _isLoadingMetro = false;
        if (transportMode == "OrangeTrain") _isLoadingOrange = false;
      });
      return;
    }
    _lastLocation = currentLocation;
    debugPrint('Current location: $currentLocation');

    final type = _transportTypes[transportMode];
    if (type == null) {
      debugPrint('Invalid transport type for mode: $transportMode');
      _showError('invalid_mode', 'Invalid transport mode: $transportMode.');
      setState(() {
        if (transportMode == "Speedo") _isLoadingSpeedo = false;
        if (transportMode == "Metro") _isLoadingMetro = false;
        if (transportMode == "OrangeTrain") _isLoadingOrange = false;
      });
      return;
    }

    try {
      final stations = _stationCache[transportMode] ?? [];
      debugPrint('Using ${stations.length} cached stations for $transportMode');

      if (stations.isEmpty) {
        _showError('no_stations_$transportMode', 'No $transportMode stations found.');
        setState(() {
          if (transportMode == "Speedo") _isLoadingSpeedo = false;
          if (transportMode == "Metro") _isLoadingMetro = false;
          if (transportMode == "OrangeTrain") _isLoadingOrange = false;
        });
        return;
      }

      Station? nearestStation;
      double minDistance = double.infinity;

      for (var station in stations) {
        final stationLoc = LatLng(station.lat, station.lng);
        final distance = _navigationHelper.haversineDistance(currentLocation, stationLoc);
        if (distance < minDistance) {
          minDistance = distance;
          nearestStation = station;
        }
      }

      if (nearestStation == null) {
        _showError('no_near_station_$transportMode', 'No nearby $transportMode station found.');
        setState(() {
          if (transportMode == "Speedo") _isLoadingSpeedo = false;
          if (transportMode == "Metro") _isLoadingMetro = false;
          if (transportMode == "OrangeTrain") _isLoadingOrange = false;
        });
        return;
      }

      final stationLoc = LatLng(nearestStation.lat, nearestStation.lng);
      debugPrint('Nearest station: ${nearestStation.name} at $stationLoc');
      final cacheKey = '${currentLocation.latitude},${currentLocation.longitude}_${stationLoc.latitude},${stationLoc.longitude}';

      List<LatLng> points;
      if (_routeCache.containsKey(cacheKey)) {
        debugPrint('Using cached route for $cacheKey');
        points = _routeCache[cacheKey]!;
      } else if (!_fetchingRoutes.contains(cacheKey)) {
        _fetchingRoutes.add(cacheKey);
        final directionsService = DirectionsService();
        final route = await directionsService.getRoute(currentLocation, stationLoc);
        _fetchingRoutes.remove(cacheKey);

        if (route == null || route['points'] == null) {
          debugPrint('Route fetch failed for ${nearestStation.name}');
          _showError('route_failed_${nearestStation.name}', 'Failed to fetch route to ${nearestStation.name}.');
          setState(() {
            if (transportMode == "Speedo") _isLoadingSpeedo = false;
            if (transportMode == "Metro") _isLoadingMetro = false;
            if (transportMode == "OrangeTrain") _isLoadingOrange = false;
          });
          return;
        }

        points = route['points'] as List<LatLng>;
        if (points.isEmpty) {
          debugPrint('No valid route points for ${nearestStation.name}');
          _showError('empty_route_${nearestStation.name}', 'No route found to ${nearestStation.name}.');
          setState(() {
            if (transportMode == "Speedo") _isLoadingSpeedo = false;
            if (transportMode == "Metro") _isLoadingMetro = false;
            if (transportMode == "OrangeTrain") _isLoadingOrange = false;
          });
          return;
        }

        points = _limitPoints(points, 30);
        _routeCache[cacheKey] = points;
        debugPrint('Cached route for $cacheKey with ${points.length} points');

        if (_routeCache.length > 10) {
          final oldestKey = _routeCache.keys.first;
          _routeCache.remove(oldestKey);
          debugPrint('Evicted oldest cache entry: $oldestKey');
        }
      } else {
        debugPrint('Route fetch skipped: already fetching $cacheKey');
        setState(() {
          if (transportMode == "Speedo") _isLoadingSpeedo = false;
          if (transportMode == "Metro") _isLoadingMetro = false;
          if (transportMode == "OrangeTrain") _isLoadingOrange = false;
        });
        return;
      }

      final polyline = Polyline(
        polylineId: PolylineId('route_${nearestStation.name}'),
        points: points,
        color: Colors.red,
        width: 2,
        patterns: [PatternItem.dash(10), PatternItem.gap(5)],
        zIndex: 1,
      );

      final marker = Marker(
        markerId: MarkerId('station_${nearestStation.name}'),
        position: stationLoc,
        infoWindow: InfoWindow(title: nearestStation.name),
        icon: _iconManager.getIconForType(type) ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );

      debugPrint('Created polyline with ${points.length} points and marker for ${nearestStation.name}');

      if (widget.onUpdateRoute != null) {
        final bounds = _getBounds(points);
        widget.onUpdateRoute!({polyline}, {marker}, bounds);
        debugPrint('Called onUpdateRoute with 1 polyline, 1 marker, bounds: $bounds');
      } else {
        _showError('update_route', 'Unable to update map with route.');
      }
    } catch (e) {
      debugPrint('Error showing route for $transportMode: $e');
      _showError('route_error_$transportMode', 'Failed to display $transportMode route.');
    } finally {
      setState(() {
        if (transportMode == "Speedo") _isLoadingSpeedo = false;
        if (transportMode == "Metro") _isLoadingMetro = false;
        if (transportMode == "OrangeTrain") _isLoadingOrange = false;
      });
    }
  }

  void _showError(String key, String message) {
    if (_errorShown[key] == true || !mounted) return;
    _errorShown[key] = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<LatLng> _limitPoints(List<LatLng> points, int maxPoints) {
    if (points.length <= maxPoints) return points;
    final step = points.length ~/ maxPoints;
    final limitedPoints = <LatLng>[];
    for (int i = 0; i < points.length && limitedPoints.length < maxPoints; i += step) {
      limitedPoints.add(points[i]);
    }
    if (limitedPoints.last != points.last) {
      limitedPoints.add(points.last);
    }
    return limitedPoints;
  }

  Future<LatLng?> _getCurrentLocation({bool silent = false}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent) _showError('location_service', 'Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!silent) _showError('location_denied', 'Location permission denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!silent) _showError('location_denied_forever', 'Location permissions permanently denied.');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final location = LatLng(position.latitude, position.longitude);
      debugPrint('Got current location: $location');
      return location;
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (!silent) _showError('location_error', 'Failed to retrieve your location.');
      return null;
    }
  }

  static bool _isValidCoordinate(LatLng coord) {
    return coord.latitude != 0 &&
        coord.longitude != 0 &&
        coord.latitude >= 31.0 &&
        coord.latitude <= 32.0 &&
        coord.longitude >= 74.0 &&
        coord.longitude <= 75.0;
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

  @override
  Widget build(BuildContext context) {
    const Color redColor = Color(0xFFE20000);
    const Color greyColor = Color(0xFFC4C7C9);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, color: greyColor),
              onPressed: widget.onToggleVisibility,
              tooltip: 'Toggle Drawer',
            ),
          ),
          Container(
            width: MediaQuery.of(context).size.width - 64,
            height: 130,
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTile(
                  icon: Icons.search,
                  label: "Get Me\nSomewhere",
                  tileName: "GetMeSomewhere",
                  isSelected: _selectedTravelMode == 'GetMeSomewhere',
                  isLoading: _isLoadingSpeedo || _isLoadingMetro || _isLoadingOrange,
                  onTap: _toggleSelection,
                  redColor: redColor,
                  greyColor: greyColor,
                ),
                const SizedBox(width: 8),
                _buildTile(
                  icon: Icons.map,
                  label: "See All\nRoutes",
                  tileName: "SeeAllRoutes",
                  isSelected: _selectedTravelMode == 'SeeAllRoutes',
                  isLoading: _isLoadingSpeedo || _isLoadingMetro || _isLoadingOrange,
                  onTap: _toggleSelection,
                  redColor: redColor,
                  greyColor: greyColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Travel Mode',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: MediaQuery.of(context).size.width - 32,
                  height: 120,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTile(
                        icon: Icons.directions_bus,
                        label: "Speedo",
                        tileName: "Speedo",
                        isSelected: _selectedTravelMode == 'Speedo',
                        isLoading: _isLoadingSpeedo,
                        onTap: _toggleSelection,
                        redColor: redColor,
                        greyColor: greyColor,
                      ),
                      const SizedBox(width: 8),
                      _buildTile(
                        icon: Icons.subway,
                        label: "Metro",
                        tileName: "Metro",
                        isSelected: _selectedTravelMode == 'Metro',
                        isLoading: _isLoadingMetro,
                        onTap: _toggleSelection,
                        redColor: redColor,
                        greyColor: greyColor,
                      ),
                      const SizedBox(width: 8),
                      _buildTile(
                        icon: Icons.train,
                        label: "Orange Train",
                        tileName: "OrangeTrain",
                        isSelected: _selectedTravelMode == 'OrangeTrain',
                        isLoading: _isLoadingOrange,
                        onTap: _toggleSelection,
                        redColor: redColor,
                        greyColor: greyColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    required String tileName,
    required bool isSelected,
    required bool isLoading,
    required Function(String) onTap,
    required Color redColor,
    required Color greyColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(tileName),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? redColor : greyColor,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 30,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      overflow: TextOverflow.ellipsis,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
              if (isLoading && ["Speedo", "Metro", "OrangeTrain"].contains(tileName))
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
            ],
          ),
        ),
      ),
    );
  }
}