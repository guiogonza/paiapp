import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/vehicle_history_entity.dart';
import 'package:pai_app/domain/failures/vehicle_history_failure.dart';
import 'package:pai_app/domain/repositories/vehicle_history_repository.dart';
import 'package:pai_app/data/models/vehicle_history_model.dart';
import 'package:pai_app/data/services/local_api_client.dart';

class VehicleHistoryRepositoryImpl implements VehicleHistoryRepository {
  final LocalApiClient _localApi = LocalApiClient();
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

      // Insertar en lotes
      const batchSize = 100;
      for (var i = 0; i < historyData.length; i += batchSize) {
        final batch = historyData.skip(i).take(batchSize).toList();
        for (var item in batch) {
          await _localApi.post('/rest/v1/$_tableName', item);
        }
      }

      return const Right(null);
    } on SocketException catch (e) {
      return Left(NetworkFailure('Error de conexión: ${e.message}'));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<VehicleHistoryFailure, List<VehicleHistoryEntity>>>
  getVehicleHistory(String vehicleId, {DateTime? from, DateTime? to}) async {
    try {
      var url =
          '/rest/v1/$_tableName?vehicle_id=eq.$vehicleId&order=timestamp.desc';

      // Aplicar filtros de fecha si se proporcionan
      if (from != null) {
        url += '&timestamp=gte.${from.toIso8601String()}';
      }
      if (to != null) {
        url += '&timestamp=lte.${to.toIso8601String()}';
      }

      final response = await _localApi.get(url);

      final history = (response as List)
          .map((json) => VehicleHistoryModel.fromJson(json).toEntity())
          .toList();

      return Right(history);
    } on SocketException catch (e) {
      return Left(NetworkFailure('Error de conexión: ${e.message}'));
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('not found') ||
          errorMsg.contains('does not exist')) {
        return Left(NotFoundFailure('La tabla vehicle_history no existe.'));
      }
      return Left(UnknownFailure(errorMsg));
    }
  }

  @override
  Future<Either<VehicleHistoryFailure, List<VehicleHistoryEntity>>>
  getAllVehicleHistory({DateTime? from, DateTime? to}) async {
    try {
      var url = '/rest/v1/$_tableName?order=timestamp.desc';

      // Aplicar filtros de fecha si se proporcionan
      if (from != null) {
        url += '&timestamp=gte.${from.toIso8601String()}';
      }
      if (to != null) {
        url += '&timestamp=lte.${to.toIso8601String()}';
      }

      final response = await _localApi.get(url);

      final history = (response as List)
          .map((json) => VehicleHistoryModel.fromJson(json).toEntity())
          .toList();

      return Right(history);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
