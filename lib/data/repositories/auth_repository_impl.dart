import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/domain/entities/user_entity.dart';
import 'package:pai_app/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<UserEntity> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Error al iniciar sesión: Usuario no encontrado');
      }

      return UserEntity(
        id: response.user!.id,
        email: response.user!.email ?? email,
        name: response.user!.userMetadata?['name'] as String?,
      );
    } on AuthException catch (e) {
      throw Exception('Error de autenticación: ${e.message}');
    } catch (e) {
      throw Exception('Error al iniciar sesión: ${e.toString()}');
    }
  }

  @override
  Future<UserEntity> register(String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Error al registrar: No se pudo crear el usuario');
      }

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
        errorMessage = 'La contraseña no cumple los requisitos';
      } else {
        errorMessage = e.message.isNotEmpty ? e.message : 'Error al registrar';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Error al registrar: ${e.toString()}');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
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
