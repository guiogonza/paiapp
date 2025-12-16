class RouteEntity {
  final String? id;
  final String vehicleId; // FK a vehicles
  final String startLocation; // Origen
  final String endLocation; // Destino
  final String? driverName; // Conductor
  final String? clientName; // Cliente
  final double? revenueAmount; // Importe a cobrar
  final DateTime? createdAt; // Fecha de creación

  const RouteEntity({
    this.id,
    required this.vehicleId,
    required this.startLocation,
    required this.endLocation,
    this.driverName,
    this.clientName,
    this.revenueAmount,
    this.createdAt,
  });

  RouteEntity copyWith({
    String? id,
    String? vehicleId,
    String? startLocation,
    String? endLocation,
    String? driverName,
    String? clientName,
    double? revenueAmount,
    DateTime? createdAt,
  }) {
    return RouteEntity(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      driverName: driverName ?? this.driverName,
      clientName: clientName ?? this.clientName,
      revenueAmount: revenueAmount ?? this.revenueAmount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteEntity &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.startLocation == startLocation &&
        other.endLocation == endLocation &&
        other.clientName == clientName;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        vehicleId.hashCode ^
        startLocation.hashCode ^
        endLocation.hashCode ^
        (clientName?.hashCode ?? 0);
  }
}

