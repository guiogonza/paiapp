class TripEntity {
  final String? id;
  final String vehicleId; // FK a vehicles
  final String driverName; // Conductor - obligatorio
  final String origin; // Origen - obligatorio
  final String destination; // Destino - obligatorio
  final double revenueAmount; // Monto de ingreso - obligatorio
  final double budgetAmount; // Presupuesto de gastos - obligatorio
  final DateTime? startDate; // Fecha de inicio del viaje
  final DateTime? endDate; // Fecha de fin del viaje

  const TripEntity({
    this.id,
    required this.vehicleId,
    required this.driverName,
    required this.origin,
    required this.destination,
    required this.revenueAmount,
    required this.budgetAmount,
    this.startDate,
    this.endDate,
  });

  TripEntity copyWith({
    String? id,
    String? vehicleId,
    String? driverName,
    String? origin,
    String? destination,
    double? revenueAmount,
    double? budgetAmount,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return TripEntity(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      driverName: driverName ?? this.driverName,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      revenueAmount: revenueAmount ?? this.revenueAmount,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TripEntity &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.driverName == driverName &&
        other.origin == origin &&
        other.destination == destination &&
        other.revenueAmount == revenueAmount &&
        other.budgetAmount == budgetAmount &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        vehicleId.hashCode ^
        driverName.hashCode ^
        origin.hashCode ^
        destination.hashCode ^
        revenueAmount.hashCode ^
        budgetAmount.hashCode ^
        (startDate?.hashCode ?? 0) ^
        (endDate?.hashCode ?? 0);
  }
}

