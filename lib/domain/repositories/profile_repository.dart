import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/profile_entity.dart';
import 'package:pai_app/domain/failures/profile_failure.dart';

abstract class ProfileRepository {
  /// Obtiene el perfil del usuario actualmente autenticado
  Future<Either<ProfileFailure, ProfileEntity>> getCurrentUserProfile();

  /// Obtiene un perfil por ID de usuario
  Future<Either<ProfileFailure, ProfileEntity>> getProfileByUserId(
    String userId,
  );

  /// Obtiene la lista de todos los conductores (usuarios con role 'driver')
  /// Retorna un Map donde la clave es el id del usuario y el valor es el email
  Future<Either<ProfileFailure, Map<String, String>>> getDriversList();

  /// Crea un nuevo conductor (usuario con role 'driver')
  /// Crea el usuario en auth.users y luego crea el perfil en profiles con role='driver'
  Future<Either<ProfileFailure, ProfileEntity>> createDriver(
    String email,
    String password, {
    String? fullName,
    String? assignedVehicleId,
  });

  /// Actualiza el vehículo asignado a un conductor (profiles.assigned_vehicle_id)
  Future<Either<ProfileFailure, Unit>> updateAssignedVehicle({
    required String driverId,
    String? vehicleId,
  });

  /// Obtiene todos los conductores con su vehículo asignado (si existe)
  Future<Either<ProfileFailure, List<ProfileEntity>>>
  getDriversWithAssignedVehicle();

  /// Elimina un conductor (usuario con role 'driver')
  Future<Either<ProfileFailure, Unit>> deleteDriver(String driverId);
}
