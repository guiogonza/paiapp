import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/domain/entities/user_entity.dart';
import 'package:pai_app/domain/repositories/auth_repository.dart';
import 'package:pai_app/data/services/gps_auth_service.dart';
import 'package:pai_app/data/repositories/profile_repository_impl.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GPSAuthService _gpsAuthService = GPSAuthService();

  @override
  Future<UserEntity> login(String email, String password) async {
    try {
      // PASO 1: Intentar primero hacer login en Supabase (prioridad)
      // Esto permite que usuarios creados directamente en Supabase puedan entrar
      UserEntity? userEntity;
      
      try {
        print('🔐 Intentando login en Supabase...');
        print('   Email: $email');
        
        final supabaseResponse = await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Timeout: No se pudo conectar con Supabase. Verifica tu conexión a internet.');
          },
        );
        
        if (supabaseResponse.user != null) {
          print('✅ Usuario autenticado en Supabase');
          userEntity = UserEntity(
            id: supabaseResponse.user!.id,
            email: supabaseResponse.user!.email ?? email,
            name: supabaseResponse.user!.userMetadata?['name'] as String?,
          );
          
          // Validar GPS SOLO si el usuario es 'owner' (asíncrono, no bloquea el login)
          // Esto se ejecuta en segundo plano después de retornar el userEntity
          _validateGpsApiIfOwnerAsync(email, password);
          
          return userEntity;
        }
      } on AuthException catch (e) {
        // Si el usuario no existe en Supabase, intentar con API de GPS
        if (e.message.contains('Invalid login credentials') || 
            e.message.contains('User not found')) {
          print('⚠️ Usuario no encontrado en Supabase, intentando con API de GPS...');
          
          // PASO 2: Validar contra el API de GPS
          try {
            final apiKey = await _gpsAuthService.login(email, password);
            
            if (apiKey == null || apiKey.isEmpty) {
              throw Exception('Credenciales inválidas. Verifica tu email y contraseña.');
            }
            
            print('✅ Credenciales válidas en API de GPS');
            
            // Si el API es correcto, crear usuario en Supabase
            try {
              final signUpResponse = await _supabase.auth.signUp(
                email: email,
                password: password,
                emailRedirectTo: null,
              );
              
              if (signUpResponse.user != null) {
                print('✅ Usuario creado en Supabase');
                return UserEntity(
                  id: signUpResponse.user!.id,
                  email: signUpResponse.user!.email ?? email,
                  name: signUpResponse.user!.userMetadata?['name'] as String?,
                );
              } else {
                throw Exception('No se pudo crear el usuario en Supabase');
              }
            } catch (signUpError) {
              print('❌ Error al crear usuario en Supabase: $signUpError');
              // Si falla la creación, intentar hacer login de nuevo
              try {
                final retryResponse = await _supabase.auth.signInWithPassword(
                  email: email,
                  password: password,
                );
                if (retryResponse.user != null) {
                  return UserEntity(
                    id: retryResponse.user!.id,
                    email: retryResponse.user!.email ?? email,
                    name: retryResponse.user!.userMetadata?['name'] as String?,
                  );
                }
              } catch (_) {
                // Si aún falla, usar email como ID temporal
                print('⚠️ Usando autenticación solo del API de GPS');
                return UserEntity(
                  id: email,
                  email: email,
                  name: null,
                );
              }
            }
          } catch (gpsError) {
            // Si el API de GPS también falla, lanzar error
            throw Exception('Credenciales inválidas. Verifica tu email y contraseña.');
          }
        } else {
          throw Exception('Error de autenticación en Supabase: ${e.message}');
        }
      }
      
      // Si llegamos aquí sin usuario, lanzar error
      throw Exception('No se pudo autenticar el usuario');
    } catch (e) {
      // Si el error es de credenciales inválidas, lanzarlo directamente
      if (e.toString().contains('Credenciales inválidas')) {
        rethrow;
      }
      throw Exception('Error al iniciar sesión: ${e.toString()}');
    }
  }

  @override
  Future<UserEntity> register(String email, String password) async {
    try {
      // PASO 1: Validar primero contra el API de GPS
      print('🔐 Validando credenciales contra API de GPS para registro...');
      final apiKey = await _gpsAuthService.login(email, password);
      
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Credenciales inválidas en el API de GPS. Verifica tu email y contraseña.');
      }
      
      print('✅ Credenciales válidas en API de GPS');
      
      // PASO 2: Si el API es correcto, crear usuario en Supabase
      try {
        final response = await _supabase.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: null, // No requerir confirmación de email por ahora
        );

        if (response.user == null) {
          throw Exception('Error al registrar: No se pudo crear el usuario en Supabase');
        }

        print('✅ Usuario creado en Supabase');
        return UserEntity(
          id: response.user!.id,
          email: response.user!.email ?? email,
          name: response.user!.userMetadata?['name'] as String?,
        );
      } on AuthException catch (e) {
        // Mensajes más específicos según el tipo de error
        String errorMessage = 'Error de autenticación';
        if (e.message.contains('already registered') || 
            e.message.contains('already exists')) {
          errorMessage = 'Este email ya está registrado. Intenta iniciar sesión.';
        } else if (e.message.contains('invalid')) {
          errorMessage = 'Email o contraseña inválidos';
        } else if (e.message.contains('password')) {
          errorMessage = 'La contraseña no cumple los requisitos de Supabase. Contacta al administrador.';
        } else {
          errorMessage = e.message.isNotEmpty ? e.message : 'Error al registrar';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      // Si el error es del API de GPS, lanzarlo directamente
      if (e.toString().contains('Credenciales inválidas')) {
        rethrow;
      }
      throw Exception('Error al registrar: ${e.toString()}');
    }
  }

  @override
  Future<void> logout() async {
    try {
      // Cerrar sesión en Supabase
      await _supabase.auth.signOut();
      // También limpiar el API key del GPS
      await _gpsAuthService.logout();
      print('✅ Sesión cerrada en Supabase y API de GPS');
    } catch (e) {
      throw Exception('Error al cerrar sesión: ${e.toString()}');
    }
  }

  @override
  UserEntity? getCurrentUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    return UserEntity(
      id: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['name'] as String?,
    );
  }

  @override
  bool isAuthenticated() {
    return _supabase.auth.currentSession != null;
  }

  /// Valida el API de GPS de forma asíncrona sin bloquear el login
  /// Solo se ejecuta si el usuario es 'owner'
  void _validateGpsApiIfOwnerAsync(String email, String password) {
    // Ejecutar en segundo plano sin bloquear el login
    Future.microtask(() async {
      try {
        final profileRepository = ProfileRepositoryImpl();
        final profileResult = await profileRepository.getCurrentUserProfile();
        
        profileResult.fold(
          (_) {
            // Si no se puede obtener el perfil, no validar GPS
            print('⚠️ No se pudo obtener perfil, omitiendo validación GPS');
          },
          (profile) {
            // Solo validar GPS si el rol es 'owner'
            if (profile.role == 'owner') {
              _validateGpsApiAsync(email, password);
            } else {
              print('ℹ️ Usuario con rol ${profile.role}, omitiendo validación GPS');
            }
          },
        );
      } catch (e) {
        print('⚠️ Error al obtener perfil para validación GPS (no crítico): $e');
        // No bloquear el login por esto
      }
    });
  }

  /// Valida el API de GPS de forma asíncrona (llamado solo para owners)
  void _validateGpsApiAsync(String email, String password) async {
    try {
      print('🔐 Validando también contra API de GPS (solo para owners)...');
      final apiKey = await _gpsAuthService.login(email, password);
      if (apiKey != null && apiKey.isNotEmpty) {
        print('✅ Credenciales también válidas en API de GPS');
      } else {
        print('⚠️ Credenciales no válidas en API de GPS, pero usuario puede entrar (solo Supabase)');
      }
    } catch (e) {
      print('⚠️ Error al validar con API de GPS (no crítico, no bloquea login): $e');
      // No lanzar error, el usuario puede entrar solo con Supabase
    }
  }
}
