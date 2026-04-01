import 'enums.dart';

class AppUser {
  final String id;
  final String email;
  final String name;
  final GlobalRole role;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: GlobalRoleExtension.fromString(json['role'] as String? ?? 'student'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime(2000),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.value,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isAdmin => role == GlobalRole.admin;

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    GlobalRole? role,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
