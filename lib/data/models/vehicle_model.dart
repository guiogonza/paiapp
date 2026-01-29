import 'package:pai_app/domain/entities/vehicle_entity.dart';

/// Modelo de datos para vehículos (mapeo con Supabase)
class VehicleModel extends VehicleEntity {
  const VehicleModel({
    super.id,
    required super.placa,
    required super.marca,
    required super.modelo,
    required super.ano,
    super.conductor,
    super.gpsDeviceId,
    super.ownerId,
    super.currentMileage,
    super.vehicleType,
  });

  /// Crea un VehicleModel desde un Map (JSON de Supabase)
  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    // Helper para parsear números que pueden venir como String
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int parseIntSafe(dynamic value, [int defaultValue = 0]) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    return VehicleModel(
      id: json['id'] as String?,
      placa:
          (json['placa'] ?? json['plate']) as String, // Soporta ambos nombres
      marca:
          (json['marca'] ?? json['brand'] ?? 'N/A')
              as String, // Soporta ambos nombres
      modelo:
          (json['modelo'] ?? json['model'] ?? 'N/A')
              as String, // Soporta ambos nombres
      ano: parseIntSafe(json['ano'] ?? json['year']), // Soporta ambos nombres
      conductor:
          json['driver_name'] as String?, // Mapeo: driver_name → conductor
      gpsDeviceId:
          json['gps_device_id']
              as String?, // Mapeo: gps_device_id → gpsDeviceId
      ownerId: json['owner_id'] as String?, // Mapeo: owner_id → ownerId
      currentMileage: parseDouble(
        json['current_mileage'],
      ), // Soporta String y num
      vehicleType:
          json['vehicle_type'] as String?, // Mapeo: vehicle_type → vehicleType
    );
  }

  /// Convierte un VehicleModel a Map (JSON para Supabase)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'placa': placa, // Mapeo para PostgreSQL local
      'marca': marca, // Mapeo para PostgreSQL local
      'modelo': modelo, // Mapeo para PostgreSQL local
      'ano': ano, // Mapeo para PostgreSQL local
      'driver_name': conductor, // Mapeo: conductor → driver_name
      if (gpsDeviceId != null)
        'gps_device_id': gpsDeviceId, // Mapeo: gpsDeviceId → gps_device_id
      if (ownerId != null) 'owner_id': ownerId, // Mapeo: ownerId → owner_id
      if (currentMileage != null)
        'current_mileage':
            currentMileage, // Mapeo: currentMileage → current_mileage
      if (vehicleType != null)
        'vehicle_type': vehicleType, // Mapeo: vehicleType → vehicle_type
    };
  }

  /// Crea un VehicleModel desde un VehicleEntity
  factory VehicleModel.fromEntity(VehicleEntity entity) {
    return VehicleModel(
      id: entity.id,
      placa: entity.placa,
      marca: entity.marca,
      modelo: entity.modelo,
      ano: entity.ano,
      conductor: entity.conductor,
      gpsDeviceId: entity.gpsDeviceId,
      ownerId: entity.ownerId,
      currentMileage: entity.currentMileage,
      vehicleType: entity.vehicleType,
    );
  }

  /// Convierte a VehicleEntity
  VehicleEntity toEntity() {
    return VehicleEntity(
      id: id,
      placa: placa,
      marca: marca,
      modelo: modelo,
      ano: ano,
      conductor: conductor,
      gpsDeviceId: gpsDeviceId, // CRÍTICO: Incluir gpsDeviceId
      ownerId: ownerId, // CRÍTICO: Incluir ownerId
      currentMileage: currentMileage, // CRÍTICO: Incluir currentMileage
      vehicleType: vehicleType, // CRÍTICO: Incluir vehicleType
    );
  }
}
