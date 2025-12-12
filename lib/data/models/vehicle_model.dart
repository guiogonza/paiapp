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
  });

  /// Crea un VehicleModel desde un Map (JSON de Supabase)
  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String?,
      placa: json['plate'] as String, // Mapeo: plate → placa
      marca: json['brand'] as String, // Mapeo: brand → marca
      modelo: json['model'] as String, // Mapeo: model → modelo
      ano: json['year'] as int? ?? 0, // Mapeo: year → ano
      conductor: json['driver_name'] as String?, // Mapeo: driver_name → conductor
      gpsDeviceId: json['gps_device_id'] as String?, // Mapeo: gps_device_id → gpsDeviceId
      ownerId: json['owner_id'] as String?, // Mapeo: owner_id → ownerId
      currentMileage: json['current_mileage'] != null 
          ? (json['current_mileage'] as num).toDouble() 
          : null, // Mapeo: current_mileage → currentMileage
    );
  }

  /// Convierte un VehicleModel a Map (JSON para Supabase)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'plate': placa, // Mapeo: placa → plate
      'brand': marca, // Mapeo: marca → brand
      'model': modelo, // Mapeo: modelo → model
      'year': ano, // Mapeo: ano → year
      'driver_name': conductor,// Mapeo: conductor → driver_name
      if (gpsDeviceId != null) 'gps_device_id': gpsDeviceId, // Mapeo: gpsDeviceId → gps_device_id
      if (ownerId != null) 'owner_id': ownerId, // Mapeo: ownerId → owner_id
      if (currentMileage != null) 'current_mileage': currentMileage, // Mapeo: currentMileage → current_mileage
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
    );
  }
}
