import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/stations.dart';
import 'navigation_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CommuteServiceDialog {
  static Future<Map<String, dynamic>?> show(
      BuildContext context, {
        required LatLng? pickupLocation,
        required LatLng? destinationLocation,
        required String pickupText,
        required String destinationText,
        required List<Station> stations,
        required NavigationHelper navigationHelper,
        required String googleApiKey,
      }) async {
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
      return null;
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        final fontScale = 0.85;
        final transportTypes = [
          {'type': 'SpeedoBus', 'logo': 'assets/speedo.png'},
          {'type': 'MetroBus', 'logo': 'assets/metro.png'},
          {'type': 'OrangeTrain', 'logo': 'assets/train.png'},
        ];

        return AlertDialog(
          backgroundColor: Colors.grey[200],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: EdgeInsets.all(screenSize.width * 0.04),
          content: SingleChildScrollView(
            child: Container(
              width: screenSize.width * 0.85,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commute Services',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18 * fontScale,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  SizedBox(height: screenSize.height * 0.015),
                  ...transportTypes.map((transport) {
                    final type = transport['type'] as String;
                    final logo = transport['logo'] as String;
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: nearestStation != null
                                    ? () {
                                  debugPrint('Start tapped, unfocusing keyboard');
                                  FocusScope.of(context).unfocus();
                                  Navigator.pop(context, {
                                    'type': type,
                                    'station': LatLng(nearestStation.lat, nearestStation.lng),
                                    'stationName': nearestStation.name,
                                    'destination': destinationLocation,
                                    'action': 'start',
                                  });
                                }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenSize.width * 0.04,
                                    vertical: screenSize.height * 0.01,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Start',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 12 * fontScale,
                                  ),
                                ),
                              ),
                            ],
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