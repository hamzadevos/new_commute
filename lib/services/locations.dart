class Location {
  final String name;
  final String type;
  final double lat;
  final double lng;

  Location({required this.name, required this.type, required this.lat, required this.lng});

  factory Location.fromJson(Map<String, dynamic> json) => Location(
    name: json['name'],
    type: json['type'],
    lat: json['lat'].toDouble(),
    lng: json['lng'].toDouble(),
  );
}