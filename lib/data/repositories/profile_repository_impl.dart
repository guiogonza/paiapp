import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/domain/entities/profile_entity.dart';
import 'package:pai_app/domain/failures/profile_failure.dart';
import 'package:pai_app/domain/repositories/profile_repository.dart';
import 'package:pai_app/data/models/profile_model.dart';
import 'package:pai_app/data/services/local_api_client.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalApiClient _localApi = LocalApiClient();
  static const String _tableName = 'profiles';

  @override
  Future<Either<ProfileFailure, ProfileEntity>> getCurrentUserProfile() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return const Left(NotFoundFailure('No hay usuario autenticado'));
      }

      return await getProfileByUserId(currentUser.id);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
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
      final updateData = <String, dynamic>{'assigned_vehicle_id': vehicleId};

      await _supabase.from(_tableName).update(updateData).eq('id', driverId);

      return const Right(unit);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ProfileFailure, List<ProfileEntity>>>
  getDriversWithAssignedVehicle() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*')
          .eq('role', 'driver')
          .order('email', ascending: true);

      final profilesList = (response as List)
          .map((json) => ProfileModel.fromJson(json as Map<String, dynamic>))
          .map((model) => model.toEntity())
          .toList();

      return Right(profilesList);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ProfileFailure, ProfileEntity>> getProfileByUserId(
    String userId,
  ) async {
    try {
      // En profiles, el id es la clave primaria que coincide con auth.uid()
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('id', userId)
          .single();

      final profile = ProfileModel.fromJson(response);
      return Right(profile.toEntity());
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        // No rows returned
        return const Left(NotFoundFailure('Perfil no encontrado'));
      }
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  String _mapPostgrestError(PostgrestException e) {
    if (e.message.contains('JWT')) {
      return 'Error de autenticación. Por favor, inicia sesión nuevamente.';
    }
    if (e.message.contains('permission denied') ||
        e.message.contains('row-level security')) {
      return 'No tienes permisos para acceder a este perfil.';
    }
    return e.message.isNotEmpty ? e.message : 'Error en la base de datos';
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

      // Buscar específicamente pepe@pai.com para diagnóstico
      bool foundPepe = false;

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
          foundPepe = true;
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

  /// Convierte cualquier texto de usuario a un formato válido para Supabase Auth
  /// Si ya tiene formato de email, lo devuelve tal cual
  /// Si no, lo convierte a usuario@conductor.app (dominio válido)
  String _normalizeUsernameForSupabase(String username) {
    final trimmed = username.trim();
    // Si ya tiene formato de email (contiene @), usarlo tal cual
    if (trimmed.contains('@')) {
      return trimmed;
    }
    // Si no tiene formato de email, convertirlo a usuario@conductor.app
    return '$trimmed@conductor.app';
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

  String _mapGenericError(dynamic e) {
    return e.toString().isNotEmpty ? e.toString() : 'Error desconocido';
  }
}
