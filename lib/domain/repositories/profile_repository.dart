import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/profile_entity.dart';
import 'package:pai_app/domain/failures/profile_failure.dart';

abstract class ProfileRepository {
  /// Obtiene el perfil del usuario actualmente autenticado
  Future<Either<ProfileFailure, ProfileEntity>> getCurrentUserProfile();
  
  /// Obtiene un perfil por ID de usuario
  Future<Either<ProfileFailure, ProfileEntity>> getProfileByUserId(String userId);
}

