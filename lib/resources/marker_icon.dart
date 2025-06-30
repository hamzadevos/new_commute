import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;

class MarkerIconManager {
  BitmapDescriptor? myLocationIcon;
  BitmapDescriptor? destinationIcon;
  BitmapDescriptor? speedoIcon;
  BitmapDescriptor? metroIcon;
  BitmapDescriptor? trainIcon;

  Future<void> loadIcons(BuildContext context) async {
    try {
      myLocationIcon = await _createBitmapDescriptor(context, Icons.my_location, Colors.blue, 40);
      destinationIcon = await _createBitmapDescriptor(context, Icons.location_pin, Colors.redAccent, 40);
      speedoIcon = await _createBitmapDescriptor(context, Icons.directions_bus, Colors.redAccent, 40);
      metroIcon = await _createBitmapDescriptor(context, Icons.directions_bus_filled, Colors.redAccent, 40);
      trainIcon = await _createBitmapDescriptor(context, Icons.train, Colors.redAccent, 40);
      debugPrint('All icons loaded successfully');
    } catch (e) {
      debugPrint('Error loading icons: $e');
      myLocationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      destinationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      speedoIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      metroIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      trainIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  Future<BitmapDescriptor> _createBitmapDescriptor(BuildContext context, IconData iconData, Color color, double size) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final iconStr = String.fromCharCode(iconData.codePoint);
    textPainter.text = TextSpan(
      text: iconStr,
      style: TextStyle(
        fontFamily: iconData.fontFamily,
        fontSize: size,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  BitmapDescriptor? getIconForType(String type) {
    switch (type) {
      case 'SpeedoBus':
        return speedoIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'MetroBus':
        return metroIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'OrangeTrain':
        return trainIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'Station':
        return metroIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      default:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }
}