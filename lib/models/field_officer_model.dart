class FieldOfficer {
  final String id;
  final String name;
  final String? phone;
  final String? phoneNumber;
  final String? password;
  final String? email;
  final String? photoUrl;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final double? latitude;
  final double? longitude;
  final DateTime? lastLocationUpdate;
  final double? coverageRadiusKm;

  FieldOfficer({
    required this.id,
    required this.name,
    this.phone,
    this.phoneNumber,
    this.password,
    this.email,
    this.photoUrl,
    this.imageUrl,
    required this.isActive,
    required this.createdAt,
    this.lastLogin,
    this.latitude,
    this.longitude,
    this.lastLocationUpdate,
    this.coverageRadiusKm,
  });

  /// Preferred photo URL: photo_url if set, else image_url
  String? get displayPhotoUrl => photoUrl ?? imageUrl;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'phone_number': phoneNumber,
      'password': password,
      'email': email,
      'photo_url': photoUrl,
      'image_url': imageUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'last_location_update': lastLocationUpdate?.toIso8601String(),
      'coverage_radius_km': coverageRadiusKm,
    };
  }

  factory FieldOfficer.fromJson(Map<String, dynamic> json) {
    return FieldOfficer(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      password: json['password']?.toString(),
      email: json['email']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      imageUrl: json['image_url']?.toString(),
      isActive: json['is_active'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      lastLogin: json['last_login'] != null
          ? DateTime.tryParse(json['last_login'].toString())
          : null,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      lastLocationUpdate: json['last_location_update'] != null
          ? DateTime.tryParse(json['last_location_update'].toString())
          : null,
      coverageRadiusKm: _toDouble(json['coverage_radius_km']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
