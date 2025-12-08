/// Entidad que representa un punto del historial de ubicación de un vehículo
class VehicleHistoryEntity {
  final String vehicleId; // ID del vehículo
  final String plate; // Placa del vehículo
  final double lat;
  final double lng;
  final DateTime timestamp;
  final double? speed; // Velocidad en km/h
  final double? heading; // Dirección en grados (course)
  final double? altitude; // Altitud en metros
  final bool? valid; // Si la ubicación es válida

  const VehicleHistoryEntity({
    required this.vehicleId,
    required this.plate,
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.speed,
    this.heading,
    this.altitude,
    this.valid,
  });

  VehicleHistoryEntity copyWith({
    String? vehicleId,
    String? plate,
    double? lat,
    double? lng,
    DateTime? timestamp,
    double? speed,
    double? heading,
    double? altitude,
    bool? valid,
  }) {
    return VehicleHistoryEntity(
      vehicleId: vehicleId ?? this.vehicleId,
      plate: plate ?? this.plate,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      timestamp: timestamp ?? this.timestamp,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      altitude: altitude ?? this.altitude,
      valid: valid ?? this.valid,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VehicleHistoryEntity &&
        other.vehicleId == vehicleId &&
        other.lat == lat &&
        other.lng == lng &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode =>
      vehicleId.hashCode ^
      lat.hashCode ^
      lng.hashCode ^
      timestamp.hashCode;
}

