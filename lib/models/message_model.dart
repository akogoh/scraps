class Message {
  final String id;
  final String submissionId;
  final String senderId;
  final String content;
  final bool isAdminMessage;
  final bool isRead;
  final DateTime createdAt;
  final String? imageUrl;

  Message({
    required this.id,
    required this.submissionId,
    required this.senderId,
    required this.content,
    this.isAdminMessage = false,
    this.isRead = false,
    required this.createdAt,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'submission_id': submissionId,
      'sender_id': senderId,
      'content': content,
      'is_admin_message': isAdminMessage,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'image_url': imageUrl,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      submissionId: json['submission_id'],
      senderId: json['sender_id'],
      content: json['content'],
      isAdminMessage: json['is_admin_message'] ?? false,
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      imageUrl: json['image_url']?.toString(),
    );
  }
}
