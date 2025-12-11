class RemittanceEntity {
  final String? id;
  final String tripId; // FK a routes (columna trip_id en Supabase)
  final String receiverName; // Nombre del receptor/cliente
  final String status; // 'pendiente' o 'cobrado'
  final String? receiptUrl; // URL de la foto del memorando (columna receipt_url en Supabase)
  final DateTime? createdAt; // Fecha de creación
  final DateTime? updatedAt; // Fecha de actualización

  const RemittanceEntity({
    this.id,
    required this.tripId,
    required this.receiverName,
    this.status = 'pendiente_completar', // Estado inicial: pendiente_completar
    this.receiptUrl,
    this.createdAt,
    this.updatedAt,
  });

  RemittanceEntity copyWith({
    String? id,
    String? tripId,
    String? receiverName,
    String? status,
    String? receiptUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RemittanceEntity(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      receiverName: receiverName ?? this.receiverName,
      status: status ?? this.status,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => status == 'pendiente';
  bool get isCollected => status == 'cobrado';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RemittanceEntity &&
        other.id == id &&
        other.tripId == tripId &&
        other.receiverName == receiverName &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        tripId.hashCode ^
        receiverName.hashCode ^
        status.hashCode;
  }
}

