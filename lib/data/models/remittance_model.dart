import 'package:pai_app/domain/entities/remittance_entity.dart';

/// Modelo que mapea RemittanceEntity a/desde JSON para Supabase
class RemittanceModel extends RemittanceEntity {
  const RemittanceModel({
    super.id,
    required super.routeId,
    required super.receiverName,
    super.status,
    super.documentUrl,
    super.createdAt,
    super.updatedAt,
  });

  factory RemittanceModel.fromJson(Map<String, dynamic> json) {
    return RemittanceModel(
      id: json['id'] as String?,
      routeId: json['route_id'] as String,
      receiverName: json['receiver_name'] as String,
      status: (json['status'] as String?) ?? 'pendiente',
      documentUrl: json['document_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'route_id': routeId,
      'receiver_name': receiverName,
      'status': status,
      if (documentUrl != null) 'document_url': documentUrl,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  factory RemittanceModel.fromEntity(RemittanceEntity entity) {
    return RemittanceModel(
      id: entity.id,
      routeId: entity.routeId,
      receiverName: entity.receiverName,
      status: entity.status,
      documentUrl: entity.documentUrl,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  RemittanceEntity toEntity() {
    return RemittanceEntity(
      id: id,
      routeId: routeId,
      receiverName: receiverName,
      status: status,
      documentUrl: documentUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

