class RemittanceEntity {
  final String? id;
  final String routeId; // FK a routes
  final String receiverName; // Nombre del receptor/cliente
  final String status; // 'pendiente' o 'cobrado'
  final String? documentUrl; // URL de la foto del documento
  final DateTime? createdAt; // Fecha de creación
  final DateTime? updatedAt; // Fecha de actualización

  const RemittanceEntity({
    this.id,
    required this.routeId,
    required this.receiverName,
    this.status = 'pendiente',
    this.documentUrl,
    this.createdAt,
    this.updatedAt,
  });

  RemittanceEntity copyWith({
    String? id,
    String? routeId,
    String? receiverName,
    String? status,
    String? documentUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RemittanceEntity(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      receiverName: receiverName ?? this.receiverName,
      status: status ?? this.status,
      documentUrl: documentUrl ?? this.documentUrl,
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
        other.routeId == routeId &&
        other.receiverName == receiverName &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        routeId.hashCode ^
        receiverName.hashCode ^
        status.hashCode;
  }
}

