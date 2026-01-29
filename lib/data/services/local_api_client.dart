import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cliente API local para conectar con PostgreSQL
/// Reemplaza completamente a Supabase
class LocalApiClient {
  static final LocalApiClient _instance = LocalApiClient._internal();
  factory LocalApiClient() => _instance;
  LocalApiClient._internal();

  // URL base de la API - detectar entorno
  static final String _baseUrl = _detectApiUrl();

  static String _detectApiUrl() {
    if (!kIsWeb) {
      // Mobile/Desktop
      return 'http://82.208.21.130:3000';
    }

    final origin = Uri.base.origin;

    // Desarrollo local Flutter (localhost o 127.0.0.1 con cualquier puerto)
    if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
      return 'http://localhost:3000';
    }

    // Producción (VPS) - usar el mismo origen (nginx proxea /auth/ y /rest/)
    return origin;
  }

  String? _accessToken;
  Map<String, dynamic>? _currentUser;

  /// Inicializa el cliente cargando el token guardado
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('api_access_token');
    final userJson = prefs.getString('api_current_user');
    if (userJson != null) {
      _currentUser = jsonDecode(userJson);
    }
  }

  /// Headers con autenticación
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  /// Usuario actual
  Map<String, dynamic>? get currentUser => _currentUser;

  /// Está autenticado
  bool get isAuthenticated => _accessToken != null;

  // =====================================================
  // AUTENTICACIÓN
  // =====================================================

  /// Login con email/usuario y contraseña
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('🔐 LocalApiClient: Intentando login...');
      print('   URL: $_baseUrl/auth/login');
      print('   Email: $email');

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      print('📥 Respuesta del servidor:');
      print('   Status Code: ${response.statusCode}');
      print('   Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // El backend retorna 'token' en lugar de 'access_token'
        _accessToken = data['token'] ?? data['access_token'];
        _currentUser = data['user'];

        // Guardar en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('api_access_token', _accessToken!);
        await prefs.setString('api_current_user', jsonEncode(_currentUser));

        // Guardar el GPS API Key si viene en la respuesta
        if (data['gpsApiKey'] != null) {
          await prefs.setString('gps_api_key', data['gpsApiKey']);
          print(
            '✅ GPS API Key guardado: ${data['gpsApiKey'].toString().substring(0, 20)}...',
          );
        }

        print('✅ LocalApiClient: Login exitoso - ${_currentUser?['email']}');
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error de autenticación');
      }
    } catch (e) {
      print('❌ LocalApiClient: Error en login - $e');
      rethrow;
    }
  }

  /// Registro de nuevo usuario
  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    String? fullName,
    String role = 'driver',
    String? assignedVehicleId,
  }) async {
    try {
      print('📝 LocalApiClient: Registrando usuario...');

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName,
          'role': role,
          'assigned_vehicle_id': assignedVehicleId,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ LocalApiClient: Usuario creado - ${data['user']['email']}');
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al crear usuario');
      }
    } catch (e) {
      print('❌ LocalApiClient: Error en registro - $e');
      rethrow;
    }
  }

  /// Cerrar sesión
  Future<void> logout() async {
    _accessToken = null;
    _currentUser = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_access_token');
    await prefs.remove('api_current_user');

    print('👋 LocalApiClient: Sesión cerrada');
  }

  /// Verificar si hay una sesión válida guardada
  Future<bool> hasValidSession() async {
    await initialize();
    if (_accessToken == null) return false;

    // Verificar que el token sea válido haciendo una petición de prueba
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return true;
      }

      // Token inválido o expirado - limpiar sesión
      if (response.statusCode == 401 || response.statusCode == 403) {
        print('⚠️ Token inválido, limpiando sesión...');
        await logout();
      }
      return false;
    } catch (e) {
      print('⚠️ Error verificando sesión: $e');
      return false;
    }
  }

  /// Obtener el perfil del usuario actual
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    await initialize();
    if (_accessToken == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = data['user'] ?? data;
        return _currentUser;
      }
      return null;
    } catch (e) {
      print('❌ Error obteniendo perfil: $e');
      return null;
    }
  }

  // =====================================================
  // OPERACIONES CRUD GENÉRICAS
  // =====================================================

  /// GET request
  Future<List<dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    try {
      var uri = Uri.parse('$_baseUrl$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada');
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ LocalApiClient GET $endpoint: $e');
      rethrow;
    }
  }

  /// GET single item
  Future<Map<String, dynamic>?> getOne(String endpoint, String id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$endpoint/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        return null;
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada');
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ LocalApiClient GET $endpoint/$id: $e');
      rethrow;
    }
  }

  /// POST request
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ LocalApiClient POST $endpoint: $e');
      rethrow;
    }
  }

  /// PATCH request
  Future<Map<String, dynamic>> patch(
    String endpoint,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl$endpoint/$id'),
        headers: _headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ LocalApiClient PATCH $endpoint/$id: $e');
      rethrow;
    }
  }

  /// DELETE request
  Future<bool> delete(String endpoint, String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl$endpoint/$id'),
        headers: _headers,
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('❌ LocalApiClient DELETE $endpoint/$id: $e');
      rethrow;
    }
  }

  // =====================================================
  // MÉTODOS ESPECÍFICOS PARA CADA ENTIDAD
  // =====================================================

  /// Obtener conductores (profiles con role=driver)
  Future<List<Map<String, dynamic>>> getDrivers() async {
    final result = await get(
      '/rest/v1/profiles',
      queryParams: {'role': 'eq.driver'},
    );
    return result.cast<Map<String, dynamic>>();
  }

  /// Crear conductor
  Future<Map<String, dynamic>> createDriver({
    required String username,
    required String password,
    String? fullName,
    String? assignedVehicleId,
  }) async {
    return await signup(
      email: username,
      password: password,
      fullName: fullName,
      role: 'driver',
      assignedVehicleId: assignedVehicleId,
    );
  }

  /// Obtener vehículos
  Future<List<Map<String, dynamic>>> getVehicles() async {
    final result = await get('/rest/v1/vehicles');
    return result.cast<Map<String, dynamic>>();
  }

  /// Crear vehículo
  Future<Map<String, dynamic>> createVehicle(
    Map<String, dynamic> vehicleData,
  ) async {
    return await post('/rest/v1/vehicles', vehicleData);
  }

  /// Obtener historial de vehículo
  Future<List<Map<String, dynamic>>> getVehicleHistory(
    String vehicleId, {
    int limit = 100,
  }) async {
    final result = await get(
      '/rest/v1/vehicle_history',
      queryParams: {'vehicle_id': 'eq.$vehicleId', 'limit': limit.toString()},
    );
    return result.cast<Map<String, dynamic>>();
  }

  /// Guardar ubicación
  Future<Map<String, dynamic>> saveLocation({
    required String vehicleId,
    required double latitude,
    required double longitude,
    double? speed,
    double? altitude,
    double? heading,
    double? accuracy,
    String? address,
  }) async {
    return await post('/rest/v1/vehicle_history', {
      'vehicle_id': vehicleId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'altitude': altitude,
      'heading': heading,
      'accuracy': accuracy,
      'address': address,
    });
  }

  /// Obtener documentos de un vehículo
  Future<List<Map<String, dynamic>>> getDocuments(String vehicleId) async {
    final result = await get(
      '/rest/v1/documents',
      queryParams: {'vehicle_id': 'eq.$vehicleId'},
    );
    return result.cast<Map<String, dynamic>>();
  }

  /// Crear documento
  Future<Map<String, dynamic>> createDocument(
    Map<String, dynamic> documentData,
  ) async {
    return await post('/rest/v1/documents', documentData);
  }

  /// Obtener viajes
  Future<List<Map<String, dynamic>>> getTrips({
    String? vehicleId,
    String? driverId,
  }) async {
    final queryParams = <String, String>{};
    if (vehicleId != null) queryParams['vehicle_id'] = 'eq.$vehicleId';
    if (driverId != null) queryParams['driver_id'] = 'eq.$driverId';

    final result = await get('/rest/v1/trips', queryParams: queryParams);
    return result.cast<Map<String, dynamic>>();
  }

  /// Iniciar viaje
  Future<Map<String, dynamic>> startTrip({
    required String vehicleId,
    double? startLatitude,
    double? startLongitude,
    String? startAddress,
  }) async {
    return await post('/rest/v1/trips', {
      'vehicle_id': vehicleId,
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'start_address': startAddress,
    });
  }

  /// Obtener gastos
  Future<List<Map<String, dynamic>>> getExpenses() async {
    final result = await get('/rest/v1/expenses');
    return result.cast<Map<String, dynamic>>();
  }

  /// Crear gasto
  Future<Map<String, dynamic>> createExpense(
    Map<String, dynamic> expenseData,
  ) async {
    return await post('/rest/v1/expenses', expenseData);
  }

  /// Obtener mantenimientos
  Future<List<Map<String, dynamic>>> getMaintenance({String? vehicleId}) async {
    final queryParams = <String, String>{};
    if (vehicleId != null) queryParams['vehicle_id'] = 'eq.$vehicleId';

    final result = await get('/rest/v1/maintenance', queryParams: queryParams);
    return result.cast<Map<String, dynamic>>();
  }

  /// Crear mantenimiento
  Future<Map<String, dynamic>> createMaintenance(
    Map<String, dynamic> maintenanceData,
  ) async {
    return await post('/rest/v1/maintenance', maintenanceData);
  }

  /// Actualizar mantenimiento
  Future<Map<String, dynamic>> updateMaintenance(
    String id,
    Map<String, dynamic> maintenanceData,
  ) async {
    return await patch('/rest/v1/maintenance', id, maintenanceData);
  }

  /// Limpiar alertas de mantenimiento
  Future<void> clearMaintenanceAlerts({
    required String vehicleId,
    required String serviceType,
    String? excludeId,
    String? tirePosition,
  }) async {
    await post('/rest/v1/maintenance/clear-alerts', {
      'vehicle_id': vehicleId,
      'service_type': serviceType,
      if (excludeId != null) 'exclude_id': excludeId,
      if (tirePosition != null) 'tire_position': tirePosition,
    });
  }

  /// Actualizar gasto
  Future<Map<String, dynamic>> updateExpense(
    String id,
    Map<String, dynamic> expenseData,
  ) async {
    return await patch('/rest/v1/expenses', id, expenseData);
  }

  /// Eliminar gasto
  Future<bool> deleteExpense(String id) async {
    return await delete('/rest/v1/expenses', id);
  }

  /// Obtener viaje por ID
  Future<Map<String, dynamic>?> getTripById(String id) async {
    return await getOne('/rest/v1/trips', id);
  }

  /// Crear viaje
  Future<Map<String, dynamic>> createTrip(Map<String, dynamic> tripData) async {
    return await post('/rest/v1/trips', tripData);
  }

  /// Actualizar viaje
  Future<Map<String, dynamic>> updateTrip(
    String id,
    Map<String, dynamic> tripData,
  ) async {
    return await patch('/rest/v1/trips', id, tripData);
  }

  /// Eliminar viaje
  Future<bool> deleteTrip(String id) async {
    return await delete('/rest/v1/trips', id);
  }

  /// Obtener vehículo por ID
  Future<Map<String, dynamic>?> getVehicleById(String id) async {
    return await getOne('/rest/v1/vehicles', id);
  }

  /// Actualizar vehículo
  Future<Map<String, dynamic>> updateVehicle(
    String id,
    Map<String, dynamic> vehicleData,
  ) async {
    return await patch('/rest/v1/vehicles', id, vehicleData);
  }

  /// Eliminar vehículo
  Future<bool> deleteVehicle(String id) async {
    return await delete('/rest/v1/vehicles', id);
  }

  /// Actualizar documento
  Future<Map<String, dynamic>> updateDocument(
    String id,
    Map<String, dynamic> documentData,
  ) async {
    return await patch('/rest/v1/documents', id, documentData);
  }

  /// Eliminar documento
  Future<bool> deleteDocument(String id) async {
    return await delete('/rest/v1/documents', id);
  }

  /// Obtener remisiones
  Future<List<Map<String, dynamic>>> getRemisiones({
    String? tripId,
    String? vehicleId,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (tripId != null) queryParams['trip_id'] = 'eq.$tripId';
    if (vehicleId != null) queryParams['vehicle_id'] = 'eq.$vehicleId';
    if (status != null) queryParams['status'] = 'eq.$status';

    final result = await get('/rest/v1/remisiones', queryParams: queryParams);
    return result.cast<Map<String, dynamic>>();
  }

  /// Crear remisión
  Future<Map<String, dynamic>> createRemision(
    Map<String, dynamic> remisionData,
  ) async {
    return await post('/rest/v1/remisiones', remisionData);
  }

  /// Actualizar remisión
  Future<Map<String, dynamic>> updateRemision(
    String id,
    Map<String, dynamic> remisionData,
  ) async {
    return await patch('/rest/v1/remisiones', id, remisionData);
  }

  /// Obtener credenciales GPS
  Future<List<Map<String, dynamic>>> getGpsCredentials() async {
    final result = await get('/rest/v1/gps_credentials');
    return result.cast<Map<String, dynamic>>();
  }

  /// Guardar credenciales GPS
  Future<Map<String, dynamic>> saveGpsCredentials({
    required String email,
    required String password,
    String provider = 'sistemagps',
  }) async {
    return await post('/rest/v1/gps_credentials', {
      'email': email,
      'password': password,
      'provider': provider,
    });
  }

  /// Health check
  Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
