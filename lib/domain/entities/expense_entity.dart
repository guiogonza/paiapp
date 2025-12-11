class ExpenseEntity {
  final String? id;
  final String tripId; // FK a routes (columna trip_id en Supabase)
  final String? driverId; // ID del conductor que registra el gasto (auth.uid())
  final double amount; // Monto del gasto
  final DateTime date; // Fecha del gasto
  final String type; // Tipo de gasto (columna type en Supabase)
  final String? description; // Descripción opcional
  final String? receiptUrl; // URL de la foto del recibo en Storage

  const ExpenseEntity({
    this.id,
    required this.tripId,
    this.driverId,
    required this.amount,
    required this.date,
    required this.type,
    this.description,
    this.receiptUrl,
  });

  ExpenseEntity copyWith({
    String? id,
    String? tripId,
    String? driverId,
    double? amount,
    DateTime? date,
    String? type,
    String? description,
    String? receiptUrl,
  }) {
    return ExpenseEntity(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      driverId: driverId ?? this.driverId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      description: description ?? this.description,
      receiptUrl: receiptUrl ?? this.receiptUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExpenseEntity &&
        other.id == id &&
        other.tripId == tripId &&
        other.amount == amount &&
        other.date == date &&
        other.type == type &&
        other.description == description &&
        other.receiptUrl == receiptUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        tripId.hashCode ^
        amount.hashCode ^
        date.hashCode ^
        type.hashCode ^
        (description?.hashCode ?? 0) ^
        (receiptUrl?.hashCode ?? 0);
  }
}

