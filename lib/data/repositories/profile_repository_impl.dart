import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/domain/entities/profile_entity.dart';
import 'package:pai_app/domain/failures/profile_failure.dart';
import 'package:pai_app/domain/repositories/profile_repository.dart';
import 'package:pai_app/data/models/profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
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
      final updateData = <String, dynamic>{
        'assigned_vehicle_id': vehicleId,
      };

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
      String userId) async {
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
      // Log para debugging
      print('🔍 Buscando conductores en la tabla profiles...');
      print('   Tabla: $_tableName');
      print('   Filtro: role = "driver"');
      
      // Select simple: profiles ahora tiene las columnas email y full_name
      final response = await _supabase
          .from(_tableName)
          .select('*')
          .eq('role', 'driver')
          .order('email', ascending: true);

      print('📊 Respuesta de Supabase: ${response.length} registros encontrados');
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
          print('⚠️ Perfil en índice $index no es un Map: ${profileRaw.runtimeType}');
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
          print('🔍 ENCONTRADO PEPE: id="$profileId", email="$email", role="$role"');
          print('   Tipo de role: ${role.runtimeType}');
          print('   Role normalizado: "${role?.trim().toLowerCase()}"');
          print('   Comparación con "driver": ${role?.trim().toLowerCase() == 'driver'}');
        }
        
        print('👤 Perfil[$index]: id="$profileId", email="$email", full_name="$fullName", role="$role"');
        
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
          print('⚠️ Perfil[$index] ignorado: id="$profileId", email="$email", role="$role" (normalized: "$normalizedRole")');
          if (profileId == null || profileId.isEmpty) {
            print('   Razón: ID faltante o vacío');
          } else if (email == null || email.isEmpty) {
            print('   Razón: Email faltante o vacío');
          } else if (normalizedRole != 'driver') {
            print('   Razón: Role no es "driver" (es: "$normalizedRole")');
          }
        }
      }
      
      if (!foundPepe) {
        print('⚠️ PEPE NO ENCONTRADO en la respuesta de Supabase');
        print('   Esto puede indicar:');
        print('   1. El usuario no existe en profiles');
        print('   2. El role no es "driver"');
        print('   3. Problema de RLS que impide leer el perfil');
      }

      print('📋 Total de conductores en el mapa: ${driversMap.length}');
      return Right(driversMap);
    } on PostgrestException catch (e) {
      print('❌ Error PostgrestException al obtener conductores: ${e.message}');
      print('   Código: ${e.code}');
      print('   Detalles: ${e.details}');
      print('   Hint: ${e.hint}');
      
      // Si hay error de columna faltante, proporcionar mensaje claro
      if (e.message.contains('column') && e.message.contains('does not exist')) {
        print('⚠️ ERROR: Columna no existe en la tabla profiles');
        print('   Solución: Verificar que las columnas email y full_name existen en la tabla profiles');
        return Left(DatabaseFailure(
          'Error de esquema: La tabla profiles no contiene todas las columnas esperadas (email, full_name). '
          'Verifica la estructura de la tabla en Supabase.'
        ));
      }
      
      // Si es un error de RLS, proporcionar mensaje más claro
      if (e.message.contains('row-level security') || 
          e.message.contains('policy') ||
          e.code == 'PGRST301' ||
          e.message.contains('permission denied')) {
        print('⚠️ ERROR DE RLS: El usuario no tiene permisos para ejecutar la función');
        print('   Solución: Verificar que la función tenga GRANT EXECUTE para authenticated');
        return Left(DatabaseFailure(
          'Error de permisos: No tienes acceso para leer perfiles de conductores. '
          'Contacta al administrador o verifica las políticas RLS en Supabase.'
        ));
      }
      
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      print('❌ Error de red al obtener conductores');
      return const Left(NetworkFailure());
    } catch (e) {
      print('❌ Error desconocido al obtener conductores: $e');
      print('   Stack trace: ${StackTrace.current}');
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ProfileFailure, ProfileEntity>> createDriver(
    String email,
    String password, {
    String? fullName,
    String? assignedVehicleId,
  }) async {
    try {
      print('🔨 Creando nuevo conductor: email=$email');
      
      // Paso 1: Crear usuario en auth.users usando signUp
      final signUpResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
          'role': 'driver',
        },
      );

      if (signUpResponse.user == null) {
        print('❌ Error: No se pudo crear el usuario en auth');
        return Left(DatabaseFailure('No se pudo crear el usuario'));
      }

      final userId = signUpResponse.user!.id;
      print('✅ Usuario creado en auth: id=$userId');

      // Paso 2: Crear perfil en profiles con role='driver'
      // profiles ahora tiene las columnas email y full_name (agregadas manualmente)
      // Nota: Si hay un trigger que crea el perfil automáticamente, esto podría fallar
      // En ese caso, intentar obtener el perfil creado por el trigger y actualizar el role
      try {
        final profileData = {
          'id': userId,
          'role': 'driver',
          'email': email, // CRÍTICO: Guardar email en profiles para facilitar consultas
          'full_name': fullName ?? '', // CRÍTICO: Guardar full_name (vacío si no se proporciona)
          if (assignedVehicleId != null) 'assigned_vehicle_id': assignedVehicleId,
          'created_at': DateTime.now().toIso8601String(),
        };

        print('📝 Intentando insertar perfil: $profileData');

        final profileResponse = await _supabase
            .from(_tableName)
            .insert(profileData)
            .select()
            .single();

        print('✅ Perfil creado en profiles: ${profileResponse['id']}');
        print('   Role en perfil creado: ${profileResponse['role']}');

        final profile = ProfileModel.fromJson(profileResponse);
        
        // Verificar que el role sea 'driver'
        if (profile.role != 'driver') {
          print('⚠️ El role no es "driver", actualizando...');
          await _supabase
              .from(_tableName)
              .update({'role': 'driver'})
              .eq('id', userId);
          // Obtener el perfil actualizado
          final updatedProfile = await getProfileByUserId(userId);
          return updatedProfile.fold(
            (failure) => Right(profile.toEntity()), // Retornar el original si falla
            (updated) => Right(updated),
          );
        }
        
        return Right(profile.toEntity());
      } on PostgrestException catch (e) {
        // Si el perfil ya existe (creado por trigger), intentar obtenerlo y actualizar el role, email y full_name
        if (e.code == '23505' || e.message.contains('duplicate') || e.message.contains('already exists')) {
          print('⚠️ Perfil ya existe, obteniendo y actualizando datos...');
          try {
            // Actualizar role, email y full_name
            final updateData = {
              'role': 'driver',
              'email': email,
              'full_name': fullName ?? '',
            };
            await _supabase
                .from(_tableName)
                .update(updateData)
                .eq('id', userId);
            
            print('✅ Datos actualizados: role=driver, email=$email, full_name=${fullName ?? ""}');
            
            // Luego obtener el perfil actualizado
            final existingProfile = await getProfileByUserId(userId);
            return existingProfile.fold(
              (failure) => Left(DatabaseFailure('Perfil existe pero no se pudo obtener: ${failure.message}')),
              (profile) {
                print('✅ Perfil obtenido con role: ${profile.role}');
                // Verificar nuevamente que el role sea 'driver'
                if (profile.role != 'driver') {
                  print('⚠️ El role aún no es "driver" después de actualizar, intentando nuevamente...');
                  // Intentar actualizar nuevamente de forma asíncrona (no bloqueante)
                  _supabase
                      .from(_tableName)
                      .update({'role': 'driver'})
                      .eq('id', userId)
                      .then((_) => print('✅ Role actualizado a "driver"'))
                      .catchError((e) => print('⚠️ Error al actualizar role: $e'));
                }
                return Right(profile);
              },
            );
          } catch (getError) {
            print('❌ Error al obtener/actualizar perfil existente: $getError');
            return Left(DatabaseFailure('Error al obtener perfil existente: $getError'));
          }
        }
        print('❌ Error al insertar perfil: ${e.message}');
        rethrow;
      }
    } on AuthException catch (e) {
      print('❌ Error AuthException al crear conductor: ${e.message}');
      if (e.message.contains('already registered') || 
          e.message.contains('already exists') ||
          e.message.contains('User already registered')) {
        return Left(DatabaseFailure('El email ya está registrado'));
      }
      // Manejo de rate limiting - mensaje amigable
      if (e.message.contains('security purposes') || 
          e.message.contains('rate limit') ||
          e.message.contains('too many requests')) {
        final match = RegExp(r'after (\d+) seconds?').firstMatch(e.message);
        final seconds = match != null ? match.group(1) : 'unos';
        return Left(DatabaseFailure(
          'Por seguridad, espera $seconds segundos antes de crear otro conductor.'
        ));
      }
      return Left(DatabaseFailure('Error al crear usuario: ${e.message}'));
    } on PostgrestException catch (e) {
      print('❌ Error PostgrestException al crear perfil: ${e.message}');
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      print('❌ Error de red al crear conductor');
      return const Left(NetworkFailure());
    } catch (e) {
      print('❌ Error desconocido al crear conductor: $e');
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  String _mapGenericError(dynamic e) {
    return e.toString().isNotEmpty ? e.toString() : 'Error desconocido';
  }
}

