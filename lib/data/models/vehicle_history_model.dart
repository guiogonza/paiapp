import 'package:pai_app/domain/entities/vehicle_history_entity.dart';

/// Modelo que mapea VehicleHistoryEntity a/desde JSON para Supabase
class VehicleHistoryModel extends VehicleHistoryEntity {
  const VehicleHistoryModel({
    required super.vehicleId,
    required super.plate,
    required super.lat,
    required super.lng,
    required super.timestamp,
    super.speed,
    super.heading,
    super.altitude,
    super.valid,
  });

  factory VehicleHistoryModel.fromJson(Map<String, dynamic> json) {
    return VehicleHistoryModel(
      vehicleId: json['vehicle_id'] as String,
      plate: json['plate'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      heading: json['heading'] != null ? (json['heading'] as num).toDouble() : null,
      altitude: json['altitude'] != null ? (json['altitude'] as num).toDouble() : null,
      valid: json['valid'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicle_id': vehicleId,
      'plate': plate,
      'lat': lat,
      'lng': lng,
      'timestamp': timestamp.toIso8601String(),
      'speed': speed,
      'heading': heading,
      'altitude': altitude,
      'valid': valid,
    };
  }

  factory VehicleHistoryModel.fromEntity(VehicleHistoryEntity entity) {
    return VehicleHistoryModel(
      vehicleId: entity.vehicleId,
      plate: entity.plate,
      lat: entity.lat,
      lng: entity.lng,
      timestamp: entity.timestamp,
      speed: entity.speed,
      heading: entity.heading,
      altitude: entity.altitude,
      valid: entity.valid,
    );
  }

  VehicleHistoryEntity toEntity() {
    return VehicleHistoryEntity(
      vehicleId: vehicleId,
      plate: plate,
      lat: lat,
      lng: lng,
      timestamp: timestamp,
      speed: speed,
      heading: heading,
      altitude: altitude,
      valid: valid,
    );
  }
}

