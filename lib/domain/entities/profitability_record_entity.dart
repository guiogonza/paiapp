/// Entidad que representa un registro de rentabilidad
/// Puede ser un ingreso, un gasto de viaje o un gasto de mantenimiento
class ProfitabilityRecordEntity {
  final String id;
  final DateTime date;
  final String type; // 'ingreso', 'gasto_viaje', 'gasto_mantenimiento'
  final double amount;
  final String? clientName; // Cliente (solo para gastos de viaje)
  final String? expenseType; // Tipo de gasto (llanta, comida, aceite, etc.)
  final String? routeOrigin; // Origen de la ruta (si aplica)
  final String? routeDestination; // Destino de la ruta (si aplica)
  final String? vehicleId; // ID del vehículo
  final String? vehiclePlate; // Placa del vehículo
  final String? driverId; // ID del conductor
  final String? driverName; // Nombre del conductor
  final String? tripId; // ID del viaje (si aplica)

  const ProfitabilityRecordEntity({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    this.clientName,
    this.expenseType,
    this.routeOrigin,
    this.routeDestination,
    this.vehicleId,
    this.vehiclePlate,
    this.driverId,
    this.driverName,
    this.tripId,
  });

  bool get isIncome => type == 'ingreso';
  bool get isTripExpense => type == 'gasto_viaje';
  bool get isMaintenanceExpense => type == 'gasto_mantenimiento';
}

