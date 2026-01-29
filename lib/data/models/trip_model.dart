import 'package:pai_app/domain/entities/trip_entity.dart';

/// Modelo de datos para viajes (mapeo estricto con Supabase)
/// CRÍTICO: Este modelo se conecta a la tabla 'routes' en Supabase
/// Las claves JSON deben coincidir exactamente con los nombres de las columnas
class TripModel extends TripEntity {
  const TripModel({
    super.id,
    required super.vehicleId,
    required super.driverName,
    required super.clientName,
    required super.origin,
    required super.destination,
    required super.revenueAmount,
    required super.budgetAmount,
    super.startDate,
    super.endDate,
  });

  /// Crea un TripModel desde un Map (JSON de Supabase)
  /// Mapeo estricto: las claves deben coincidir con las columnas de la tabla 'routes'
  factory TripModel.fromJson(Map<String, dynamic> json) {
    // Helper para parsear números que pueden venir como String
    double parseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    return TripModel(
      id: json['id'] as String?,
      vehicleId: json['vehicle_id'] as String, // Mapeo estricto: vehicle_id
      driverName: json['driver_name'] as String, // Mapeo estricto: driver_name
      clientName:
          (json['client_name'] as String?) ?? '', // Mapeo estricto: client_name
      origin:
          (json['start_location'] ?? json['origin']) as String? ??
          '', // Mapeo estricto: start_location o origin
      destination:
          (json['end_location'] ?? json['destination']) as String? ??
          '', // Mapeo estricto: end_location o destination
      revenueAmount: parseDouble(
        json['revenue_amount'],
      ), // Mapeo estricto: revenue_amount
      budgetAmount: parseDouble(
        json['budget_amount'],
      ), // Mapeo estricto: budget_amount
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null, // Mapeo estricto: start_date
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null, // Mapeo estricto: end_date
    );
  }

  /// Convierte un TripModel a Map (JSON para Supabase)
  /// Mapeo estricto: las claves deben coincidir con las columnas de la tabla 'routes'
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'vehicle_id': vehicleId, // Mapeo estricto: vehicle_id
      'driver_name': driverName, // Mapeo estricto: driver_name
      'client_name': clientName, // Mapeo estricto: client_name
      'start_location': origin, // Mapeo estricto: start_location
      'end_location': destination, // Mapeo estricto: end_location
      'revenue_amount': revenueAmount, // Mapeo estricto: revenue_amount
      'budget_amount': budgetAmount, // Mapeo estricto: budget_amount
      if (startDate != null)
        'start_date': startDate!
            .toIso8601String(), // Mapeo estricto: start_date
      if (endDate != null)
        'end_date': endDate!.toIso8601String(), // Mapeo estricto: end_date
    };
  }

  /// Crea un TripModel desde un TripEntity
  factory TripModel.fromEntity(TripEntity entity) {
    return TripModel(
      id: entity.id,
      vehicleId: entity.vehicleId,
      driverName: entity.driverName,
      clientName: entity.clientName,
      origin: entity.origin,
      destination: entity.destination,
      revenueAmount: entity.revenueAmount,
      budgetAmount: entity.budgetAmount,
      startDate: entity.startDate,
      endDate: entity.endDate,
    );
  }

  /// Convierte a TripEntity
  TripEntity toEntity() {
    return TripEntity(
      id: id,
      vehicleId: vehicleId,
      driverName: driverName,
      clientName: clientName,
      origin: origin,
      destination: destination,
      revenueAmount: revenueAmount,
      budgetAmount: budgetAmount,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
