import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';
import 'package:pai_app/domain/failures/vehicle_failure.dart';

abstract class VehicleRepository {
  Future<Either<VehicleFailure, List<VehicleEntity>>> getVehicles();
  Future<Either<VehicleFailure, VehicleEntity>> getVehicleById(String id);
  Future<Either<VehicleFailure, VehicleEntity>> createVehicle(
      VehicleEntity vehicle);
  Future<Either<VehicleFailure, VehicleEntity>> updateVehicle(
      VehicleEntity vehicle);
  Future<Either<VehicleFailure, void>> deleteVehicle(String id);
}

