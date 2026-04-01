import 'app_user.dart';
import 'association.dart';
import 'enums.dart';

class Membership {
  final String id;
  final String userId;
  final String associationId;
  final AssociationRole role;
  final DateTime createdAt;

  /// Données de l'association embarquées via join Supabase (`associations(*)`).
  /// Null si la requête n'inclut pas le join.
  final Association? association;

  /// Données de l'utilisateur embarquées via join Supabase (`users(*)`).
  /// Null si la requête n'inclut pas le join.
  final AppUser? memberUser;

  const Membership({
    required this.id,
    required this.userId,
    required this.associationId,
    required this.role,
    required this.createdAt,
    this.association,
    this.memberUser,
  });

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      associationId: json['association_id'] as String,
      role: AssociationRoleExtension.fromString(json['role'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      association: json['associations'] != null
          ? Association.fromJson(json['associations'] as Map<String, dynamic>)
          : null,
      memberUser: json['users'] != null
          ? AppUser.fromJson(json['users'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isResponsible => role == AssociationRole.responsible;
  bool get isMember => role == AssociationRole.member;

  Membership copyWith({
    String? id,
    String? userId,
    String? associationId,
    AssociationRole? role,
    DateTime? createdAt,
    Association? association,
    AppUser? memberUser,
  }) {
    return Membership(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      associationId: associationId ?? this.associationId,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      association: association ?? this.association,
      memberUser: memberUser ?? this.memberUser,
    );
  }
}
