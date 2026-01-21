// lib/features/go_to/models/customer_model.dart

class CustomerModel {
  final String id;
  final String name;
  final String shopName;
  final String shopAddress;
  final List<String> contacts;
  final CustomerLocation? location;

  CustomerModel({
    required this.id,
    required this.name,
    required this.shopName,
    required this.shopAddress,
    required this.contacts,
    this.location,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      shopName: json['shopName']?.toString() ?? '',
      shopAddress: json['shopAddress']?.toString() ?? '',
      contacts: (json['contacts'] as List?)
              ?.map((c) => c.toString())
              .toList() ??
          [],
      location: json['location'] != null
          ? CustomerLocation.fromJson(json['location'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'shopName': shopName,
      'shopAddress': shopAddress,
      'contacts': contacts,
      'location': location?.toJson(),
    };
  }

  String get displayName => '$name - $shopName';
  String? get primaryContact => contacts.isNotEmpty ? contacts.first : null;
}

class CustomerLocation {
  final double? latitude;
  final double? longitude;

  CustomerLocation({
    this.latitude,
    this.longitude,
  });

  factory CustomerLocation.fromJson(Map<String, dynamic> json) {
    return CustomerLocation(
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  bool get isValid => latitude != null && longitude != null;
}