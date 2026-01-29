import 'package:pai_app/data/providers/gps_vehicle_provider.dart';
import 'package:pai_app/data/services/gps_auth_service.dart';
import 'package:pai_app/data/services/local_api_client.dart';
import 'package:pai_app/domain/entities/user_entity.dart';
import 'package:pai_app/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final LocalApiClient _apiClient = LocalApiClient();

  @override
  Future<UserEntity> login(String username, String password) async {
    try {
      print('🔐 Intentando login con API local (PostgreSQL)...');
      print('   Usuario: $username');

      // Login directo con LocalApiClient (backend PostgreSQL + GPS validation)
      final response = await _apiClient.login(username, password);

      print('✅ Login exitoso en API local');

      return UserEntity(
        id: response['user']['userId'],
        email: response['user']['email'],
        name: response['user']['fullName'],
      );
    } catch (e) {
      print('❌ Error en login: $e');
      throw Exception('Error al iniciar sesión: ${e.toString()}');
    }
  }

  @override
  Future<UserEntity> register(String username, String password) async {
    try {
      print('📝 Intentando registro con API local (PostgreSQL)...');

      // El registro no está implementado en el API backend
      // Los usuarios se crean automáticamente al hacer login con credenciales GPS válidas
      throw Exception(
        'El registro no está disponible. Los usuarios se crean automáticamente al hacer login con credenciales válidas del GPS.',
      );
    } catch (e) {
      print('❌ Error en registro: $e');
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      print('👋 Cerrando sesión...');

      // 1. Limpiar cache de vehículos GPS
      final gpsProvider = GPSVehicleProvider();
      gpsProvider.clearCache();
      print('✅ Cache de vehículos GPS limpiado');

      // 2. Limpiar API key y credenciales GPS
      final gpsAuthService = GPSAuthService();
      await gpsAuthService.logout();
      print('✅ Credenciales GPS limpiadas');

      // 3. Limpiar token de API local
      await _apiClient.logout();
      print('✅ Sesión local cerrada');

      print('✅ Logout completo - usuario puede cambiar');
    } catch (e) {
      print('❌ Error al cerrar sesión: $e');
      throw Exception('Error al cerrar sesión: ${e.toString()}');
    }
  }

  @override
  UserEntity? getCurrentUser() {
    // El usuario actual se obtiene del token almacenado
    // Esta función es síncrona pero necesitamos verificar asíncronamente
    // Por ahora retornamos null - la info real se obtiene con ProfileRepository
    return null;
  }

  @override
  bool isAuthenticated() {
    // Verificación síncrona simple - solo verifica si hay token en memoria
    // Para verificación completa del token, usar hasValidSession() desde el caller
    // Nota: _accessToken es privado en LocalApiClient, necesitamos agregar un getter público

    // Por ahora, siempre retornamos false aquí y la app verificará con hasValidSession()
    // cuando sea necesario (esa función sí valida el token contra el servidor)
    return false;
  }
}
