import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/app_location.dart';
import '../services/location_service.dart';

class SearchBarWidget extends StatefulWidget {
  final List<AppLocation> locations;
  final LatLng? pickupLocation;
  final String pickupText;
  final LatLng? destinationLocation;
  final String destinationText;
  final Function(LatLng, String) onPickupChanged;
  final Function(LatLng?, String) onDestinationChanged;
  final VoidCallback onCommute;
  final LocationService locationService;

  const SearchBarWidget({
    super.key,
    required this.locations,
    required this.pickupLocation,
    required this.pickupText,
    required this.destinationLocation,
    required this.destinationText,
    required this.onPickupChanged,
    required this.onDestinationChanged,
    required this.onCommute,
    required this.locationService,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();
  List<AppLocation> _pickupSuggestions = [];
  List<AppLocation> _destinationSuggestions = [];
  bool _showPickupSuggestions = false;
  bool _showDestinationSuggestions = false;
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 [INFO] SearchBarWidget initialized');
    _pickupController.text = widget.pickupText;
    _destinationController.text = widget.destinationText;

    _pickupController.addListener(_onPickupTextChanged);
    _destinationController.addListener(_onDestinationTextChanged);

    _pickupFocusNode.addListener(() {
      if (_pickupFocusNode.hasFocus) {
        setState(() {
          _showPickupSuggestions = _pickupSuggestions.isNotEmpty || _pickupController.text.isNotEmpty;
          _showDestinationSuggestions = false;
        });
        debugPrint('🔍 [INFO] Pickup field focused');
      }
    });

    _destinationFocusNode.addListener(() {
      if (_destinationFocusNode.hasFocus) {
        setState(() {
          _showDestinationSuggestions = _destinationSuggestions.isNotEmpty || _destinationController.text.isNotEmpty;
          _showPickupSuggestions = false;
        });
        debugPrint('🔍 [INFO] Destination field focused');
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pickupController.dispose();
    _destinationController.dispose();
    _pickupFocusNode.dispose();
    _destinationFocusNode.dispose();
    debugPrint('🧹 [INFO] SearchBarWidget disposed');
    super.dispose();
  }

  void _onPickupTextChanged() {
    final query = _pickupController.text.toLowerCase();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      debugPrint('🔍 [INFO] Pickup query: $query');
      if (query.isEmpty) {
        setState(() {
          _pickupSuggestions = widget.locations
              .where((loc) => !loc.name.toLowerCase().contains('speedo') && !loc.name.toLowerCase().contains('orange'))
              .take(5)
              .toList();
          _showPickupSuggestions = _pickupFocusNode.hasFocus;
        });
        debugPrint('✅ [INFO] Pickup suggestions cleared, showing top 5: ${_pickupSuggestions.length}');
        return;
      }

      final prefixMatches = widget.locations
          .where((loc) =>
      loc.name.toLowerCase().startsWith(query) &&
          !loc.name.toLowerCase().contains('speedo') &&
          !loc.name.toLowerCase().contains('orange'))
          .toList();
      final containsMatches = widget.locations
          .where((loc) =>
      loc.name.toLowerCase().contains(query) &&
          !loc.name.toLowerCase().startsWith(query) &&
          !loc.name.toLowerCase().contains('speedo') &&
          !loc.name.toLowerCase().contains('orange'))
          .toList();
      setState(() {
        _pickupSuggestions = [...prefixMatches, ...containsMatches].take(10).toList();
        _showPickupSuggestions = true;
      });
      debugPrint('✅ [INFO] Pickup suggestions updated: ${_pickupSuggestions.length}');
      if (_pickupSuggestions.isEmpty) {
        debugPrint('ℹ️ [INFO] No pickup suggestions found for query: $query');
      }
    });
  }

  void _onDestinationTextChanged() {
    final query = _destinationController.text.toLowerCase();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      debugPrint('🔍 [INFO] Destination query: $query');
      if (query.isEmpty) {
        setState(() {
          _destinationSuggestions = widget.locations
              .where((loc) => !loc.name.toLowerCase().contains('speedo') && !loc.name.toLowerCase().contains('orange'))
              .take(5)
              .toList();
          _showDestinationSuggestions = _destinationFocusNode.hasFocus;
        });
        debugPrint('✅ [INFO] Destination suggestions cleared, showing top 5: ${_destinationSuggestions.length}');
        return;
      }

      final prefixMatches = widget.locations
          .where((loc) =>
      loc.name.toLowerCase().startsWith(query) &&
          !loc.name.toLowerCase().contains('speedo'))
          .toList();
      final containsMatches = widget.locations
          .where((loc) =>
      loc.name.toLowerCase().contains(query) &&
          !loc.name.toLowerCase().startsWith(query) &&
          !loc.name.toLowerCase().contains('speedo') &&
          !loc.name.toLowerCase().contains('orange'))
          .toList();
      setState(() {
        _destinationSuggestions = [...prefixMatches, ...containsMatches].take(10).toList();
        _showDestinationSuggestions = true;
      });
      debugPrint('✅ [INFO] Destination suggestions updated: ${_destinationSuggestions.length}');
      if (_destinationSuggestions.isEmpty) {
        debugPrint('ℹ️ [INFO] No destination suggestions found for query: $query');
      }
    });
  }

