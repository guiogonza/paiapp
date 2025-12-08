class VehicleLocationEntity {
  final String id; // ID del vehículo
  final String plate; // Placa del vehículo
  final double lat;
  final double lng;
  final DateTime? timestamp;
  final double? speed; // Opcional: velocidad en km/h
  final double? heading; // Opcional: dirección en grados

  const VehicleLocationEntity({
    required this.id,
    required this.plate,
    required this.lat,
    required this.lng,
    this.timestamp,
    this.speed,
    this.heading,
  });

  VehicleLocationEntity copyWith({
    String? id,
    String? plate,
    double? lat,
    double? lng,
    DateTime? timestamp,
    double? speed,
    double? heading,
  }) {
    return VehicleLocationEntity(
      id: id ?? this.id,
      plate: plate ?? this.plate,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      timestamp: timestamp ?? this.timestamp,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VehicleLocationEntity &&
        other.id == id &&
        other.lat == lat &&
        other.lng == lng;
  }

  @override
  int get hashCode => id.hashCode ^ lat.hashCode ^ lng.hashCode;
}

