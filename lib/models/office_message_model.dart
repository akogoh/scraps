class OfficeMessage {
  final String id;
  final String senderId;
  final String senderType; // 'admin' | 'field_officer'
  final String recipientId;
  final String recipientType;
  final String content;
  final String? imageUrl;
  final bool isRead;
  final DateTime createdAt;

  OfficeMessage({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.recipientId,
    required this.recipientType,
    required this.content,
    this.imageUrl,
    this.isRead = false,
    required this.createdAt,
  });

  factory OfficeMessage.fromJson(Map<String, dynamic> json) {
    return OfficeMessage(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderType: json['sender_type']?.toString() ?? 'admin',
      recipientId: json['recipient_id']?.toString() ?? '',
      recipientType: json['recipient_type']?.toString() ?? 'admin',
      content: json['content']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      isRead: json['is_read'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }
}

/// Represents a conversation with another team member (for list view).
class OfficeConversation {
  final String otherId;
  final String otherType; // 'admin' | 'field_officer'
  final String otherName;
  final String? lastContent;
  final DateTime? lastAt;
  final int unreadCount;

  OfficeConversation({
    required this.otherId,
    required this.otherType,
    required this.otherName,
    this.lastContent,
    this.lastAt,
    this.unreadCount = 0,
  });
}
