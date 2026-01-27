import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';
import 'package:pai_app/domain/failures/vehicle_failure.dart';
import 'package:pai_app/domain/repositories/vehicle_repository.dart';
import 'package:pai_app/data/models/vehicle_model.dart';
import 'package:pai_app/data/services/local_api_client.dart';

class VehicleRepositoryImpl implements VehicleRepository {
  final LocalApiClient _localApi = LocalApiClient();
  static const String _tableName = 'vehicles';

  @override
  Future<Either<VehicleFailure, List<VehicleEntity>>> getVehicles() async {
    try {
      final response = await _localApi.getVehicles();

      final vehicles = response
          .map((json) => VehicleModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(vehicles);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('Sesión expirada') || errorMsg.contains('401')) {
        return Left(ValidationFailure(
          'No tienes permisos. Asegúrate de estar autenticado correctamente.'
        ));
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<VehicleFailure, VehicleEntity>> getVehicleById(
      String id) async {
    try {
      final response = await _localApi.getVehicleById(id);

      if (response == null) {
        return const Left(NotFoundFailure());
      }

      final vehicle = VehicleModel.fromJson(response);
      return Right(vehicle.toEntity());
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('404')) {
        return const Left(NotFoundFailure());
      }
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

      final response = await _localApi.createVehicle(json);

      final createdVehicle = VehicleModel.fromJson(response);
      return Right(createdVehicle.toEntity());
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('Sesión expirada') || errorMsg.contains('401')) {
        return Left(ValidationFailure(
          'No tienes permisos. Asegúrate de estar autenticado correctamente.'
        ));
      }
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

      final response = await _localApi.updateVehicle(vehicle.id!, json);

      final updatedVehicle = VehicleModel.fromJson(response);
      return Right(updatedVehicle.toEntity());
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('404')) {
        return const Left(NotFoundFailure());
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<VehicleFailure, void>> deleteVehicle(String id) async {
    try {
      await _localApi.deleteVehicle(id);
      return const Right(null);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('404')) {
        return const Left(NotFoundFailure());
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
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
    return 'Ocurrió un error inesperado: ${e.toString()}';
  }
}
