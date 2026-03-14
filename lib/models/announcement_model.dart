class Announcement {
  final String id;
  final String title;
  final String body;
  final String type; // announcement, deal, info, urgent
  final String? imageUrl;
  final String? linkUrl;
  final int priority;
  final DateTime createdAt;
  final DateTime? expiresAt;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'announcement',
    this.imageUrl,
    this.linkUrl,
    this.priority = 0,
    required this.createdAt,
    this.expiresAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? 'announcement',
      imageUrl: json['image_url']?.toString(),
      linkUrl: json['link_url']?.toString(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
    );
  }

  bool get isDeal => type == 'deal';
  bool get isUrgent => type == 'urgent';
}
