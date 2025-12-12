class MaintenanceEntity {
  final String? id;
  final String vehicleId;
  final String serviceType; // Aceite, Llantas, Batería, Frenos, Filtro Aire, Otro
  final DateTime serviceDate;
  final double kmAtService; // Kilometraje al momento del servicio
  final double? nextChangeKm; // Próximo cambio en km (nullable) - usado como alert_km
  final DateTime? alertDate; // Fecha de alerta (nullable) - para Batería o fecha manual
  final double cost;
  final String? customServiceName; // Nombre del servicio personalizado (solo para "Otro")
  final String? providerName; // Nombre del proveedor (nullable)
  final String? receiptUrl; // URL del recibo (nullable)
  final String createdBy; // ID del usuario que creó el registro

  const MaintenanceEntity({
    this.id,
    required this.vehicleId,
    required this.serviceType,
    required this.serviceDate,
    required this.kmAtService,
    this.nextChangeKm,
    this.alertDate,
    required this.cost,
    this.customServiceName,
    this.providerName,
    this.receiptUrl,
    required this.createdBy,
  });

  MaintenanceEntity copyWith({
    String? id,
    String? vehicleId,
    String? serviceType,
    DateTime? serviceDate,
    double? kmAtService,
    double? nextChangeKm,
    DateTime? alertDate,
    double? cost,
    String? customServiceName,
    String? providerName,
    String? receiptUrl,
    String? createdBy,
  }) {
    return MaintenanceEntity(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      serviceType: serviceType ?? this.serviceType,
      serviceDate: serviceDate ?? this.serviceDate,
      kmAtService: kmAtService ?? this.kmAtService,
      nextChangeKm: nextChangeKm ?? this.nextChangeKm,
      alertDate: alertDate ?? this.alertDate,
      cost: cost ?? this.cost,
      customServiceName: customServiceName ?? this.customServiceName,
      providerName: providerName ?? this.providerName,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MaintenanceEntity &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.serviceType == serviceType &&
        other.serviceDate == serviceDate &&
        other.kmAtService == kmAtService &&
        other.nextChangeKm == nextChangeKm &&
        other.alertDate == alertDate &&
        other.cost == cost &&
        other.customServiceName == customServiceName &&
        other.providerName == providerName &&
        other.receiptUrl == receiptUrl &&
        other.createdBy == createdBy;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        vehicleId.hashCode ^
        serviceType.hashCode ^
        serviceDate.hashCode ^
        kmAtService.hashCode ^
        (nextChangeKm?.hashCode ?? 0) ^
        (alertDate?.hashCode ?? 0) ^
        cost.hashCode ^
        (customServiceName?.hashCode ?? 0) ^
        (providerName?.hashCode ?? 0) ^
        (receiptUrl?.hashCode ?? 0) ^
        createdBy.hashCode;
  }
}

