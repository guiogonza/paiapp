class ProfileEntity {
  final String id;
  final String userId; // FK a auth.users
  final String role; // 'owner' o 'driver'
  final String? fullName;
  final String? phone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfileEntity({
    required this.id,
    required this.userId,
    required this.role,
    this.fullName,
    this.phone,
    this.createdAt,
    this.updatedAt,
  });

  ProfileEntity copyWith({
    String? id,
    String? userId,
    String? role,
    String? fullName,
    String? phone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileEntity &&
        other.id == id &&
        other.userId == userId &&
        other.role == role;
  }

  @override
  int get hashCode => id.hashCode ^ userId.hashCode ^ role.hashCode;
}

