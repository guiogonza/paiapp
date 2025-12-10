import 'package:pai_app/domain/entities/remittance_entity.dart';

/// Modelo que mapea RemittanceEntity a/desde JSON para Supabase
/// IMPORTANTE: 
/// - La columna de FK se llama 'trip_id' (no 'route_id')
/// - La columna de foto se llama 'receipt_url' (no 'document_url')
class RemittanceModel extends RemittanceEntity {
  const RemittanceModel({
    super.id,
    required super.tripId,
    required super.receiverName,
    super.status,
    super.receiptUrl,
    super.createdAt,
    super.updatedAt,
  });

  factory RemittanceModel.fromJson(Map<String, dynamic> json) {
    return RemittanceModel(
      id: json['id'] as String?,
      tripId: json['trip_id'] as String, // Mapeo a trip_id en Supabase
      receiverName: json['receiver_name'] as String,
      status: (json['status'] as String?) ?? 'pendiente',
      receiptUrl: json['receipt_url'] as String?, // Mapeo a receipt_url en Supabase
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
      'trip_id': tripId, // Mapeo a trip_id en Supabase
      'receiver_name': receiverName,
      'status': status,
      if (receiptUrl != null) 'receipt_url': receiptUrl, // Mapeo a receipt_url en Supabase
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  factory RemittanceModel.fromEntity(RemittanceEntity entity) {
    return RemittanceModel(
      id: entity.id,
      tripId: entity.tripId,
      receiverName: entity.receiverName,
      status: entity.status,
      receiptUrl: entity.receiptUrl,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  RemittanceEntity toEntity() {
    return RemittanceEntity(
      id: id,
      tripId: tripId,
      receiverName: receiverName,
      status: status,
      receiptUrl: receiptUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

