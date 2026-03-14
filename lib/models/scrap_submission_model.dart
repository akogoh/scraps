class ScrapSubmission {
  final String id;
  final String userId;
  final String phoneNumber;
  final String itemName;
  final String? imageUrl;
  final String? videoUrl;
  final String comments;
  final DateTime submittedAt;
  final String status; // pending, reviewed, approved, rejected
  final double? latitude;
  final double? longitude;
  final String? address;
  final DateTime? collectionDate;
  final double price; // in Ghana Cedis (GH¢)
  final bool isSelling; // true: selling, false: donating
  final String? assignedOfficerId;
  final String? assignedOfficerName;
  final DateTime? assignedAt;
  final String? paymentPhoneNumber;

  ScrapSubmission({
    required this.id,
    required this.userId,
    required this.phoneNumber,
    required this.itemName,
    this.imageUrl,
    this.videoUrl,
    required this.comments,
    required this.submittedAt,
    this.status = 'pending',
    this.latitude,
    this.longitude,
    this.address,
    this.collectionDate,
    this.price = 0,
    this.isSelling = true,
    this.assignedOfficerId,
    this.assignedOfficerName,
    this.assignedAt,
    this.paymentPhoneNumber,
  });

  Map<String, dynamic> toJson() {
    // Note: assigned_officer_name is NOT a database column - it's computed when reading
    // assigned_at is a DB column but new submissions won't have it, so we omit it
    final json = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'phone_number': phoneNumber,
      'item_name': itemName,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'comments': comments,
      'submitted_at': submittedAt.toIso8601String(),
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'collection_date': collectionDate?.toIso8601String(),
      'price': price,
      'is_selling': isSelling,
    };

    // Only include assigned_officer_id if it's not null (new submissions won't have this)
    if (assignedOfficerId != null) {
      json['assigned_officer_id'] = assignedOfficerId;
    }

    // Include payment_phone_number if provided
    if (paymentPhoneNumber != null) {
      json['payment_phone_number'] = paymentPhoneNumber;
    }

    // Do NOT include assigned_officer_name - it's not a DB column, computed when reading
    // Do NOT include assigned_at - new submissions won't have this

    return json;
  }

  factory ScrapSubmission.fromJson(Map<String, dynamic> json) {
    return ScrapSubmission(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      phoneNumber: json['phone_number'].toString(),
      itemName: json['item_name'].toString(),
      imageUrl: json['image_url']?.toString(),
      videoUrl: json['video_url']?.toString(),
      comments: json['comments']?.toString() ?? '',
      submittedAt: DateTime.parse(json['submitted_at']),
      status: json['status']?.toString() ?? 'pending',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      address: json['address']?.toString(),
      collectionDate: json['collection_date'] != null
          ? DateTime.parse(json['collection_date'])
          : null,
      price: (json['price'] is int)
          ? (json['price'] as int).toDouble()
          : (json['price'] as num?)?.toDouble() ?? 0.0,
      isSelling: json['is_selling'] ?? true,
      assignedOfficerId: json['assigned_officer_id']?.toString(),
      assignedOfficerName: json['assigned_officer_name']?.toString(),
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'])
          : null,
      paymentPhoneNumber: json['payment_phone_number']?.toString(),
    );
  }
}
