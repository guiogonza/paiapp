import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/maintenance_entity.dart';
import 'package:pai_app/domain/failures/maintenance_failure.dart';

/// Interfaz del repositorio de mantenimiento
abstract class MaintenanceRepository {
  /// Obtiene el historial de mantenimiento de un vehículo
  Future<Either<MaintenanceFailure, List<MaintenanceEntity>>> getHistory(String vehicleId);

  /// Registra un nuevo mantenimiento
  /// Actualiza también el current_mileage del vehículo
  Future<Either<MaintenanceFailure, MaintenanceEntity>> registerMaintenance(
    MaintenanceEntity maintenance,
    double newMileage, // Nuevo kilometraje para actualizar en vehicles
  );

  /// Obtiene el kilometraje actual desde el GPS
  /// Parsea el XML <totaldistance> del API de GPS
  Future<Either<MaintenanceFailure, double?>> getLiveGpsMileage(String gpsDeviceId);
}

