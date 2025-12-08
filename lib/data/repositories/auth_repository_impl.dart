import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/domain/entities/user_entity.dart';
import 'package:pai_app/domain/repositories/auth_repository.dart';
import 'package:pai_app/data/services/gps_auth_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GPSAuthService _gpsAuthService = GPSAuthService();

  @override
  Future<UserEntity> login(String email, String password) async {
    try {
      // PASO 1: Validar primero contra el API de GPS
      print('🔐 Validando credenciales contra API de GPS...');
      final apiKey = await _gpsAuthService.login(email, password);
      
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Credenciales inválidas. Verifica tu email y contraseña.');
      }
      
      print('✅ Credenciales válidas en API de GPS');
      
      // PASO 2: Si el API es correcto, verificar/crear usuario en Supabase
      UserEntity? userEntity;
      
      try {
        // Intentar hacer login en Supabase (si el usuario ya existe)
        final supabaseResponse = await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        
        if (supabaseResponse.user != null) {
          print('✅ Usuario encontrado en Supabase');
          userEntity = UserEntity(
            id: supabaseResponse.user!.id,
            email: supabaseResponse.user!.email ?? email,
            name: supabaseResponse.user!.userMetadata?['name'] as String?,
          );
        }
      } on AuthException catch (e) {
        // Si el usuario no existe en Supabase, crearlo
        if (e.message.contains('Invalid login credentials') || 
            e.message.contains('User not found')) {
          print('⚠️ Usuario no existe en Supabase, creándolo...');
          
          try {
            // Crear usuario en Supabase con la misma contraseña
            final signUpResponse = await _supabase.auth.signUp(
              email: email,
              password: password,
              emailRedirectTo: null, // No requerir confirmación de email por ahora
            );
            
            if (signUpResponse.user != null) {
              print('✅ Usuario creado en Supabase');
              userEntity = UserEntity(
                id: signUpResponse.user!.id,
                email: signUpResponse.user!.email ?? email,
                name: signUpResponse.user!.userMetadata?['name'] as String?,
              );
            } else {
              throw Exception('No se pudo crear el usuario en Supabase');
            }
          } catch (signUpError) {
            print('❌ Error al crear usuario en Supabase: $signUpError');
            // Si falla la creación, intentar hacer login de nuevo (por si se creó en otro momento)
            try {
              final retryResponse = await _supabase.auth.signInWithPassword(
                email: email,
                password: password,
              );
              if (retryResponse.user != null) {
                userEntity = UserEntity(
                  id: retryResponse.user!.id,
                  email: retryResponse.user!.email ?? email,
                  name: retryResponse.user!.userMetadata?['name'] as String?,
                );
              }
            } catch (_) {
              // Si aún falla, continuar con el usuario del API de GPS
              print('⚠️ No se pudo crear/autenticar en Supabase, continuando con API de GPS');
            }
          }
        } else {
          throw Exception('Error de autenticación en Supabase: ${e.message}');
        }
      }
      
      // Si no se pudo obtener/crear usuario en Supabase, crear un UserEntity temporal
      // usando el email como ID (esto es solo para mantener la compatibilidad)
      if (userEntity == null) {
        print('⚠️ Usando autenticación solo del API de GPS');
        userEntity = UserEntity(
          id: email, // Usar email como ID temporal
          email: email,
          name: null,
        );
      }
      
      return userEntity;
    } catch (e) {
      // Si el error es del API de GPS, lanzarlo directamente
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
}
