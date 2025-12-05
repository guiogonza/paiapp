import 'package:pai_app/domain/entities/expense_entity.dart';

/// Modelo de datos para gastos (mapeo estricto con Supabase)
/// Las claves JSON deben coincidir exactamente con los nombres de las columnas
class ExpenseModel extends ExpenseEntity {
  const ExpenseModel({
    super.id,
    required super.routeId,
    required super.amount,
    required super.date,
    required super.category,
    super.description,
    super.receiptUrl,
  });

  /// Crea un ExpenseModel desde un Map (JSON de Supabase)
  /// Mapeo estricto: las claves deben coincidir con las columnas de la tabla
  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String?,
      routeId: json['route_id'] as String, // Mapeo estricto: route_id
      amount: (json['amount'] as num).toDouble(), // Mapeo estricto: amount
      date: DateTime.parse(json['date'] as String), // Mapeo estricto: date
      category: json['category'] as String, // Mapeo estricto: category
      description: json['description'] as String?, // Mapeo estricto: description
      receiptUrl: json['receipt_url'] as String?, // Mapeo estricto: receipt_url
    );
  }

  /// Convierte un ExpenseModel a Map (JSON para Supabase)
  /// Mapeo estricto: las claves deben coincidir con las columnas de la tabla
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'route_id': routeId, // Mapeo estricto: route_id
      'amount': amount, // Mapeo estricto: amount
      'date': date.toIso8601String().split('T')[0], // Mapeo estricto: date (formato YYYY-MM-DD)
      'category': category, // Mapeo estricto: category
      if (description != null) 'description': description, // Mapeo estricto: description
      if (receiptUrl != null) 'receipt_url': receiptUrl, // Mapeo estricto: receipt_url
    };
  }

  /// Crea un ExpenseModel desde un ExpenseEntity
  factory ExpenseModel.fromEntity(ExpenseEntity entity) {
    return ExpenseModel(
      id: entity.id,
      routeId: entity.routeId,
      amount: entity.amount,
      date: entity.date,
      category: entity.category,
      description: entity.description,
      receiptUrl: entity.receiptUrl,
    );
  }

  /// Convierte a ExpenseEntity
  ExpenseEntity toEntity() {
    return ExpenseEntity(
      id: id,
      routeId: routeId,
      amount: amount,
      date: date,
      category: category,
      description: description,
      receiptUrl: receiptUrl,
    );
  }
}

