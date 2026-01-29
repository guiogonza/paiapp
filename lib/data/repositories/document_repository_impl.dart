import 'dart:io';
import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/document_entity.dart';
import 'package:pai_app/domain/failures/document_failure.dart';
import 'package:pai_app/domain/repositories/document_repository.dart';
import 'package:pai_app/data/models/document_model.dart';
import 'package:pai_app/data/services/local_api_client.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  final LocalApiClient _localApi = LocalApiClient();

  @override
  Future<Either<DocumentFailure, List<DocumentEntity>>> getDocuments() async {
    try {
      final response = await _localApi.get('/rest/v1/documents');

      final documents = (response as List)
          .map((json) => DocumentModel.fromJson(json as Map<String, dynamic>))
          .map((model) => model.toEntity())
          .toList();

      return Right(documents);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('Sesión expirada') || errorMsg.contains('401')) {
        return Left(
          ValidationFailure(
            'No tienes permisos. Asegúrate de estar autenticado correctamente.',
          ),
        );
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, DocumentEntity>> getDocumentById(
    String id,
  ) async {
    try {
      final response = await _localApi.get('/rest/v1/documents/$id');

      if (response == null) {
        return const Left(NotFoundFailure());
      }

      final document = DocumentModel.fromJson(response as Map<String, dynamic>);
      return Right(document.toEntity());
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      if (e.toString().contains('404')) {
        return const Left(NotFoundFailure());
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, List<DocumentEntity>>> getDocumentsByVehicleId(
    String vehicleId,
  ) async {
    try {
      final response = await _localApi.get(
        '/rest/v1/documents',
        queryParams: {'vehicle_id': 'eq.$vehicleId'},
      );

      final documents = (response as List)
          .map((json) => DocumentModel.fromJson(json as Map<String, dynamic>))
          .map((model) => model.toEntity())
          .toList();

      return Right(documents);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, List<DocumentEntity>>> getDocumentsByDriverId(
    String driverId,
  ) async {
    try {
      final response = await _localApi.get(
        '/rest/v1/documents',
        queryParams: {'driver_id': 'eq.$driverId'},
      );

      final documents = (response as List)
          .map((json) => DocumentModel.fromJson(json as Map<String, dynamic>))
          .map((model) => model.toEntity())
          .toList();

      return Right(documents);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, DocumentEntity>> createDocument(
    DocumentEntity document,
  ) async {
    try {
      final documentData = DocumentModel.fromEntity(document).toJson();
      documentData.remove('id'); // No incluir id en la creación
      documentData.remove('created_at');
      documentData.remove('updated_at');

      print('📄 Creando documento: $documentData');

      final response = await _localApi.post('/rest/v1/documents', documentData);

      print('✅ Documento creado: $response');

      final createdDocument = DocumentModel.fromJson(
        response as Map<String, dynamic>,
      );
      return Right(createdDocument.toEntity());
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      final errorMsg = e.toString();
      print('❌ Error creando documento: $errorMsg');
      if (errorMsg.contains('Sesión expirada') || errorMsg.contains('401')) {
        return Left(
          ValidationFailure(
            'No tienes permisos. Asegúrate de estar autenticado correctamente.',
          ),
        );
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, DocumentEntity>> updateDocument(
    DocumentEntity document,
  ) async {
    try {
      if (document.id == null) {
        return const Left(
          ValidationFailure('El ID del documento es requerido para actualizar'),
        );
      }

      final documentData = DocumentModel.fromEntity(document).toJson();
      documentData.remove('id'); // No actualizar el id
      documentData.remove('created_at');

      final response = await _localApi.patch(
        '/rest/v1/documents',
        document.id!,
        documentData,
      );

      final updatedDocument = DocumentModel.fromJson(
        response as Map<String, dynamic>,
      );
      return Right(updatedDocument.toEntity());
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      if (e.toString().contains('404')) {
        return const Left(NotFoundFailure());
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, void>> deleteDocument(String id) async {
    try {
      await _localApi.delete('/rest/v1/documents', id);
      return const Right(null);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      if (e.toString().contains('404')) {
        return const Left(NotFoundFailure());
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, String>> uploadDocumentImage(
    List<int> fileBytes,
    String fileName,
  ) async {
    try {
      // Por ahora, retornamos una URL placeholder ya que no tenemos storage local configurado
      // TODO: Implementar subida de archivos al servidor local
      print(
        '⚠️ Upload de imagen no implementado localmente, usando placeholder',
      );
      return Right('https://placeholder.local/documents/$fileName');
    } catch (e) {
      return Left(StorageFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, void>> deleteDocumentImage(
    String imageUrl,
  ) async {
    try {
      // TODO: Implementar eliminación de archivos del servidor local
      print('⚠️ Delete de imagen no implementado localmente');
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, DocumentEntity>> renewDocument(
    String oldDocumentId,
    DocumentEntity newDocument,
  ) async {
    try {
      // 1. Archivar el documento antiguo (marcar is_archived = true)
      await _localApi.patch('/rest/v1/documents', oldDocumentId, {
        'is_archived': true,
      });

      // 2. Crear el nuevo documento
      final newDocumentData = DocumentModel.fromEntity(newDocument).toJson();
      newDocumentData.remove('id'); // No incluir id en la creación
      newDocumentData['is_archived'] = false; // El nuevo documento está activo

      final response = await _localApi.post(
        '/rest/v1/documents',
        newDocumentData,
      );

      final renewedDocument = DocumentModel.fromJson(
        response as Map<String, dynamic>,
      ).toEntity();
      return Right(renewedDocument);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, List<DocumentEntity>>> getDocumentHistory(
    DocumentEntity document,
  ) async {
    try {
      final queryParams = <String, String>{
        'is_archived': 'eq.true',
        'document_type': 'eq.${document.documentType}',
      };

      // Filtrar por vehicle_id o driver_id según corresponda
      if (document.vehicleId != null && document.vehicleId!.isNotEmpty) {
        queryParams['vehicle_id'] = 'eq.${document.vehicleId}';
      } else if (document.driverId != null && document.driverId!.isNotEmpty) {
        queryParams['driver_id'] = 'eq.${document.driverId}';
      }

      final response = await _localApi.get(
        '/rest/v1/documents',
        queryParams: queryParams,
      );

      final documents = (response as List)
          .map((json) => DocumentModel.fromJson(json as Map<String, dynamic>))
          .map((model) => model.toEntity())
          .toList();

      return Right(documents);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  String _mapGenericError(dynamic e) {
    return e.toString();
  }
}
