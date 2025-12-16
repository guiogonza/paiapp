import 'dart:io';
import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/domain/entities/document_entity.dart';
import 'package:pai_app/domain/failures/document_failure.dart';
import 'package:pai_app/domain/repositories/document_repository.dart';
import 'package:pai_app/data/models/document_model.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'documents';
  static const String _storageBucket = 'signatures'; // Usar el mismo bucket que las remisiones

  @override
  Future<Either<DocumentFailure, List<DocumentEntity>>> getDocuments() async {
    try {
      // Filtrar solo documentos activos (no archivados)
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('is_archived', false)
          .order('expiration_date', ascending: true);

      final documents = (response as List)
          .map((json) => DocumentModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(documents);
    } on PostgrestException catch (e) {
      if (e.message.contains('row-level security') || 
          e.message.contains('policy') ||
          e.code == 'PGRST301') {
        return Left(ValidationFailure(
          'No tienes permisos. Asegúrate de estar autenticado como owner.'
        ));
      }
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, DocumentEntity>> getDocumentById(String id) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return const Left(NotFoundFailure());
      }

      final document = DocumentModel.fromJson(response);
      return Right(document.toEntity());
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure());
      }
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, List<DocumentEntity>>> getDocumentsByVehicleId(String vehicleId) async {
    try {
      // Filtrar solo documentos activos (no archivados)
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('vehicle_id', vehicleId)
          .eq('is_archived', false)
          .order('expiration_date', ascending: true);

      final documents = (response as List)
          .map((json) => DocumentModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(documents);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, List<DocumentEntity>>> getDocumentsByDriverId(String driverId) async {
    try {
      // Filtrar solo documentos activos (no archivados)
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('driver_id', driverId)
          .eq('is_archived', false)
          .order('expiration_date', ascending: true);

      final documents = (response as List)
          .map((json) => DocumentModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(documents);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, DocumentEntity>> createDocument(DocumentEntity document) async {
    try {
      // Obtener el ID del usuario autenticado (owner)
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        return const Left(ValidationFailure('Usuario no autenticado. Por favor, inicia sesión.'));
      }

      final documentData = DocumentModel.fromEntity(document).toJson();
      documentData.remove('id'); // No incluir id en la creación
      documentData['created_by'] = currentUserId; // Incluir explícitamente el usuario que crea el documento
      documentData['created_at'] = DateTime.now().toIso8601String();
      documentData['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from(_tableName)
          .insert(documentData)
          .select()
          .single();

      final createdDocument = DocumentModel.fromJson(response);
      return Right(createdDocument.toEntity());
    } on PostgrestException catch (e) {
      if (e.message.contains('row-level security') || 
          e.message.contains('policy') ||
          e.code == 'PGRST301') {
        return Left(ValidationFailure(
          'No tienes permisos. Asegúrate de estar autenticado como owner.'
        ));
      }
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, DocumentEntity>> updateDocument(DocumentEntity document) async {
    try {
      if (document.id == null) {
        return const Left(ValidationFailure('El ID del documento es requerido para actualizar'));
      }

      final documentData = DocumentModel.fromEntity(document).toJson();
      documentData.remove('id'); // No actualizar el id
      documentData['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from(_tableName)
          .update(documentData)
          .eq('id', document.id!)
          .select()
          .single();

      final updatedDocument = DocumentModel.fromJson(response);
      return Right(updatedDocument.toEntity());
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure());
      }
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, void>> deleteDocument(String id) async {
    try {
      await _supabase
          .from(_tableName)
          .delete()
          .eq('id', id);

      return const Right(null);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return Left(NotFoundFailure());
      }
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, String>> uploadDocumentImage(List<int> fileBytes, String fileName) async {
    try {
      // Convertir List<int> a Uint8List
      final uint8List = Uint8List.fromList(fileBytes);
      
      // Normalizar el nombre del archivo
      final normalizedFileName = fileName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9._-]'), '_')
          .replaceAll(RegExp(r'_+'), '_');

      final filePath = 'documents/$normalizedFileName';

      await _supabase.storage
          .from(_storageBucket)
          .uploadBinary(
            filePath,
            uint8List,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _getContentType(fileName),
            ),
          );

      final publicUrl = _supabase.storage
          .from(_storageBucket)
          .getPublicUrl(filePath);

      return Right(publicUrl);
    } on StorageException catch (e) {
      return Left(StorageFailure(_mapStorageError(e)));
    } catch (e) {
      return Left(StorageFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, void>> deleteDocumentImage(String imageUrl) async {
    try {
      // Extraer el path del archivo desde la URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final filePath = pathSegments.sublist(pathSegments.length - 2).join('/');

      await _supabase.storage
          .from(_storageBucket)
          .remove([filePath]);

      return const Right(null);
    } on StorageException catch (e) {
      return Left(StorageFailure(_mapStorageError(e)));
    } catch (e) {
      return Left(StorageFailure(_mapGenericError(e)));
    }
  }

  String _getContentType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Future<Either<DocumentFailure, DocumentEntity>> renewDocument(
    String oldDocumentId,
    DocumentEntity newDocument,
  ) async {
    try {
      // 1. Archivar el documento antiguo (marcar is_archived = true)
      await _supabase
          .from(_tableName)
          .update({
            'is_archived': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', oldDocumentId);

      // 2. Crear el nuevo documento
      final newDocumentData = DocumentModel.fromEntity(newDocument).toJson();
      newDocumentData.remove('id'); // No incluir id en la creación
      newDocumentData['is_archived'] = false; // El nuevo documento está activo

      final response = await _supabase
          .from(_tableName)
          .insert(newDocumentData)
          .select()
          .single();

      final renewedDocument = DocumentModel.fromJson(response).toEntity();
      return Right(renewedDocument);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<DocumentFailure, List<DocumentEntity>>> getDocumentHistory(DocumentEntity document) async {
    try {
      // Buscar documentos archivados con el mismo tipo y asociación (vehículo o conductor)
      var query = _supabase
          .from(_tableName)
          .select()
          .eq('type', document.documentType)
          .eq('is_archived', true);

      // Filtrar por vehicle_id o driver_id según corresponda
      if (document.vehicleId != null && document.vehicleId!.isNotEmpty) {
        query = query.eq('vehicle_id', document.vehicleId!);
      } else if (document.driverId != null && document.driverId!.isNotEmpty) {
        query = query.eq('driver_id', document.driverId!);
      }

      // Aplicar orden después de todos los filtros
      final response = await query.order('expiration_date', ascending: false);

      final documents = (response as List)
          .map((json) => DocumentModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(documents);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  String _mapPostgrestError(PostgrestException e) {
    return e.message.isNotEmpty ? e.message : 'Error en la base de datos';
  }

  String _mapStorageError(StorageException e) {
    return e.message.isNotEmpty ? e.message : 'Error al subir el documento';
  }

  String _mapGenericError(dynamic e) {
    return e.toString();
  }
}

