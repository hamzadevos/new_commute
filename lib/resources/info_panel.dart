import 'package:new_commute/services/stations.dart';
import 'package:flutter/material.dart';

class InfoPanel extends StatelessWidget {
  final bool isVisible;
  final Station? nearestStation;
  final double? distance;
  final int selectedIndex;
  final String destinationText;
  final VoidCallback onStopNavigation;

  const InfoPanel({
    super.key,
    required this.isVisible,
    required this.nearestStation,
    required this.distance,
    required this.selectedIndex,
    required this.destinationText,
    required this.onStopNavigation,
  });

  String _estimateTravelTime(double distance, String mode) {
    double speed = mode == 'SpeedoBus' ? 20 : mode == 'MetroBus' ? 30 : 40;
    double timeHours = distance / speed;
    int timeMinutes = (timeHours * 60).round();
    return timeMinutes == 0 ? '1 min' : '$timeMinutes min';
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || nearestStation == null) {
      return const SizedBox.shrink();
    }

    String mode = selectedIndex == 2
        ? 'SpeedoBus'
        : selectedIndex == 3
        ? 'MetroBus'
        : selectedIndex == 4
        ? 'OrangeTrain'
        : 'Not Selected';
    String distanceText = distance?.toStringAsFixed(1) ?? '--';
    String eta = mode != 'Not Selected' && distance != null
        ? _estimateTravelTime(distance!, mode)
        : '--';

    return Positioned(
      bottom: 50,
      left: 16,
      right: 16,
      child: Column(
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Commute Info',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Nearest Station:', style: TextStyle(fontFamily: 'Outfit')),
                      Text(nearestStation!.name, style: const TextStyle(fontFamily: 'Outfit')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Distance to Station:', style: TextStyle(fontFamily: 'Outfit')),
                      Text('$distanceText km', style: const TextStyle(fontFamily: 'Outfit')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mode:', style: TextStyle(fontFamily: 'Outfit')),
                      Text(mode, style: const TextStyle(fontFamily: 'Outfit')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estimated Time:', style: TextStyle(fontFamily: 'Outfit')),
                      Text(eta, style: const TextStyle(fontFamily: 'Outfit')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Destination:', style: TextStyle(fontFamily: 'Outfit')),
                      Text(destinationText, style: const TextStyle(fontFamily: 'Outfit')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onStopNavigation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Stop Navigation',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}