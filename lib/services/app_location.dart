abstract class AppLocation {
  String get name;
  String get type;
  double get lat;
  double get lng;
}

class Location implements AppLocation {
  @override
  final String name;
  @override
  final String type;
  @override
  final double lat;
  @override
  final double lng;

  Location({
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
  });

  factory Location.fromJson(Map<String, dynamic> json) => Location(
    name: json['name'],
    type: json['type'],
    lat: json['lat'].toDouble(),
    lng: json['lng'].toDouble(),
  );
}