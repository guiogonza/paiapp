import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/domain/entities/vehicle_history_entity.dart';
import 'package:pai_app/domain/failures/vehicle_history_failure.dart';
import 'package:pai_app/domain/repositories/vehicle_history_repository.dart';
import 'package:pai_app/data/models/vehicle_history_model.dart';

class VehicleHistoryRepositoryImpl implements VehicleHistoryRepository {
  // TODO: Remover Supabase - ya no se usa
  // final SupabaseClient _supabase = Supabase.instance.client;

  // Getter temporal para evitar errores - lanzará error si se usa
  dynamic get _supabase =>
      throw UnimplementedError('Supabase ya no se usa - migrado a PostgreSQL');
  static const String _tableName = 'vehicle_history';

  @override
  Future<Either<VehicleHistoryFailure, void>> saveVehicleHistory(
    List<VehicleHistoryEntity> history,
  ) async {
    try {
      if (history.isEmpty) {
        return const Right(null);
      }

      // Convertir a modelos y luego a JSON
      final historyData = history
          .map((entity) => VehicleHistoryModel.fromEntity(entity).toJson())
          .toList();

      // Insertar en lotes (Supabase permite hasta 1000 registros por inserción)
      const batchSize = 1000;
      for (var i = 0; i < historyData.length; i += batchSize) {
        final batch = historyData.skip(i).take(batchSize).toList();
        await _supabase.from(_tableName).insert(batch);
      }

      return const Right(null);
    } on PostgrestException catch (e) {
      // Error específico: tabla no existe
      if (e.code == 'PGRST116' ||
          e.message.contains('does not exist') ||
          (e.message.contains('relation') &&
              e.message.contains('does not exist'))) {
        return Left(
          DatabaseFailure(
            'La tabla vehicle_history no existe. Por favor, créala en Supabase usando el script SQL proporcionado.',
          ),
        );
      }
      // Error de permisos
      if (e.code == 'PGRST301' ||
          e.message.contains('permission denied') ||
          e.message.contains('RLS')) {
        return Left(
          DatabaseFailure(
            'Error de permisos. Verifica las políticas RLS en Supabase.',
          ),
        );
      }
      return Left(DatabaseFailure(e.message));
    } on SocketException catch (e) {
      return Left(NetworkFailure('Error de conexión: ${e.message}'));
    } catch (e) {
      final errorMsg = e.toString();
      // Detectar errores de CORS o conexión
      if (errorMsg.contains('Failed to fetch') ||
          errorMsg.contains('CORS') ||
          errorMsg.contains('NetworkError') ||
          errorMsg.contains('api.supabase.com')) {
        return Left(
          NetworkFailure(
            'Error de conexión con Supabase. Verifica tu conexión a internet y que el proyecto de Supabase esté activo.',
          ),
        );
      }
      return Left(UnknownFailure(errorMsg));
    }
  }

  @override
  Future<Either<VehicleHistoryFailure, List<VehicleHistoryEntity>>>
  getVehicleHistory(String vehicleId, {DateTime? from, DateTime? to}) async {
    try {
      var query = _supabase
          .from(_tableName)
          .select()
          .eq('vehicle_id', vehicleId);

      // Aplicar filtros de fecha si se proporcionan (antes del order)
      if (from != null) {
        query = query.gte('timestamp', from.toIso8601String());
      }
      if (to != null) {
        query = query.lte('timestamp', to.toIso8601String());
      }

      // Aplicar ordenamiento al final
      final response = await query.order('timestamp', ascending: false);

      final history = (response as List)
          .map((json) => VehicleHistoryModel.fromJson(json).toEntity())
          .toList();

      return Right(history);
    } on PostgrestException catch (e) {
      // Error específico: tabla no existe
      if (e.code == 'PGRST116' ||
          e.message.contains('does not exist') ||
          e.message.contains('relation') &&
              e.message.contains('does not exist')) {
        return Left(
          NotFoundFailure(
            'La tabla vehicle_history no existe. Por favor, créala en Supabase usando el script SQL proporcionado.',
          ),
        );
      }
      // Error de permisos
      if (e.code == 'PGRST301' ||
          e.message.contains('permission denied') ||
          e.message.contains('RLS')) {
        return Left(
          DatabaseFailure(
            'Error de permisos. Verifica las políticas RLS en Supabase.',
          ),
        );
      }
      return Left(DatabaseFailure(e.message));
    } on SocketException catch (e) {
      return Left(NetworkFailure('Error de conexión: ${e.message}'));
    } catch (e) {
      final errorMsg = e.toString();
      // Detectar errores de CORS o conexión
      if (errorMsg.contains('Failed to fetch') ||
          errorMsg.contains('CORS') ||
          errorMsg.contains('NetworkError') ||
          errorMsg.contains('api.supabase.com')) {
        return Left(
          NetworkFailure(
            'Error de conexión con Supabase. Verifica tu conexión a internet y que el proyecto de Supabase esté activo.',
          ),
        );
      }
      return Left(UnknownFailure(errorMsg));
    }
  }

  @override
  Future<Either<VehicleHistoryFailure, List<VehicleHistoryEntity>>>
  getAllVehicleHistory({DateTime? from, DateTime? to}) async {
    try {
      var query = _supabase.from(_tableName).select();

      // Aplicar filtros de fecha si se proporcionan (antes del order)
      if (from != null) {
        query = query.gte('timestamp', from.toIso8601String());
      }
      if (to != null) {
        query = query.lte('timestamp', to.toIso8601String());
      }

      // Aplicar ordenamiento al final
      final response = await query.order('timestamp', ascending: false);

      final history = (response as List)
          .map((json) => VehicleHistoryModel.fromJson(json).toEntity())
          .toList();

      return Right(history);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
