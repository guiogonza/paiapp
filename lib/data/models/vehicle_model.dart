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
      if (conductor != null && conductor!.isNotEmpty) 'driver_name': conductor, // Mapeo: conductor → driver_name
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
    );
  }
}
