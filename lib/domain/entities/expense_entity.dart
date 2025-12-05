class ExpenseEntity {
  final String? id;
  final String routeId; // FK a routes
  final double amount; // Monto del gasto
  final DateTime date; // Fecha del gasto
  final String category; // Categoría: 'Gasolina', 'Comida', 'Peajes', 'Hoteles', 'Repuestos', 'Arreglos', 'Otros'
  final String? description; // Descripción opcional
  final String? receiptUrl; // URL de la foto del recibo en Storage

  const ExpenseEntity({
    this.id,
    required this.routeId,
    required this.amount,
    required this.date,
    required this.category,
    this.description,
    this.receiptUrl,
  });

  ExpenseEntity copyWith({
    String? id,
    String? routeId,
    double? amount,
    DateTime? date,
    String? category,
    String? description,
    String? receiptUrl,
  }) {
    return ExpenseEntity(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      receiptUrl: receiptUrl ?? this.receiptUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExpenseEntity &&
        other.id == id &&
        other.routeId == routeId &&
        other.amount == amount &&
        other.date == date &&
        other.category == category &&
        other.description == description &&
        other.receiptUrl == receiptUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        routeId.hashCode ^
        amount.hashCode ^
        date.hashCode ^
        category.hashCode ^
        (description?.hashCode ?? 0) ^
        (receiptUrl?.hashCode ?? 0);
  }
}

