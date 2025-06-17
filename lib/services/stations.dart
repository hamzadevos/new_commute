import 'app_location.dart';

class Station implements AppLocation {
  final String id;
  @override
  final String name;
  @override
  final double lat;
  @override
  final double lng;
  @override
  final String type;

  Station({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      lat: (json['lat'] is num) ? json['lat'].toDouble() : 0.0,
      lng: (json['lng'] is num) ? json['lng'].toDouble() : 0.0,
      type: json['type']?.toString() ?? '',
    );
  }

  @override
  String toString() {
    return 'Station(id: $id, name: $name, lat: $lat, lng: $lng, type: $type)';
  }
}