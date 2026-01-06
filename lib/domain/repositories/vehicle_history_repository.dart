import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/vehicle_history_entity.dart';
import 'package:pai_app/domain/failures/vehicle_history_failure.dart';

abstract class VehicleHistoryRepository {
  /// Guarda el historial de un vehículo en la base de datos
  Future<Either<VehicleHistoryFailure, void>> saveVehicleHistory(
    List<VehicleHistoryEntity> history,
  );

  /// Obtiene el historial de un vehículo desde la base de datos
  Future<Either<VehicleHistoryFailure, List<VehicleHistoryEntity>>> getVehicleHistory(
    String vehicleId, {
    DateTime? from,
    DateTime? to,
  });

  /// Obtiene el historial de todos los vehículos
  Future<Either<VehicleHistoryFailure, List<VehicleHistoryEntity>>> getAllVehicleHistory({
    DateTime? from,
    DateTime? to,
  });
}


