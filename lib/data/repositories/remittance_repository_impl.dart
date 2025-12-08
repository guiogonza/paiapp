import 'dart:io';
import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/domain/entities/remittance_entity.dart';
import 'package:pai_app/domain/entities/remittance_with_route_entity.dart';
import 'package:pai_app/domain/entities/route_entity.dart';
import 'package:pai_app/domain/failures/remittance_failure.dart';
import 'package:pai_app/domain/repositories/remittance_repository.dart';
import 'package:pai_app/data/models/remittance_model.dart';

class RemittanceRepositoryImpl implements RemittanceRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'remittances';
  static const String _storageBucket = 'remittances';

  @override
  Future<Either<RemittanceFailure, List<RemittanceEntity>>> getRemittances() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .order('created_at', ascending: false);

      final remittances = (response as List)
          .map((json) => RemittanceModel.fromJson(json).toEntity())
          .toList();

      return Right(remittances);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, List<RemittanceEntity>>> getPendingRemittances() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('status', 'pendiente')
          .order('created_at', ascending: false);

      final remittances = (response as List)
          .map((json) => RemittanceModel.fromJson(json).toEntity())
          .toList();

      return Right(remittances);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, List<RemittanceWithRouteEntity>>> getRemittancesWithRoutes() async {
    try {
      // Hacer JOIN con routes usando Supabase
      final response = await _supabase
          .from(_tableName)
          .select('''
            *,
            routes:route_id (
              id,
              vehicle_id,
              start_location,
              end_location,
              driver_name,
              client_name,
              created_at
            )
          ''')
          .order('created_at', ascending: false);

      final remittancesWithRoutes = <RemittanceWithRouteEntity>[];

      for (var item in response as List) {
        final remittance = RemittanceModel.fromJson(item).toEntity();
        
        // Extraer datos de route del JOIN
        final routeData = item['routes'] as Map<String, dynamic>?;
        if (routeData != null) {
          final route = RouteEntity(
            id: routeData['id'] as String?,
            vehicleId: routeData['vehicle_id'] as String,
            startLocation: routeData['start_location'] as String? ?? '',
            endLocation: routeData['end_location'] as String? ?? '',
            driverName: routeData['driver_name'] as String?,
            clientName: routeData['client_name'] as String?,
            createdAt: routeData['created_at'] != null
                ? DateTime.parse(routeData['created_at'] as String)
                : null,
          );

          remittancesWithRoutes.add(
            RemittanceWithRouteEntity(
              remittance: remittance,
              route: route,
            ),
          );
        }
      }

      return Right(remittancesWithRoutes);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, List<RemittanceWithRouteEntity>>> getPendingRemittancesWithRoutes() async {
    try {
      // Hacer JOIN con routes y filtrar por status = 'pendiente'
      final response = await _supabase
          .from(_tableName)
          .select('''
            *,
            routes:route_id (
              id,
              vehicle_id,
              start_location,
              end_location,
              driver_name,
              client_name,
              created_at
            )
          ''')
          .eq('status', 'pendiente')
          .order('created_at', ascending: false);

      final remittancesWithRoutes = <RemittanceWithRouteEntity>[];

      for (var item in response as List) {
        final remittance = RemittanceModel.fromJson(item).toEntity();
        
        // Extraer datos de route del JOIN
        final routeData = item['routes'] as Map<String, dynamic>?;
        if (routeData != null) {
          final route = RouteEntity(
            id: routeData['id'] as String?,
            vehicleId: routeData['vehicle_id'] as String,
            startLocation: routeData['start_location'] as String? ?? '',
            endLocation: routeData['end_location'] as String? ?? '',
            driverName: routeData['driver_name'] as String?,
            clientName: routeData['client_name'] as String?,
            createdAt: routeData['created_at'] != null
                ? DateTime.parse(routeData['created_at'] as String)
                : null,
          );

          remittancesWithRoutes.add(
            RemittanceWithRouteEntity(
              remittance: remittance,
              route: route,
            ),
          );
        }
      }

      return Right(remittancesWithRoutes);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, RemittanceEntity>> getRemittanceById(String id) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('id', id)
          .single();

      final remittance = RemittanceModel.fromJson(response).toEntity();
      return Right(remittance);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure('Remisión no encontrada'));
      }
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, void>> markAsCollected(String id) async {
    try {
      await _supabase
          .from(_tableName)
          .update({
            'status': 'cobrado',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, RemittanceEntity>> createRemittance(RemittanceEntity remittance) async {
    try {
      final remittanceData = RemittanceModel.fromEntity(remittance).toJson();
      remittanceData.remove('id'); // No incluir id en la creación
      
      final response = await _supabase
          .from(_tableName)
          .insert(remittanceData)
          .select()
          .single();

      final createdRemittance = RemittanceModel.fromJson(response).toEntity();
      return Right(createdRemittance);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, RemittanceEntity>> updateRemittance(RemittanceEntity remittance) async {
    try {
      if (remittance.id == null) {
        return const Left(ValidationFailure('El ID de la remisión es requerido para actualizar'));
      }

      final remittanceData = RemittanceModel.fromEntity(remittance).toJson();
      remittanceData['updated_at'] = DateTime.now().toIso8601String();
      remittanceData.remove('id'); // No actualizar el id

      final response = await _supabase
          .from(_tableName)
          .update(remittanceData)
          .eq('id', remittance.id!)
          .select()
          .single();

      final updatedRemittance = RemittanceModel.fromJson(response).toEntity();
      return Right(updatedRemittance);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure('Remisión no encontrada'));
      }
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

  @override
  Future<Either<RemittanceFailure, List<RemittanceWithRouteEntity>>> getDriverPendingRemittances(String driverName) async {
    try {
      // Hacer JOIN con routes, filtrar por status pendiente
      final response = await _supabase
          .from(_tableName)
          .select('''
            *,
            routes:route_id (
              id,
              vehicle_id,
              start_location,
              end_location,
              driver_name,
              client_name,
              created_at
            )
          ''')
          .eq('status', 'pendiente')
          .order('created_at', ascending: false);

      final remittancesWithRoutes = <RemittanceWithRouteEntity>[];

      for (var item in response as List) {
        final remittance = RemittanceModel.fromJson(item).toEntity();
        
        // Filtrar por document_url NULL (sin foto adjunta)
        if (remittance.documentUrl != null && remittance.documentUrl!.isNotEmpty) {
          continue;
        }
        
        // Extraer datos de route del JOIN
        final routeData = item['routes'] as Map<String, dynamic>?;
        if (routeData != null) {
          final routeDriverName = routeData['driver_name'] as String?;
          
          // Filtrar por driver_name del route
          if (routeDriverName == driverName) {
            final route = RouteEntity(
              id: routeData['id'] as String?,
              vehicleId: routeData['vehicle_id'] as String,
              startLocation: routeData['start_location'] as String? ?? '',
              endLocation: routeData['end_location'] as String? ?? '',
              driverName: routeData['driver_name'] as String?,
              clientName: routeData['client_name'] as String?,
              createdAt: routeData['created_at'] != null
                  ? DateTime.parse(routeData['created_at'] as String)
                  : null,
            );

            remittancesWithRoutes.add(
              RemittanceWithRouteEntity(
                remittance: remittance,
                route: route,
              ),
            );
          }
        }
      }

      return Right(remittancesWithRoutes);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, String>> uploadMemorandumImage(List<int> fileBytes, String fileName) async {
    try {
      // Convertir List<int> a Uint8List
      final uint8List = Uint8List.fromList(fileBytes);
      
      // Subir usando uploadBinary que acepta Uint8List
      await _supabase.storage
          .from(_storageBucket)
          .uploadBinary(
            fileName, 
            uint8List, 
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );

      final imageUrl = _supabase.storage
          .from(_storageBucket)
          .getPublicUrl(fileName);

      return Right(imageUrl);
    } on StorageException catch (e) {
      return Left(StorageFailure(_mapStorageError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(StorageFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, void>> deleteMemorandumImage(String imageUrl) async {
    try {
      // Extraer el nombre del archivo de la URL
      final fileName = imageUrl.split('/').last.split('?').first;

      await _supabase.storage
          .from(_storageBucket)
          .remove([fileName]);

      return const Right(null);
    } on StorageException catch (e) {
      // Si el archivo no existe, no es un error crítico
      if (e.statusCode == '404' || e.message.contains('not found')) {
        return const Right(null);
      }
      return Left(StorageFailure(_mapStorageError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(StorageFailure(_mapGenericError(e)));
    }
  }

  String _mapStorageError(StorageException e) {
    if (e.statusCode == '413') {
      return 'La imagen es demasiado grande';
    }
    if (e.statusCode == '415') {
      return 'Formato de imagen no soportado';
    }
    return e.message.isNotEmpty ? e.message : 'Error al subir la imagen';
  }

  String _mapGenericError(dynamic e) {
    return e.toString().isNotEmpty ? e.toString() : 'Error desconocido';
  }
}

