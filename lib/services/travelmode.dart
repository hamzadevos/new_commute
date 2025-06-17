import 'dart:math';

import 'package:flutter/material.dart';
import '../screens/mapscreen.dart';

class TravelModeWidget extends StatefulWidget {
  final VoidCallback onGetMeSomewhereTapped;
  final VoidCallback? onToggleVisibility;
  final MapScreenState? mapScreenState;

  const TravelModeWidget({
    super.key,
    required this.onGetMeSomewhereTapped,
    this.onToggleVisibility,
    this.mapScreenState,
  });

  @override
  _TravelModeWidgetState createState() => _TravelModeWidgetState();
}

class _TravelModeWidgetState extends State<TravelModeWidget> {
  final List<String> _selectedTiles = [];

  void _toggleSelection(String tileName) {
    setState(() {
      if (_selectedTiles.contains(tileName)) {
        _selectedTiles.remove(tileName);
        _selectedTimes.remove(tileName); // Remove its time
      } else if (_selectedTiles.length < 2) {
        _selectedTiles.add(tileName);
        _selectedTimes[tileName] = _pickRandomTime(tileName);
      } else {
        // Remove the first selected tile
        final removed = _selectedTiles.removeAt(0);
        _selectedTimes.remove(removed);
        _selectedTiles.add(tileName);
        _selectedTimes[tileName] = _pickRandomTime(tileName);
      }

      if (tileName == "GetMeSomewhere") {
        widget.onGetMeSomewhereTapped();
      } else if (tileName == "SeeAllRoutes" && widget.mapScreenState != null) {
        widget.mapScreenState!.showNearestStationRoutes();
      }
    });
  }

  String _pickRandomTime(String tileName) {
    final options = _travelTimeOptions[tileName];
    if (options == null || options.isEmpty) return '';
    final rand = Random();
    return options[rand.nextInt(options.length)];
  }


  final Map<String, List<String>> _travelTimeOptions = {
    'Speedo': ['9 min', '10 min', '11 min', '12 min', '13 min'],
    'Metro': ['15 min', '16 min', '17 min', '18 min', '19 min'],
    'OrangeTrain': ['24 min', '25 min', '26 min', '27 min', '28 min'],
  };

  final Map<String, String> _selectedTimes = {}; // Stores the current picked time for each selected tile



  @override
  Widget build(BuildContext context) {
    const Color redColor = Color(0xFFE20000);
    const Color greyColor = Color(0xFFC4C4C9);

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
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
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
                  isSelected: _selectedTiles.contains("GetMeSomewhere"),
                  onTap: _toggleSelection,
                  redColor: redColor,
                  greyColor: greyColor,
                ),
                const SizedBox(width: 8),
                _buildTile(
                  icon: Icons.map,
                  label: "See All\nRoutes",
                  tileName: "SeeAllRoutes",
                  isSelected: _selectedTiles.contains("SeeAllRoutes"),
                  onTap: _toggleSelection,
                  redColor: redColor,
                  greyColor: greyColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Travel Mode",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: MediaQuery.of(context).size.width - 64,
                  height: 120,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTile(
                        icon: Icons.directions_bus,
                        label: "Speedo",
                        tileName: "Speedo",
                        isSelected: _selectedTiles.contains("Speedo"),
                        onTap: _toggleSelection,
                        redColor: redColor,
                        greyColor: greyColor,
                        timeLabel: _selectedTimes['Speedo'], // Updated
                      ),

                      const SizedBox(width: 8),
                      _buildTile(
                        icon: Icons.subway,
                        label: "Metro",
                        tileName: "Metro",
                        isSelected: _selectedTiles.contains("Metro"),
                        onTap: _toggleSelection,
                        redColor: redColor,
                        greyColor: greyColor,
                        timeLabel: _selectedTimes['Metro'],
                      ),
                      const SizedBox(width: 8),
                      _buildTile(
                        icon: Icons.train,
                        label: "Orange Train",
                        tileName: "OrangeTrain",
                        isSelected: _selectedTiles.contains("OrangeTrain"),
                        onTap: _toggleSelection,
                        redColor: redColor,
                        greyColor: greyColor,
                        timeLabel: _selectedTimes['OrangeTrain'],
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
    required Function(String) onTap,
    required Color redColor,
    required Color greyColor,
    String? timeLabel, // NEW
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(tileName),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? redColor : greyColor,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
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
              if (isSelected && timeLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  timeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}