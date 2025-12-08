import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/remittance_entity.dart';
import 'package:pai_app/domain/entities/remittance_with_route_entity.dart';
import 'package:pai_app/domain/failures/remittance_failure.dart';

abstract class RemittanceRepository {
  /// Obtiene todas las remisiones
  Future<Either<RemittanceFailure, List<RemittanceEntity>>> getRemittances();

  /// Obtiene las remisiones pendientes (status = 'pendiente')
  Future<Either<RemittanceFailure, List<RemittanceEntity>>> getPendingRemittances();

  /// Obtiene remisiones con información de rutas (JOIN)
  Future<Either<RemittanceFailure, List<RemittanceWithRouteEntity>>> getRemittancesWithRoutes();

  /// Obtiene remisiones pendientes con información de rutas (JOIN)
  Future<Either<RemittanceFailure, List<RemittanceWithRouteEntity>>> getPendingRemittancesWithRoutes();

  /// Obtiene una remisión por ID
  Future<Either<RemittanceFailure, RemittanceEntity>> getRemittanceById(String id);

  /// Actualiza el status de una remisión a 'cobrado'
  Future<Either<RemittanceFailure, void>> markAsCollected(String id);

  /// Crea una nueva remisión
  Future<Either<RemittanceFailure, RemittanceEntity>> createRemittance(RemittanceEntity remittance);

  /// Actualiza una remisión
  Future<Either<RemittanceFailure, RemittanceEntity>> updateRemittance(RemittanceEntity remittance);

  /// Obtiene remisiones pendientes del conductor (donde driver_name coincide y document_url es NULL)
  Future<Either<RemittanceFailure, List<RemittanceWithRouteEntity>>> getDriverPendingRemittances(String driverName);

  /// Sube una imagen del memorando a Storage
  Future<Either<RemittanceFailure, String>> uploadMemorandumImage(List<int> fileBytes, String fileName);

  /// Elimina una imagen del memorando de Storage
  Future<Either<RemittanceFailure, void>> deleteMemorandumImage(String imageUrl);
}

