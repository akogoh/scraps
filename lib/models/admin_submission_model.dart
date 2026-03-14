class AdminSubmission {
  final String id;
  final String itemName;
  final String comments;
  final String status;
  final DateTime submittedAt;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String userName;
  final String phoneNumber;
  final String? imageUrl;
  final String? videoUrl;
  final String? adminCollectionImageUrl;
  final String? adminNotes;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final int messageCount;
  final double price;
  final DateTime? collectionDate;
  final String? assignedOfficerId;
  final DateTime? assignedAt;
  final String? assignedBy;

  AdminSubmission({
    required this.id,
    required this.itemName,
    required this.comments,
    required this.status,
    required this.submittedAt,
    this.latitude,
    this.longitude,
    this.address,
    required this.userName,
    required this.phoneNumber,
    this.imageUrl,
    this.videoUrl,
    this.adminCollectionImageUrl,
    this.adminNotes,
    this.reviewedBy,
    this.reviewedAt,
    required this.messageCount,
    this.price = 0,
    this.collectionDate,
    this.assignedOfficerId,
    this.assignedAt,
    this.assignedBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_name': itemName,
      'comments': comments,
      'status': status,
      'submitted_at': submittedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'user_name': userName,
      'phone_number': phoneNumber,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'admin_collection_image_url': adminCollectionImageUrl,
      'admin_notes': adminNotes,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'message_count': messageCount,
      'price': price,
      'collection_date': collectionDate?.toIso8601String(),
      'assigned_officer_id': assignedOfficerId,
      'assigned_at': assignedAt?.toIso8601String(),
      'assigned_by': assignedBy,
    };
  }

  factory AdminSubmission.fromJson(Map<String, dynamic> json) {
    return AdminSubmission(
      id: json['id'].toString(),
      itemName: json['item_name'],
      comments: json['comments'] ?? '',
      status: json['status'],
      submittedAt: DateTime.parse(json['submitted_at']),
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      address: json['address'],
      userName: json['user_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      imageUrl: json['image_url'],
      videoUrl: json['video_url'],
      adminCollectionImageUrl: json['admin_collection_image_url'],
      adminNotes: json['admin_notes'],
      reviewedBy: json['reviewed_by'],
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'])
          : null,
      messageCount: json['message_count'] ?? 0,
      price: (json['price'] is int)
          ? (json['price'] as int).toDouble()
          : (json['price'] as num?)?.toDouble() ?? 0.0,
      collectionDate: json['collection_date'] != null
          ? DateTime.parse(json['collection_date'])
          : null,
      assignedOfficerId: json['assigned_officer_id']?.toString(),
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'])
          : null,
      assignedBy: json['assigned_by']?.toString(),
    );
  }
}
