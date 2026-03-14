class Admin {
  final String id;
  final String username;
  final String email;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;

  Admin({
    required this.id,
    required this.username,
    required this.email,
    required this.isActive,
    required this.createdAt,
    this.lastLogin,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : null,
    );
  }
}
