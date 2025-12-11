import 'package:pai_app/domain/entities/expense_entity.dart';

/// Modelo de datos para gastos (mapeo estricto con Supabase)
/// IMPORTANTE: 
/// - La columna FK se llama 'trip_id' (no 'route_id')
/// - La columna de tipo se llama 'type' (no 'category')
/// - La columna de conductor se llama 'driver_id'
class ExpenseModel extends ExpenseEntity {
  const ExpenseModel({
    super.id,
    required super.tripId,
    super.driverId,
    required super.amount,
    required super.date,
    required super.type,
    super.description,
    super.receiptUrl,
  });

  /// Crea un ExpenseModel desde un Map (JSON de Supabase)
  /// Mapeo estricto: las claves deben coincidir con las columnas de la tabla
  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String?,
      tripId: json['trip_id'] as String, // Mapeo a trip_id en Supabase
      driverId: json['driver_id'] as String?, // Mapeo a driver_id en Supabase
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      type: json['type'] as String, // Mapeo a type en Supabase
      description: json['description'] as String?,
      receiptUrl: json['receipt_url'] as String?,
    );
  }

  /// Convierte un ExpenseModel a Map (JSON para Supabase)
  /// Mapeo estricto: las claves deben coincidir con las columnas de la tabla
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'trip_id': tripId, // Mapeo a trip_id en Supabase
      if (driverId != null) 'driver_id': driverId, // Mapeo a driver_id en Supabase
      'amount': amount,
      'date': date.toIso8601String().split('T')[0], // Formato YYYY-MM-DD
      'type': type, // Mapeo a type en Supabase
      if (description != null) 'description': description,
      if (receiptUrl != null) 'receipt_url': receiptUrl,
    };
  }

  /// Crea un ExpenseModel desde un ExpenseEntity
  factory ExpenseModel.fromEntity(ExpenseEntity entity) {
    return ExpenseModel(
      id: entity.id,
      tripId: entity.tripId,
      driverId: entity.driverId,
      amount: entity.amount,
      date: entity.date,
      type: entity.type,
      description: entity.description,
      receiptUrl: entity.receiptUrl,
    );
  }

  /// Convierte a ExpenseEntity
  ExpenseEntity toEntity() {
    return ExpenseEntity(
      id: id,
      tripId: tripId,
      driverId: driverId,
      amount: amount,
      date: date,
      type: type,
      description: description,
      receiptUrl: receiptUrl,
    );
  }
}

