class VehicleEntity {
  final String? id;
  final String placa;
  final String marca;
  final String modelo;
  final int ano;
  final String? conductor; // Opcional
  final String? gpsDeviceId; // ID del dispositivo GPS
  final String? ownerId; // ID del dueño
  final double? currentMileage; // Kilometraje actual en km
  final String? vehicleType; // Tipo de vehículo: 'turbo_sencillo', 'doble_troque', 'mini_mula_18', 'mula_22'

  const VehicleEntity({
    this.id,
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.ano,
    this.conductor,
    this.gpsDeviceId,
    this.ownerId,
    this.currentMileage,
    this.vehicleType,
  });

  VehicleEntity copyWith({
    String? id,
    String? placa,
    String? marca,
    String? modelo,
    int? ano,
    String? conductor,
    String? gpsDeviceId,
    String? ownerId,
    double? currentMileage,
    String? vehicleType,
  }) {
    return VehicleEntity(
      id: id ?? this.id,
      placa: placa ?? this.placa,
      marca: marca ?? this.marca,
      modelo: modelo ?? this.modelo,
      ano: ano ?? this.ano,
      conductor: conductor ?? this.conductor,
      gpsDeviceId: gpsDeviceId ?? this.gpsDeviceId,
      ownerId: ownerId ?? this.ownerId,
      currentMileage: currentMileage ?? this.currentMileage,
      vehicleType: vehicleType ?? this.vehicleType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VehicleEntity &&
        other.id == id &&
        other.placa == placa &&
        other.marca == marca &&
        other.modelo == modelo &&
        other.ano == ano &&
        other.conductor == conductor;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        placa.hashCode ^
        marca.hashCode ^
        modelo.hashCode ^
        ano.hashCode ^
        (conductor?.hashCode ?? 0);
  }
}

