import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/trip_entity.dart';
import 'package:pai_app/domain/failures/trip_failure.dart';
import 'package:pai_app/domain/repositories/trip_repository.dart';
import 'package:pai_app/data/models/trip_model.dart';
import 'package:pai_app/data/services/local_api_client.dart';

class TripRepositoryImpl implements TripRepository {
  final LocalApiClient _localApi = LocalApiClient();
  static const String _tableName = 'trips';

  @override
  Future<Either<TripFailure, List<TripEntity>>> getTrips() async {
    try {
      final response = await _localApi.getTrips();

      final trips = response
          .map((json) => TripModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(trips);
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
  Future<Either<TripFailure, TripEntity>> getTripById(String id) async {
    try {
      final response = await _localApi.getTripById(id);

      if (response == null) {
        return const Left(NotFoundFailure());
      }

      final trip = TripModel.fromJson(response);
      return Right(trip.toEntity());
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
  Future<Either<TripFailure, TripEntity>> createTrip(TripEntity trip) async {
    try {
      final model = TripModel.fromEntity(trip);
      final json = model.toJson();
      json.remove('id'); // No incluir id en la creación

      final response = await _localApi.createTrip(json);

      final createdTrip = TripModel.fromJson(response);
      return Right(createdTrip.toEntity());
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
  Future<Either<TripFailure, TripEntity>> updateTrip(TripEntity trip) async {
    try {
      if (trip.id == null) {
        return const Left(ValidationFailure('El ID del viaje es requerido'));
      }

      final model = TripModel.fromEntity(trip);
      final json = model.toJson();
      json.remove('id'); // No actualizar el id

      final response = await _localApi.updateTrip(trip.id!, json);

      final updatedTrip = TripModel.fromJson(response);
      return Right(updatedTrip.toEntity());
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
  Future<Either<TripFailure, void>> deleteTrip(String id) async {
    try {
      await _localApi.deleteTrip(id);
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
