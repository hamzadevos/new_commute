import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/stations.dart';
import 'navigation_manager.dart';

class CommuteServiceDialog {
  static void show(
      BuildContext context, {
        required LatLng? pickupLocation,
        required LatLng? destinationLocation,
        required String pickupText,
        required String destinationText,
        required List<Station> stations,
        required NavigationHelper navigationHelper,
      }) {
    if (pickupLocation == null || destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select both pickup and destination.',
            style: TextStyle(fontFamily: 'Outfit'),
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        final fontScale = 0.85; // ~15% smaller elements
        final transportTypes = [
          {'type': 'SpeedoBus', 'logo': 'assets/speedo.png'},
          {'type': 'MetroBus', 'logo': 'assets/metro.png'},
          {'type': 'OrangeTrain', 'logo': 'assets/train.png'},
        ];

        return AlertDialog(
          backgroundColor: Colors.grey[200],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // Reduced from 12
          ),
          contentPadding: EdgeInsets.all(screenSize.width * 0.04),
          content: SingleChildScrollView(
            child: Container(
              width: screenSize.width * 0.85, // Responsive width
              constraints: BoxConstraints(
                maxHeight: screenSize.height * 0.6, // Adjusted for content
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commuter Services',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18 * fontScale,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  SizedBox(height: screenSize.height * 0.015),
                  ...transportTypes.map((transport) {
                    final type = transport['type']!;
                    final logo = transport['logo']!;
                    final nearestStation = navigationHelper.findNearestStation(
                      pickupLocation,
                      stations,
                      type: type,
                    );
                    final distance = nearestStation != null
                        ? navigationHelper.haversineDistance(
                      pickupLocation,
                      LatLng(nearestStation.lat, nearestStation.lng),
                    )
                        : 0.0;
                    return Padding(
                      padding: EdgeInsets.only(bottom: screenSize.height * 0.015),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.asset(
                                logo,
                                width: 30 * fontScale,
                                height: 30 * fontScale,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.error,
                                  size: 30 * fontScale,
                                  color: Colors.redAccent,
                                ),
                              ),
                              SizedBox(width: screenSize.width * 0.03),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      type,
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 14 * fontScale,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xff022E57),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    Text(
                                      nearestStation != null
                                          ? 'Nearest: ${nearestStation.name} (${distance.toStringAsFixed(1)} km)'
                                          : 'No stations available',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 12 * fontScale,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: screenSize.height * 0.01),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: nearestStation != null
                                  ? () async {
                                Navigator.pop(context);
                                await navigationHelper.launchGoogleMaps(
                                  context,
                                  pickupLocation,
                                  LatLng(nearestStation.lat, nearestStation.lng),
                                  'walking',
                                  pickupText,
                                  nearestStation.name,
                                );
                                await navigationHelper.launchGoogleMaps(
                                  context,
                                  LatLng(nearestStation.lat, nearestStation.lng),
                                  destinationLocation,
                                  'transit',
                                  nearestStation.name,
                                  destinationText,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Navigating with $type to $destinationText',
                                        style: const TextStyle(fontFamily: 'Outfit'),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenSize.width * 0.04,
                                  vertical: screenSize.height * 0.015,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Navigate To',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12 * fontScale,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  SizedBox(height: screenSize.height * 0.015),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14 * fontScale,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}