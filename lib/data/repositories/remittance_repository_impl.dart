import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/remittance_entity.dart';
import 'package:pai_app/domain/entities/remittance_with_route_entity.dart';
import 'package:pai_app/domain/entities/route_entity.dart';
import 'package:pai_app/domain/failures/remittance_failure.dart';
import 'package:pai_app/domain/repositories/remittance_repository.dart';
import 'package:pai_app/data/models/remittance_model.dart';
import 'package:pai_app/data/services/local_api_client.dart';

class RemittanceRepositoryImpl implements RemittanceRepository {
  final LocalApiClient _localApi = LocalApiClient();
  static const String _tableName =
      'remisiones'; // Nombre correcto en PostgreSQL

  // Helper para parsear números que pueden venir como String
  double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  @override
  Future<Either<RemittanceFailure, List<RemittanceEntity>>>
  getRemittances() async {
    try {
      final response = await _localApi.get(
        '/rest/v1/$_tableName?order=created_at.desc',
      );

      final remittances = (response as List)
          .map((json) => RemittanceModel.fromJson(json).toEntity())
          .toList();

      return Right(remittances);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, List<RemittanceEntity>>>
  getPendingRemittances() async {
    try {
      final response = await _localApi.get(
        '/rest/v1/$_tableName?status=eq.pendiente&order=created_at.desc',
      );

      final remittances = (response as List)
          .map((json) => RemittanceModel.fromJson(json).toEntity())
          .toList();

      return Right(remittances);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, List<RemittanceWithRouteEntity>>>
  getRemittancesWithRoutes() async {
    try {
      // Obtener remisiones
      final remittancesResponse = await _localApi.get(
        '/rest/v1/$_tableName?order=created_at.desc',
      );

      final remittancesWithRoutes = <RemittanceWithRouteEntity>[];

      for (var item in remittancesResponse as List) {
        final remittance = RemittanceModel.fromJson(item).toEntity();
        final tripId = remittance.tripId;

        if (tripId.isEmpty) continue;

        try {
          // Obtener el route correspondiente
          final routeResponse = await _localApi.get(
            '/rest/v1/routes?id=eq.$tripId',
          );

          if (routeResponse is List && routeResponse.isNotEmpty) {
            final routeData = routeResponse.first;
            final route = RouteEntity(
              id: routeData['id'] as String?,
              vehicleId: routeData['vehicle_id'] as String,
              startLocation: routeData['start_location'] as String? ?? '',
              endLocation: routeData['end_location'] as String? ?? '',
              driverName: routeData['driver_name'] as String?,
              clientName: routeData['client_name'] as String?,
              revenueAmount: routeData['revenue_amount'] != null
                  ? _parseDouble(routeData['revenue_amount'])
                  : null,
              createdAt: routeData['created_at'] != null
                  ? DateTime.parse(routeData['created_at'] as String)
                  : null,
            );

            remittancesWithRoutes.add(
              RemittanceWithRouteEntity(remittance: remittance, route: route),
            );
          }
        } catch (e) {
          print('Error al obtener route $tripId: $e');
          continue;
        }
      }

      return Right(remittancesWithRoutes);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, List<RemittanceWithRouteEntity>>>
  getPendingRemittancesWithRoutes() async {
    try {
      // Obtener remisiones con estados: pendiente_completar, pendiente_cobrar, cobrado
      final remittancesResponse = await _localApi.get(
        '/rest/v1/$_tableName?or=(status.eq.pendiente_completar,status.eq.pendiente_cobrar,status.eq.cobrado)&order=created_at.desc',
      );

      final remittancesWithRoutes = <RemittanceWithRouteEntity>[];

      for (var remittanceData in remittancesResponse as List) {
        final remittance = RemittanceModel.fromJson(remittanceData).toEntity();
        final tripId = remittance.tripId;

        if (tripId.isEmpty) continue;

        try {
          final routeResponse = await _localApi.get(
            '/rest/v1/routes?id=eq.$tripId',
          );

          if (routeResponse is List && routeResponse.isNotEmpty) {
            final routeData = routeResponse.first;
            final route = RouteEntity(
              id: routeData['id'] as String?,
              vehicleId: routeData['vehicle_id'] as String,
              startLocation: routeData['start_location'] as String? ?? '',
              endLocation: routeData['end_location'] as String? ?? '',
              driverName: routeData['driver_name'] as String?,
              clientName: routeData['client_name'] as String?,
              revenueAmount: routeData['revenue_amount'] != null
                  ? _parseDouble(routeData['revenue_amount'])
                  : null,
              createdAt: routeData['created_at'] != null
                  ? DateTime.parse(routeData['created_at'] as String)
                  : null,
            );

            remittancesWithRoutes.add(
              RemittanceWithRouteEntity(remittance: remittance, route: route),
            );
          }
        } catch (e) {
          print('Error al obtener route $tripId: $e');
          continue;
        }
      }

      return Right(remittancesWithRoutes);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, RemittanceEntity>> getRemittanceById(
    String id,
  ) async {
    try {
      final response = await _localApi.get('/rest/v1/$_tableName?id=eq.$id');

      if (response is List && response.isEmpty) {
        return const Left(NotFoundFailure('Remisión no encontrada'));
      }

      final data = response is List ? response.first : response;
      final remittance = RemittanceModel.fromJson(data).toEntity();
      return Right(remittance);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      if (e.toString().contains('not found') || e.toString().contains('404')) {
        return const Left(NotFoundFailure('Remisión no encontrada'));
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, void>> markAsCollected(String id) async {
    try {
      await _localApi.patch('/rest/v1/$_tableName', id, {
        'status': 'cobrado',
        'updated_at': DateTime.now().toIso8601String(),
      });

      return const Right(null);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, RemittanceEntity>> createRemittance(
    RemittanceEntity remittance,
  ) async {
    try {
      final remittanceData = RemittanceModel.fromEntity(remittance).toJson();
      remittanceData.remove('id');

      final response = await _localApi.post(
        '/rest/v1/$_tableName',
        remittanceData,
      );

      final createdRemittance = RemittanceModel.fromJson(response).toEntity();
      return Right(createdRemittance);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, RemittanceEntity?>> getRemittanceByTripId(
    String tripId,
  ) async {
    try {
      final response = await _localApi.get(
        '/rest/v1/$_tableName?trip_id=eq.$tripId',
      );

      if (response is List && response.isEmpty) {
        return const Right(null);
      }

      final data = response is List ? response.first : response;
      final remittance = RemittanceModel.fromJson(data).toEntity();
      return Right(remittance);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, RemittanceEntity>> updateRemittance(
    RemittanceEntity remittance,
  ) async {
    try {
      if (remittance.id == null) {
        return const Left(
          ValidationFailure(
            'El ID de la remisión es requerido para actualizar',
          ),
        );
      }

      final remittanceData = RemittanceModel.fromEntity(remittance).toJson();
      remittanceData.remove('id');
      remittanceData['updated_at'] = DateTime.now().toIso8601String();

      await _localApi.patch(
        '/rest/v1/$_tableName',
        remittance.id!,
        remittanceData,
      );

      // Obtener el registro actualizado
      final updatedResponse = await _localApi.get(
        '/rest/v1/$_tableName?id=eq.${remittance.id}',
      );
      final updatedData = updatedResponse is List
          ? updatedResponse.first
          : updatedResponse;
      final updatedRemittance = RemittanceModel.fromJson(
        updatedData,
      ).toEntity();

      return Right(updatedRemittance);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      if (e.toString().contains('not found') || e.toString().contains('404')) {
        return const Left(NotFoundFailure('Remisión no encontrada'));
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, List<RemittanceWithRouteEntity>>>
  getDriverPendingRemittances(String driverName) async {
    try {
      // Obtener remisiones pendientes
      final remittancesResponse = await _localApi.get(
        '/rest/v1/$_tableName?status=eq.pendiente&order=created_at.desc',
      );

      final remittancesWithRoutes = <RemittanceWithRouteEntity>[];

      for (var remittanceData in remittancesResponse as List) {
        final remittance = RemittanceModel.fromJson(remittanceData).toEntity();

        // Filtrar por receipt_url NULL (sin foto adjunta)
        if (remittance.receiptUrl != null &&
            remittance.receiptUrl!.isNotEmpty) {
          continue;
        }

        final tripId = remittance.tripId;
        if (tripId.isEmpty) continue;

        try {
          final routeResponse = await _localApi.get(
            '/rest/v1/routes?id=eq.$tripId',
          );

          if (routeResponse is List && routeResponse.isNotEmpty) {
            final routeData = routeResponse.first;
            final routeDriverName = routeData['driver_name'] as String?;

            // Filtrar por driver_name del route
            if (routeDriverName != null &&
                routeDriverName.toLowerCase().trim() ==
                    driverName.toLowerCase().trim()) {
              final route = RouteEntity(
                id: routeData['id'] as String?,
                vehicleId: routeData['vehicle_id'] as String,
                startLocation: routeData['start_location'] as String? ?? '',
                endLocation: routeData['end_location'] as String? ?? '',
                driverName: routeData['driver_name'] as String?,
                clientName: routeData['client_name'] as String?,
                revenueAmount: routeData['revenue_amount'] != null
                    ? _parseDouble(routeData['revenue_amount'])
                    : null,
                createdAt: routeData['created_at'] != null
                    ? DateTime.parse(routeData['created_at'] as String)
                    : null,
              );

              remittancesWithRoutes.add(
                RemittanceWithRouteEntity(remittance: remittance, route: route),
              );
            }
          }
        } catch (e) {
          print('Error al obtener route $tripId: $e');
          continue;
        }
      }

      return Right(remittancesWithRoutes);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, String>> uploadMemorandumImage(
    List<int> fileBytes,
    String fileName,
  ) async {
    try {
      // TODO: Implementar upload de imágenes con la API local
      return const Left(
        StorageFailure('Upload de imágenes no disponible en modo local'),
      );
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(StorageFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<RemittanceFailure, void>> deleteMemorandumImage(
    String imageUrl,
  ) async {
    try {
      // TODO: Implementar delete de imágenes con la API local
      return const Right(null);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(StorageFailure(_mapGenericError(e)));
    }
  }

  String _mapGenericError(dynamic e) {
    return e.toString().isNotEmpty ? e.toString() : 'Error desconocido';
  }
}
