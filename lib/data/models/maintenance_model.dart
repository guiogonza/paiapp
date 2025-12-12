import 'package:pai_app/domain/entities/maintenance_entity.dart';

/// Modelo de datos para mantenimiento (mapeo con Supabase)
class MaintenanceModel extends MaintenanceEntity {
  const MaintenanceModel({
    super.id,
    required super.vehicleId,
    required super.type,
    required super.cost,
    required super.date,
    super.description,
    required super.createdBy,
  });

  /// Crea un MaintenanceModel desde un Map (JSON de Supabase)
  factory MaintenanceModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceModel(
      id: json['id'] as String?,
      vehicleId: json['vehicle_id'] as String,
      type: json['type'] as String,
      cost: (json['cost'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String?,
      createdBy: json['created_by'] as String,
    );
  }

  /// Convierte un MaintenanceModel a Map (JSON para Supabase)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'vehicle_id': vehicleId,
      'type': type,
      'cost': cost,
      'date': date.toIso8601String().split('T')[0], // Solo fecha (YYYY-MM-DD)
      if (description != null && description!.isNotEmpty) 'description': description,
      'created_by': createdBy,
    };
  }

  /// Crea un MaintenanceModel desde un MaintenanceEntity
  factory MaintenanceModel.fromEntity(MaintenanceEntity entity) {
    return MaintenanceModel(
      id: entity.id,
      vehicleId: entity.vehicleId,
      type: entity.type,
      cost: entity.cost,
      date: entity.date,
      description: entity.description,
      createdBy: entity.createdBy,
    );
  }

  /// Convierte a MaintenanceEntity
  MaintenanceEntity toEntity() {
    return MaintenanceEntity(
      id: id,
      vehicleId: vehicleId,
      type: type,
      cost: cost,
      date: date,
      description: description,
      createdBy: createdBy,
    );
  }
}

