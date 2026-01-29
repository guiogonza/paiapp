import 'package:pai_app/domain/entities/document_entity.dart';

/// Modelo que mapea DocumentEntity a/desde JSON para Supabase
class DocumentModel extends DocumentEntity {
  const DocumentModel({
    super.id,
    super.vehicleId,
    super.driverId,
    required super.documentType,
    required super.expirationDate,
    super.documentUrl,
    super.createdBy,
    super.createdAt,
    super.updatedAt,
    super.isArchived,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String?,
      vehicleId: json['vehicle_id'] as String?,
      driverId: json['driver_id'] as String?,
      documentType: (json['document_type'] ?? json['type']) as String,
      expirationDate: DateTime.parse(
        (json['expiry_date'] ?? json['expiration_date']) as String,
      ),
      documentUrl: json['document_url'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isArchived: json['is_archived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (driverId != null) 'driver_id': driverId,
      'document_type': documentType,
      'expiry_date': expirationDate.toIso8601String().split(
        'T',
      )[0], // YYYY-MM-DD
      if (documentUrl != null) 'document_url': documentUrl,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'is_archived': isArchived ?? false,
    };
  }

  factory DocumentModel.fromEntity(DocumentEntity entity) {
    return DocumentModel(
      id: entity.id,
      vehicleId: entity.vehicleId,
      driverId: entity.driverId,
      documentType: entity.documentType,
      expirationDate: entity.expirationDate,
      documentUrl: entity.documentUrl,
      createdBy: entity.createdBy,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isArchived: entity.isArchived,
    );
  }

  DocumentEntity toEntity() {
    return DocumentEntity(
      id: id,
      vehicleId: vehicleId,
      driverId: driverId,
      documentType: documentType,
      expirationDate: expirationDate,
      documentUrl: documentUrl,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isArchived: isArchived,
    );
  }
}
