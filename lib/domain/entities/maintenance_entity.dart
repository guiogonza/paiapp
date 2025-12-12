class MaintenanceEntity {
  final String? id;
  final String vehicleId;
  final String type; // Aceite, Llantas, Batería, Frenos, Filtros, Otro
  final double cost;
  final DateTime date;
  final String? description;
  final String createdBy; // ID del usuario que creó el registro

  const MaintenanceEntity({
    this.id,
    required this.vehicleId,
    required this.type,
    required this.cost,
    required this.date,
    this.description,
    required this.createdBy,
  });

  MaintenanceEntity copyWith({
    String? id,
    String? vehicleId,
    String? type,
    double? cost,
    DateTime? date,
    String? description,
    String? createdBy,
  }) {
    return MaintenanceEntity(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      type: type ?? this.type,
      cost: cost ?? this.cost,
      date: date ?? this.date,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MaintenanceEntity &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.type == type &&
        other.cost == cost &&
        other.date == date &&
        other.description == description &&
        other.createdBy == createdBy;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        vehicleId.hashCode ^
        type.hashCode ^
        cost.hashCode ^
        date.hashCode ^
        (description?.hashCode ?? 0) ^
        createdBy.hashCode;
  }
}

