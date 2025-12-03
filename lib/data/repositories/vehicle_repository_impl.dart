import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';
import 'package:pai_app/domain/failures/vehicle_failure.dart';
import 'package:pai_app/domain/repositories/vehicle_repository.dart';
import 'package:pai_app/data/models/vehicle_model.dart';

class VehicleRepositoryImpl implements VehicleRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'vehicles';

  @override
  Future<Either<VehicleFailure, List<VehicleEntity>>> getVehicles() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .order('created_at', ascending: false);

      final vehicles = (response as List)
          .map((json) => VehicleModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(vehicles);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<VehicleFailure, VehicleEntity>> getVehicleById(
      String id) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return const Left(NotFoundFailure());
      }

      final vehicle = VehicleModel.fromJson(response as Map<String, dynamic>);
      return Right(vehicle.toEntity());
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
  Future<Either<VehicleFailure, VehicleEntity>> createVehicle(
      VehicleEntity vehicle) async {
    try {
      final model = VehicleModel.fromEntity(vehicle);
      final json = model.toJson();
      json.remove('id'); // No incluir id en la creación

      final response = await _supabase
          .from(_tableName)
          .insert(json)
          .select()
          .single();

      final createdVehicle =
          VehicleModel.fromJson(response as Map<String, dynamic>);
      return Right(createdVehicle.toEntity());
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<VehicleFailure, VehicleEntity>> updateVehicle(
      VehicleEntity vehicle) async {
    try {
      if (vehicle.id == null) {
        return const Left(ValidationFailure('El ID del vehículo es requerido'));
      }

      final model = VehicleModel.fromEntity(vehicle);
      final json = model.toJson();
      json.remove('id'); // No actualizar el id

      final response = await _supabase
          .from(_tableName)
          .update(json)
          .eq('id', vehicle.id!)
          .select()
          .single();

      final updatedVehicle =
          VehicleModel.fromJson(response as Map<String, dynamic>);
      return Right(updatedVehicle.toEntity());
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
  Future<Either<VehicleFailure, void>> deleteVehicle(String id) async {
    try {
      await _supabase.from(_tableName).delete().eq('id', id);

      return const Right(null);
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

  /// Mapea errores de Postgrest a mensajes amigables
  String _mapPostgrestError(PostgrestException e) {
    // Errores comunes de Supabase/Postgrest
    if (e.code == '23505') {
      return 'Ya existe un vehículo con esta placa';
    }
    if (e.code == '23503') {
      return 'Error de integridad de datos';
    }
    if (e.code == 'PGRST301') {
      return 'No tienes permisos para realizar esta acción';
    }
    return e.message.isNotEmpty ? e.message : 'Error en la base de datos';
  }

  /// Mapea errores genéricos a mensajes amigables
  String _mapGenericError(dynamic e) {
    final errorString = e.toString().toLowerCase();
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket')) {
      return 'Error de conexión';
    }
    if (errorString.contains('timeout')) {
      return 'La operación tardó demasiado. Intenta nuevamente';
    }
    return 'Ocurrió un error inesperado';
  }
}
