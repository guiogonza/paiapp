import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/profile_entity.dart';
import 'package:pai_app/domain/failures/profile_failure.dart';
import 'package:pai_app/domain/repositories/profile_repository.dart';
import 'package:pai_app/data/models/profile_model.dart';
import 'package:pai_app/data/services/local_api_client.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final LocalApiClient _localApi = LocalApiClient();
  static const String _tableName = 'profiles';

  @override
  Future<Either<ProfileFailure, ProfileEntity>> getCurrentUserProfile() async {
    try {
      // Usar LocalApiClient en lugar de Supabase
      final currentUser = _localApi.currentUser;
      if (currentUser == null) {
        return const Left(NotFoundFailure('No hay usuario autenticado'));
      }

      final userId = currentUser['id']?.toString();
      if (userId == null) {
        return const Left(NotFoundFailure('ID de usuario no encontrado'));
      }

      return await getProfileByUserId(userId);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ProfileFailure, Unit>> updateAssignedVehicle({
    required String driverId,
    String? vehicleId,
  }) async {
    try {
      print('🔄 Actualizando vehículo asignado...');
      print('   Driver ID: $driverId');
      print('   Vehicle ID: $vehicleId');

      // Usar la API local de PostgreSQL
      await _localApi.patch('/rest/v1/profiles', driverId, {
        'assigned_vehicle_id': vehicleId,
      });

      print('✅ Vehículo asignado actualizado correctamente');
      return const Right(unit);
    } on SocketException catch (_) {
      print('❌ Error de red al actualizar vehículo asignado');
      return const Left(NetworkFailure());
    } catch (e) {
      print('❌ Error al actualizar vehículo asignado: $e');
      return Left(DatabaseFailure('Error al actualizar vehículo: $e'));
    }
  }

  @override
  Future<Either<ProfileFailure, List<ProfileEntity>>>
  getDriversWithAssignedVehicle() async {
    try {
      print('🔍 Obteniendo conductores con vehículos asignados...');

      // Usar la API local de PostgreSQL
      final response = await _localApi.getDrivers();

      final profilesList = <ProfileEntity>[];
      for (var profileData in response) {
        final profile = ProfileEntity(
          id: profileData['id'] ?? '',
          userId: profileData['id'] ?? '',
          email: profileData['email'] ?? '',
          fullName: profileData['full_name'] ?? '',
          role: profileData['role'] ?? 'driver',
          assignedVehicleId: profileData['assigned_vehicle_id'],
          createdAt: profileData['created_at'] != null
              ? DateTime.tryParse(profileData['created_at'])
              : DateTime.now(),
        );
        profilesList.add(profile);
      }

      print('✅ ${profilesList.length} conductores con vehículos encontrados');
      return Right(profilesList);
    } on SocketException catch (_) {
      print('❌ Error de red al obtener conductores');
      return const Left(NetworkFailure());
    } catch (e) {
      print('❌ Error al obtener conductores: $e');
      return Left(DatabaseFailure('Error al obtener conductores: $e'));
    }
  }

  @override
  Future<Either<ProfileFailure, ProfileEntity>> getProfileByUserId(
    String userId,
  ) async {
    try {
      // Usar LocalApiClient en lugar de Supabase
      final response = await _localApi.get('/rest/v1/profiles?id=eq.$userId');

      if (response is List && response.isEmpty) {
        return const Left(NotFoundFailure('Perfil no encontrado'));
      }

      final profileData = response is List ? response.first : response;
      final profile = ProfileModel.fromJson(profileData);
      return Right(profile.toEntity());
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      if (e.toString().contains('not found') || e.toString().contains('404')) {
        return const Left(NotFoundFailure('Perfil no encontrado'));
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ProfileFailure, ProfileEntity>> getProfileByEmail(
    String email,
  ) async {
    try {
      // Usar LocalApiClient en lugar de Supabase
      final response = await _localApi.get('/rest/v1/profiles?email=eq.$email');

      if (response is List && response.isEmpty) {
        return const Left(NotFoundFailure('Perfil no encontrado'));
      }

      final profileData = response is List ? response.first : response;
      final profile = ProfileModel.fromJson(profileData);
      return Right(profile.toEntity());
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      if (e.toString().contains('not found') || e.toString().contains('404')) {
        return const Left(NotFoundFailure('Perfil no encontrado'));
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ProfileFailure, Map<String, String>>> getDriversList() async {
    try {
      // Usar la API local de PostgreSQL
      print('🔍 Buscando conductores en PostgreSQL local...');

      final response = await _localApi.getDrivers();

      print(
        '📊 Respuesta de PostgreSQL: ${response.length} registros encontrados',
      );
      print('📊 Tipo de respuesta: ${response.runtimeType}');

      // Debug: mostrar la respuesta completa
      if (response.isNotEmpty) {
        print('📋 Primer registro de ejemplo: ${response[0]}');
        print('📋 Tipo del primer registro: ${response[0].runtimeType}');
      } else {
        print('⚠️ No se encontraron registros con role="driver"');
      }

      final driversMap = <String, String>{};

      // Asegurar que response sea una List
      final profilesList = response as List;
      print('📋 Procesando ${profilesList.length} perfiles...');

      for (var index = 0; index < profilesList.length; index++) {
        final profileRaw = profilesList[index];

        // Asegurar que profile sea un Map
        if (profileRaw is! Map<String, dynamic>) {
          print(
            '⚠️ Perfil en índice $index no es un Map: ${profileRaw.runtimeType}',
          );
          print('   Contenido: $profileRaw');
          continue;
        }

        final profile = profileRaw;

        // Extraer campos directamente del Map
        // profiles ahora tiene las columnas email y full_name
        final profileId = profile['id']?.toString();
        final email = profile['email']?.toString();
        final fullName = profile['full_name']?.toString();
        final role = profile['role']?.toString();

        // Diagnóstico especial para pepe@pai.com
        if (email != null && email.toLowerCase().contains('pepe')) {
          print(
            '🔍 ENCONTRADO PEPE: id="$profileId", email="$email", role="$role"',
          );
          print('   Tipo de role: ${role.runtimeType}');
          print('   Role normalizado: "${role?.trim().toLowerCase()}"');
          print(
            '   Comparación con "driver": ${role?.trim().toLowerCase() == 'driver'}',
          );
        }

        print(
          '👤 Perfil[$index]: id="$profileId", email="$email", full_name="$fullName", role="$role"',
        );

        // Validación: normalizar el role (trim y lowercase) para comparación robusta
        final normalizedRole = role?.trim().toLowerCase();

        // Validación estricta: debe tener id, email y role='driver'
        if (profileId != null &&
            profileId.isNotEmpty &&
            email != null &&
            email.isNotEmpty &&
            normalizedRole == 'driver') {
          // Usar email como valor mostrado, pero el id como clave
          // Si hay full_name, mostrarlo junto con el email
          final displayName = fullName != null && fullName.trim().isNotEmpty
              ? '$fullName ($email)'
              : email;
          driversMap[profileId] = displayName;
          print('✅ Conductor agregado al mapa: $displayName (id: $profileId)');
        } else {
          print(
            '⚠️ Perfil[$index] ignorado: id="$profileId", email="$email", role="$role" (normalized: "$normalizedRole")',
          );
          if (profileId == null || profileId.isEmpty) {
            print('   Razón: ID faltante o vacío');
          } else if (email == null || email.isEmpty) {
            print('   Razón: Email faltante o vacío');
          } else if (normalizedRole != 'driver') {
            print('   Razón: Role no es "driver" (es: "$normalizedRole")');
          }
        }
      }

      print('📋 Total de conductores en el mapa: ${driversMap.length}');
      return Right(driversMap);
    } on SocketException catch (_) {
      print('❌ Error de red al obtener conductores');
      return const Left(NetworkFailure());
    } catch (e) {
      print('❌ Error al obtener conductores: $e');
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ProfileFailure, ProfileEntity>> createDriver(
    String username,
    String password, {
    String? fullName,
    String? assignedVehicleId,
  }) async {
    try {
      print(
        '🔨 Creando nuevo conductor en PostgreSQL local: usuario=$username',
      );

      // Usar la API local de PostgreSQL en lugar de Supabase
      final result = await _localApi.createDriver(
        username: username,
        password: password,
        fullName: fullName,
        assignedVehicleId: assignedVehicleId,
      );

      final userData = result['user'] as Map<String, dynamic>;
      print('✅ Conductor creado en PostgreSQL: ${userData['email']}');

      // Convertir a ProfileEntity
      final String odId = userData['id'] ?? '';
      final profile = ProfileEntity(
        id: odId,
        userId: odId, // En PostgreSQL local, id == userId
        email: userData['email'] ?? username,
        fullName: userData['full_name'] ?? fullName ?? '',
        role: userData['role'] ?? 'driver',
        assignedVehicleId: userData['assigned_vehicle_id'],
        createdAt: userData['created_at'] != null
            ? DateTime.tryParse(userData['created_at'])
            : DateTime.now(),
      );

      return Right(profile);
    } on SocketException catch (_) {
      print('❌ Error de red al crear conductor');
      return const Left(NetworkFailure());
    } catch (e) {
      print('❌ Error al crear conductor en PostgreSQL: $e');
      final errorMsg = e.toString();

      if (errorMsg.contains('ya existe') ||
          errorMsg.contains('already exists')) {
        return Left(DatabaseFailure('Este usuario ya está registrado'));
      }

      return Left(DatabaseFailure('Error al crear conductor: $errorMsg'));
    }
  }

  @override
  Future<Either<ProfileFailure, Unit>> deleteDriver(String driverId) async {
    try {
      print('🗑️ Eliminando conductor con ID: $driverId');

      // Eliminar del backend PostgreSQL usando el método delete
      final success = await _localApi.delete('/rest/v1/profiles', driverId);

      if (success) {
        print('✅ Conductor eliminado exitosamente');
        return const Right(unit);
      } else {
        print('❌ Error al eliminar conductor');
        return const Left(DatabaseFailure('Error al eliminar conductor'));
      }
    } catch (e) {
      print('❌ Error al eliminar conductor: $e');
      return Left(
        DatabaseFailure('Error al eliminar conductor: ${e.toString()}'),
      );
    }
  }

  String _mapGenericError(dynamic e) {
    return e.toString().isNotEmpty ? e.toString() : 'Error desconocido';
  }
}
