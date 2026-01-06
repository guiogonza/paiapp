import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/domain/entities/trip_entity.dart';
import 'package:pai_app/domain/failures/trip_failure.dart';
import 'package:pai_app/domain/repositories/trip_repository.dart';
import 'package:pai_app/data/models/trip_model.dart';

class TripRepositoryImpl implements TripRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  // CRÍTICO: Mantener conexión a la tabla 'routes' en Supabase
  static const String _tableName = 'routes';

  @override
  Future<Either<TripFailure, List<TripEntity>>> getTrips() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .order('created_at', ascending: false);

      final trips = (response as List)
          .map((json) => TripModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(trips);
    } on PostgrestException catch (e) {
      // Si el error es de RLS, dar un mensaje más claro
      if (e.message.contains('row-level security') || 
          e.message.contains('policy') ||
          e.code == 'PGRST301') {
        return Left(ValidationFailure(
          'No tienes permisos. Asegúrate de estar autenticado correctamente.'
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
  Future<Either<TripFailure, TripEntity>> getTripById(String id) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return const Left(NotFoundFailure());
      }

      final trip = TripModel.fromJson(response);
      return Right(trip.toEntity());
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
  Future<Either<TripFailure, TripEntity>> createTrip(
      TripEntity trip) async {
    try {
      final model = TripModel.fromEntity(trip);
      final json = model.toJson();
      json.remove('id'); // No incluir id en la creación

      final response = await _supabase
          .from(_tableName)
          .insert(json)
          .select()
          .single();

      final createdTrip = TripModel.fromJson(response);
      return Right(createdTrip.toEntity());
    } on PostgrestException catch (e) {
      // Si el error es de RLS, dar un mensaje más claro
      if (e.message.contains('row-level security') || 
          e.message.contains('policy') ||
          e.code == 'PGRST301') {
        return Left(ValidationFailure(
          'No tienes permisos. Asegúrate de estar autenticado correctamente.'
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
  Future<Either<TripFailure, TripEntity>> updateTrip(
      TripEntity trip) async {
    try {
      if (trip.id == null) {
        return const Left(ValidationFailure('El ID del viaje es requerido'));
      }

      final model = TripModel.fromEntity(trip);
      final json = model.toJson();
      json.remove('id'); // No actualizar el id

      final response = await _supabase
          .from(_tableName)
          .update(json)
          .eq('id', trip.id!)
          .select()
          .single();

      final updatedTrip = TripModel.fromJson(response);
      return Right(updatedTrip.toEntity());
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
  Future<Either<TripFailure, void>> deleteTrip(String id) async {
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
      return 'Ya existe un viaje con estos datos';
    }
    if (e.code == '23503') {
      return 'Error de integridad de datos. Verifica que el vehículo exista';
    }
    if (e.code == 'PGRST301') {
      return 'No tienes permisos para realizar esta acción';
    }
    // Error de columna no encontrada
    if (e.message.contains('column') && e.message.contains('does not exist')) {
      return 'Error: Faltan columnas en la tabla. Agrega las columnas: start_location, end_location, budget_amount a la tabla routes en Supabase';
    }
    if (e.message.contains('column') && e.message.contains('not found')) {
      return 'Error: Faltan columnas en la tabla. Agrega las columnas: start_location, end_location, budget_amount a la tabla routes en Supabase';
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