  void _selectPickup(AppLocation location) {
    setState(() {
      _pickupController.text = location.name;
      _showPickupSuggestions = false;
      _pickupFocusNode.unfocus();
    });
    widget.onPickupChanged(
      LatLng(location.lat, location.lng),
      location.name,
    );
    debugPrint('✅ [INFO] Pickup selected: ${location.name} (${location.lat}, ${location.lng})');
  }

  void _selectDestination(AppLocation location) {
    setState(() {
      _destinationController.text = location.name;
      _showDestinationSuggestions = false;
      _destinationFocusNode.unfocus();
    });
    widget.onDestinationChanged(
      LatLng(location.lat, location.lng),
      location.name,
    );
    debugPrint('✅ [INFO] Destination selected: ${location.name} (${location.lat}, ${location.lng})');
  }

  void _clearPickup() {
    setState(() {
      _pickupController.clear();
      _pickupSuggestions = widget.locations
          .where((loc) => !loc.name.toLowerCase().contains('speedo') && !loc.name.toLowerCase().contains('orange'))
          .take(5)
          .toList();
      _showPickupSuggestions = _pickupFocusNode.hasFocus;
      _pickupFocusNode.unfocus();
    });
    widget.onPickupChanged(
      widget.pickupLocation ?? const LatLng(31.5, 74.42), // Corrected default
      '',
    );
    debugPrint('🗑️ [INFO] Pickup cleared');
  }

  void _clearDestination() {
    setState(() {
      _destinationController.clear();
      _destinationSuggestions = widget.locations
          .where((loc) => !loc.name.toLowerCase().contains('speedo') && !loc.name.toLowerCase().contains('orange'))
          .take(5)
          .toList();
      _showDestinationSuggestions = _destinationFocusNode.hasFocus;
      _destinationFocusNode.unfocus();
    });
    widget.onDestinationChanged(null, '');
    debugPrint('🗑️ [INFO] Destination cleared');
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final location = await widget.locationService.getCurrentLocation(context);
      if (location != null && mounted) {
        setState(() {
          _pickupController.text = 'My Location';
          _showPickupSuggestions = false;
          _pickupFocusNode.unfocus();
        });
        widget.onPickupChanged(location, 'My Location');
        debugPrint('✅ [INFO] Current location set as pickup: $location');
      } else {
        debugPrint('ℹ️ [INFO] No location returned from LocationService');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
        debugPrint('❌ [ERROR] Failed to get current location: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withOpacity(0.1), width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pickup Text Field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _pickupController,
                        focusNode: _pickupFocusNode,
                        decoration: const InputDecoration(
                          hintText: 'Enter pickup location',
                          hintStyle: TextStyle(color: Colors.grey, fontFamily: 'Outfit', fontSize: 14),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Colors.black),
                        onTap: () {
                          if (_pickupController.text == 'My Location') {
                            _getCurrentLocation();
                          }
                        },
                      ),
                    ),
                    if (_pickupController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                        onPressed: _clearPickup,
                      ),
                    if (_isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.gps_fixed, color: Colors.redAccent, size: 18),
                        onPressed: _getCurrentLocation,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Destination Text Field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _destinationController,
                        focusNode: _destinationFocusNode,
                        decoration: const InputDecoration(
                          hintText: 'Enter destination',
                          hintStyle: TextStyle(color: Colors.grey, fontFamily: 'Outfit', fontSize: 14),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Colors.black),
                      ),
                    ),
                    if (_destinationController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                        onPressed: _clearDestination,
                      ),
                  ],
                ),
              ),
              if (_showPickupSuggestions)
                AnimatedOpacity(
                  opacity: _showPickupSuggestions ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: _pickupSuggestions.isEmpty
                      ? _buildEmptySuggestions('No pickup locations found')
                      : _buildSuggestions(_pickupSuggestions, _selectPickup),
                ),
              if (_showDestinationSuggestions)
                AnimatedOpacity(
                  opacity: _showDestinationSuggestions ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: _destinationSuggestions.isEmpty
                      ? _buildEmptySuggestions('No destination locations found')
                      : _buildSuggestions(_destinationSuggestions, _selectDestination),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onCommute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Get Me Somewhere',
                    style: TextStyle(fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(List<AppLocation> suggestions, Function(AppLocation) onSelect) {
    debugPrint('ℹ️ [INFO] Rendering ${suggestions.length} suggestions');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final location = suggestions[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(
                location.name,
                style: const TextStyle(
                  color: Colors.black,
                  fontFamily: 'Outfit',
                  fontSize: 14,
                ),
              ),
              onTap: () => onSelect(location),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptySuggestions(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.grey,
            fontFamily: 'Outfit',
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}