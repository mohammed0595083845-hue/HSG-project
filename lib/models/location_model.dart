import 'dart:math';

class LocationModel {
  final String locationId;
  final double latitude;
  final double longitude;
  final String address;

  const LocationModel({
    required this.locationId,
    required this.latitude,
    required this.longitude,
    this.address = '',
  });

  /// getLocation() من الداياجرام
  LocationModel getLocation() => this;

  Map<String, dynamic> toMap() => {
    'locationId': locationId,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
  };

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      locationId: map['locationId'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      address: map['address'] as String? ?? '',
    );
  }
}
