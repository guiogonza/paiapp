class VehicleEntity {
  final String? id;
  final String placa;
  final String marca;
  final String modelo;
  final int ano;
  final String? conductor; // Opcional

  const VehicleEntity({
    this.id,
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.ano,
    this.conductor,
  });

  VehicleEntity copyWith({
    String? id,
    String? placa,
    String? marca,
    String? modelo,
    int? ano,
    String? conductor,
  }) {
    return VehicleEntity(
      id: id ?? this.id,
      placa: placa ?? this.placa,
      marca: marca ?? this.marca,
      modelo: modelo ?? this.modelo,
      ano: ano ?? this.ano,
      conductor: conductor ?? this.conductor,
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

