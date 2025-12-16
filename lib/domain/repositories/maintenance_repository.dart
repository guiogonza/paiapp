import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/maintenance_entity.dart';
import 'package:pai_app/domain/failures/maintenance_failure.dart';

/// Interfaz del repositorio de mantenimiento
abstract class MaintenanceRepository {
  /// Obtiene el historial de mantenimiento de un vehículo
  Future<Either<MaintenanceFailure, List<MaintenanceEntity>>> getHistory(String vehicleId);

  /// Registra un nuevo mantenimiento
  /// Actualiza también el current_mileage del vehículo con km_at_service
  Future<Either<MaintenanceFailure, MaintenanceEntity>> registerMaintenance(
    MaintenanceEntity maintenance,
  );

  /// Obtiene el kilometraje actual desde el GPS
  /// Parsea el XML <totaldistance> del API de GPS
  Future<Either<MaintenanceFailure, double?>> getLiveGpsMileage(String gpsDeviceId);

  /// Obtiene los mantenimientos con alertas pendientes
  /// Alertas por km: cuando faltan 2000 km o menos para next_change_km
  /// Alertas por fecha: cuando faltan 30 días o menos para alert_date
  Future<Either<MaintenanceFailure, List<MaintenanceEntity>>> getPendingAlerts();

  /// Verifica alertas activas para el usuario actual
  /// Retorna el número de alertas activas (current_km >= alert_km O current_date >= alert_date)
  Future<Either<MaintenanceFailure, int>> checkActiveAlerts();

  /// Obtiene todos los mantenimientos (para cálculos financieros)
  Future<Either<MaintenanceFailure, List<MaintenanceEntity>>> getAllMaintenance();
}

