import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/document_entity.dart';
import 'package:pai_app/domain/failures/document_failure.dart';

abstract class DocumentRepository {
  /// Obtiene todos los documentos
  Future<Either<DocumentFailure, List<DocumentEntity>>> getDocuments();

  /// Obtiene un documento por ID
  Future<Either<DocumentFailure, DocumentEntity>> getDocumentById(String id);

  /// Obtiene documentos por vehicle_id
  Future<Either<DocumentFailure, List<DocumentEntity>>> getDocumentsByVehicleId(String vehicleId);

  /// Obtiene documentos por driver_id
  Future<Either<DocumentFailure, List<DocumentEntity>>> getDocumentsByDriverId(String driverId);

  /// Crea un nuevo documento
  Future<Either<DocumentFailure, DocumentEntity>> createDocument(DocumentEntity document);

  /// Actualiza un documento
  Future<Either<DocumentFailure, DocumentEntity>> updateDocument(DocumentEntity document);

  /// Elimina un documento
  Future<Either<DocumentFailure, void>> deleteDocument(String id);

  /// Sube un documento a Storage
  Future<Either<DocumentFailure, String>> uploadDocumentImage(List<int> fileBytes, String fileName);

  /// Elimina un documento de Storage
  Future<Either<DocumentFailure, void>> deleteDocumentImage(String imageUrl);

  /// Renueva un documento: archiva el antiguo y crea uno nuevo
  Future<Either<DocumentFailure, DocumentEntity>> renewDocument(
    String oldDocumentId,
    DocumentEntity newDocument,
  );

  /// Obtiene el historial de documentos archivados para un documento específico
  /// (mismo tipo, mismo vehículo o conductor)
  Future<Either<DocumentFailure, List<DocumentEntity>>> getDocumentHistory(DocumentEntity document);
}

