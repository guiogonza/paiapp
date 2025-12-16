import 'package:pai_app/domain/entities/maintenance_entity.dart';

/// Modelo de datos para mantenimiento (mapeo con Supabase)
class MaintenanceModel extends MaintenanceEntity {
  const MaintenanceModel({
    super.id,
    required super.vehicleId,
    required super.serviceType,
    required super.serviceDate,
    required super.kmAtService,
    super.nextChangeKm,
    super.alertDate,
    required super.cost,
    super.customServiceName,
    super.tirePosition,
    super.providerName,
    super.receiptUrl,
    required super.createdBy,
  });

  /// Crea un MaintenanceModel desde un Map (JSON de Supabase)
  factory MaintenanceModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceModel(
      id: json['id'] as String?,
      vehicleId: json['vehicle_id'] as String,
      serviceType: json['service_type'] as String,
      serviceDate: DateTime.parse(json['service_date'] as String),
      kmAtService: (json['km_at_service'] as num).toDouble(),
      nextChangeKm: json['next_change_km'] != null 
          ? (json['next_change_km'] as num).toDouble() 
          : null,
      alertDate: json['alert_date'] != null
          ? DateTime.parse(json['alert_date'] as String)
          : null,
      cost: (json['cost'] as num).toDouble(),
      customServiceName: json['custom_service_name'] as String?,
      tirePosition: json['tire_position'] as int?,
      providerName: json['provider_name'] as String?,
      receiptUrl: json['receipt_url'] as String?,
      createdBy: json['created_by'] as String,
    );
  }

  /// Convierte un MaintenanceModel a Map (JSON para Supabase)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'vehicle_id': vehicleId,
      'service_type': serviceType,
      'service_date': serviceDate.toIso8601String().split('T')[0], // Solo fecha (YYYY-MM-DD)
      'km_at_service': kmAtService,
      if (nextChangeKm != null) 'next_change_km': nextChangeKm,
      if (alertDate != null) 'alert_date': alertDate!.toIso8601String().split('T')[0],
      'cost': cost,
      if (customServiceName != null && customServiceName!.isNotEmpty) 'custom_service_name': customServiceName,
      if (tirePosition != null) 'tire_position': tirePosition,
      if (providerName != null && providerName!.isNotEmpty) 'provider_name': providerName,
      if (receiptUrl != null && receiptUrl!.isNotEmpty) 'receipt_url': receiptUrl,
      'created_by': createdBy,
    };
  }

  /// Crea un MaintenanceModel desde un MaintenanceEntity
  factory MaintenanceModel.fromEntity(MaintenanceEntity entity) {
    return MaintenanceModel(
      id: entity.id,
      vehicleId: entity.vehicleId,
      serviceType: entity.serviceType,
      serviceDate: entity.serviceDate,
      kmAtService: entity.kmAtService,
      nextChangeKm: entity.nextChangeKm,
      alertDate: entity.alertDate,
      cost: entity.cost,
      customServiceName: entity.customServiceName,
      tirePosition: entity.tirePosition,
      providerName: entity.providerName,
      receiptUrl: entity.receiptUrl,
      createdBy: entity.createdBy,
    );
  }

  /// Convierte a MaintenanceEntity
  MaintenanceEntity toEntity() {
    return MaintenanceEntity(
      id: id,
      vehicleId: vehicleId,
      serviceType: serviceType,
      serviceDate: serviceDate,
      kmAtService: kmAtService,
      nextChangeKm: nextChangeKm,
      alertDate: alertDate,
      cost: cost,
      customServiceName: customServiceName,
      tirePosition: tirePosition,
      providerName: providerName,
      receiptUrl: receiptUrl,
      createdBy: createdBy,
    );
  }
}

