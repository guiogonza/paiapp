class ProfileEntity {
  final String id;
  final String userId; // FK a auth.users
  final String role; // 'owner' o 'driver'
  final String? email;
  final String? fullName;
  final String? phone;
  final String? assignedVehicleId; // ID del vehículo asignado (nullable)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfileEntity({
    required this.id,
    required this.userId,
    required this.role,
    this.email,
    this.fullName,
    this.phone,
    this.assignedVehicleId,
    this.createdAt,
    this.updatedAt,
  });

  ProfileEntity copyWith({
    String? id,
    String? userId,
    String? role,
    String? email,
    String? fullName,
    String? phone,
    String? assignedVehicleId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      assignedVehicleId: assignedVehicleId ?? this.assignedVehicleId,
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
        other.role == role &&
        other.email == email &&
        other.assignedVehicleId == assignedVehicleId;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      role.hashCode ^
      (email?.hashCode ?? 0) ^
      (assignedVehicleId?.hashCode ?? 0);
}

