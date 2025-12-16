import 'package:flutter/material.dart';

class DocumentEntity {
  final String? id;
  final String? vehicleId; // FK a vehicles (NULLABLE)
  final String? driverId; // FK a auth.users (NULLABLE)
  final String documentType; // Tipo de documento (ej: "Licencia", "SOAT", "Seguro")
  final DateTime expirationDate; // Fecha de expiración
  final String? documentUrl; // URL del documento en Storage
  final String? createdBy; // FK a auth.users - Usuario que creó el documento
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? isArchived; // Si el documento fue reemplazado/archivado (para historial)

  const DocumentEntity({
    this.id,
    this.vehicleId,
    this.driverId,
    required this.documentType,
    required this.expirationDate,
    this.documentUrl,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.isArchived,
  });

  /// Verifica si el documento está asociado a un vehículo
  bool get isVehicleDocument => vehicleId != null && vehicleId!.isNotEmpty;

  /// Verifica si el documento está asociado a un conductor
  bool get isDriverDocument => driverId != null && driverId!.isNotEmpty;

  /// Verifica si el documento está próximo a expirar (menos de 7 días)
  bool get isExpiringSoon {
    final daysUntilExpiration = expirationDate.difference(DateTime.now()).inDays;
    return daysUntilExpiration >= 0 && daysUntilExpiration < 7;
  }

  /// Verifica si el documento ya expiró
  bool get isExpired {
    return expirationDate.isBefore(DateTime.now());
  }

  /// Obtiene los días hasta la expiración (negativo si ya expiró)
  int get daysUntilExpiration {
    return expirationDate.difference(DateTime.now()).inDays;
  }

  /// Lógica de Semáforo: 🟢 Verde (>30 días) | 🟡 Amarillo (<=30 días) | 🔴 Rojo (vencido)
  /// Retorna: 'vencido', 'atencion', o 'bien'
  String get trafficLightStatus {
    final daysRemaining = daysUntilExpiration;
    if (daysRemaining < 0) {
      return 'vencido'; // Rojo
    } else if (daysRemaining <= 30) {
      return 'atencion'; // Amarillo
    } else {
      return 'bien'; // Verde
    }
  }

  /// Obtiene el color del semáforo
  Color get trafficLightColor {
    switch (trafficLightStatus) {
      case 'vencido':
        return Colors.red;
      case 'atencion':
        return Colors.orange;
      case 'bien':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Obtiene el ícono del semáforo
  IconData get trafficLightIcon {
    switch (trafficLightStatus) {
      case 'vencido':
        return Icons.error;
      case 'atencion':
        return Icons.warning;
      case 'bien':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  DocumentEntity copyWith({
    String? id,
    String? vehicleId,
    String? driverId,
    String? documentType,
    DateTime? expirationDate,
    String? documentUrl,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
  }) {
    return DocumentEntity(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      driverId: driverId ?? this.driverId,
      documentType: documentType ?? this.documentType,
      expirationDate: expirationDate ?? this.expirationDate,
      documentUrl: documentUrl ?? this.documentUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentEntity &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.driverId == driverId &&
        other.documentType == documentType &&
        other.expirationDate == expirationDate &&
        other.documentUrl == documentUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        (vehicleId?.hashCode ?? 0) ^
        (driverId?.hashCode ?? 0) ^
        documentType.hashCode ^
        expirationDate.hashCode ^
        (documentUrl?.hashCode ?? 0);
  }
}

