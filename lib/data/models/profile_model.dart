import 'package:pai_app/domain/entities/profile_entity.dart';

/// Modelo de datos para perfiles (mapeo estricto con Supabase)
/// Las claves JSON deben coincidir exactamente con los nombres de las columnas de la tabla 'profiles'
class ProfileModel extends ProfileEntity {
  const ProfileModel({
    required super.id,
    required super.userId,
    required super.role,
    super.fullName,
    super.phone,
    super.createdAt,
    super.updatedAt,
  });

  /// Crea un ProfileModel desde un Map (JSON de Supabase)
  /// Mapeo estricto: las claves deben coincidir con las columnas de la tabla 'profiles'
  /// En profiles, el id es la clave primaria que coincide con auth.uid()
  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final profileId = json['id'] as String;
    return ProfileModel(
      id: profileId,
      userId: profileId, // En profiles, id y userId son el mismo (id = auth.uid())
      role: json['role'] as String, // Mapeo estricto: role
      fullName: json['full_name'] as String?, // Mapeo estricto: full_name
      phone: json['phone'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null, // Mapeo estricto: created_at
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null, // Mapeo estricto: updated_at
    );
  }

  /// Convierte un ProfileModel a Map (JSON para Supabase)
  /// En profiles, solo existe la columna 'id' (clave primaria), no 'user_id'
  Map<String, dynamic> toJson() {
    return {
      'id': id, // id es la clave primaria que coincide con auth.uid()
      'role': role,
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Crea un ProfileModel desde un ProfileEntity
  factory ProfileModel.fromEntity(ProfileEntity entity) {
    return ProfileModel(
      id: entity.id,
      userId: entity.userId,
      role: entity.role,
      fullName: entity.fullName,
      phone: entity.phone,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Convierte a ProfileEntity
  ProfileEntity toEntity() {
    return ProfileEntity(
      id: id,
      userId: userId,
      role: role,
      fullName: fullName,
      phone: phone,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

