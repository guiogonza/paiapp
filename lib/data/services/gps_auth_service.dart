import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de autenticación para la API de GPS
class GPSAuthService {
  static const String _loginUrl =
      'https://plataforma.sistemagps.online/api/login';
  static const String _apiKeyStorageKey = 'gps_api_key';

  /// Realiza login y guarda el API key
  /// Usa POST con body x-www-form-urlencoded (NO query string)
  Future<String?> login(String email, String password) async {
    try {
      final uri = Uri.parse(_loginUrl);

      print('🔐 Intentando login con: $email');
      print('📡 URL: $uri');
      print('📡 Método: POST');
      print('📡 Body: email=$email&password=***');

      // Preparar el body manualmente para asegurar el formato correcto
      final body =
          'email=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}';
      print(
        '📡 Body codificado: email=${Uri.encodeComponent(email)}&password=***',
      );

      final response = await http.post(
        uri,
        body: body,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          'User-Agent': 'Flutter-App/1.0',
        },
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📡 Response Headers: ${response.headers}');
      print('📡 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Respuesta del login: $data');

        // Verificar si el servidor respondió con error
        if (data is Map && data['status'] == 0) {
          print(
            '❌ El servidor rechazó las credenciales: ${data['message'] ?? 'Datos incorrectos'}',
          );
          return null;
        }

        // Extraer el API key de la respuesta
        // El endpoint devuelve: {"status":1,"user_api_hash":"..."}
        final apiKey =
            data['user_api_hash'] ??
            data['api_key'] ??
            data['apikey'] ??
            data['key'] ??
            data['token'] ??
            data['apiKey'] ??
            data['access_token'] ??
            (data is String
                ? data
                : null); // Si la respuesta es directamente el string

        if (apiKey != null) {
          // Guardar el API key
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_apiKeyStorageKey, apiKey.toString());
          print(
            '✅ API Key guardada exitosamente: ${apiKey.toString().substring(0, apiKey.toString().length > 20 ? 20 : apiKey.toString().length)}...',
          );
          return apiKey.toString();
        } else {
          print(
            '❌ No se encontró API key en la respuesta. Estructura recibida:',
          );
          print('   Keys disponibles: ${data.keys.toList()}');
          print('   Respuesta completa: ${response.body}');
          return null;
        }
      } else {
        print('❌ Error en login: ${response.statusCode}');
        print('   Respuesta: ${response.body}');

        // Intentar parsear el error si es JSON
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['message'] != null) {
            print('   Mensaje del servidor: ${errorData['message']}');
          }
        } catch (_) {
          // No es JSON, mostrar el body tal cual
        }

        return null;
      }
    } catch (e) {
      print('❌ Error de conexión en login: ${e.toString()}');
      return null;
    }
  }

  /// Obtiene el API key guardado
  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyStorageKey);
  }

  /// Elimina el API key guardado (logout)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyStorageKey);
  }

  /// Verifica si hay un API key guardado
  Future<bool> hasApiKey() async {
    final apiKey = await getApiKey();
    return apiKey != null && apiKey.isNotEmpty;
  }

  /// Función de debug para inspeccionar la estructura JSON del API de GPS
  /// Realiza el flujo completo: login -> obtener devices -> mostrar JSON completo
  Future<void> debugGpsStructure() async {
    try {
      print('🔍 ==========================================');
      print('🔍 INICIANDO DEBUG GPS STRUCTURE');
      print('🔍 ==========================================');

      // Paso 1: Login
      print('\n📡 PASO 1: Realizando login...');
      final email = 'luisr@rastrear.com.co';
      final password = '2023';

      final uri = Uri.parse(_loginUrl);
      print('📡 URL: $uri');
      print('📡 Método: POST');

      final loginResponse = await http.post(
        uri,
        body: {'email': email, 'password': password},
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      print('📡 Status Code: ${loginResponse.statusCode}');
      print('📡 Response Headers: ${loginResponse.headers}');
      print('📡 Response Body: ${loginResponse.body}');

      if (loginResponse.statusCode != 200) {
        print('❌ Error en login: ${loginResponse.statusCode}');
        print('   Respuesta: ${loginResponse.body}');
        return;
      }

      final loginData = json.decode(loginResponse.body);
      print('📦 Login JSON: $loginData');

      // Paso 2: Extraer token/API key
      final apiKey =
          loginData['user_api_hash'] ??
          loginData['api_key'] ??
          loginData['apikey'] ??
          loginData['key'] ??
          loginData['token'] ??
          loginData['apiKey'] ??
          loginData['access_token'] ??
          (loginData is String ? loginData : null);

      if (apiKey == null) {
        print('❌ No se encontró API key en la respuesta');
        print('   Keys disponibles: ${loginData.keys.toList()}');
        return;
      }

      print(
        '\n✅ API Key obtenido: ${apiKey.toString().substring(0, apiKey.toString().length > 30 ? 30 : apiKey.toString().length)}...',
      );

      // Paso 3: Obtener devices
      print('\n📡 PASO 3: Obteniendo devices...');
      const devicesUrl = 'https://plataforma.sistemagps.online/api/get_devices';
      final devicesUri = Uri.parse(devicesUrl).replace(
        queryParameters: {'user_api_hash': apiKey.toString(), 'lang': 'es'},
      );

      print('📡 URL: $devicesUri');

      final devicesResponse = await http.get(
        devicesUri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Flutter-App/1.0',
        },
      );

      print('📡 Status Code: ${devicesResponse.statusCode}');
      print('📡 Response Headers: ${devicesResponse.headers}');

      if (devicesResponse.statusCode != 200) {
        print('❌ Error al obtener devices: ${devicesResponse.statusCode}');
        print('   Respuesta: ${devicesResponse.body}');
        return;
      }

      // Paso 4: Parsear y mostrar JSON completo del primer dispositivo
      print('\n📦 PASO 4: Parseando respuesta...');
      final devicesData = json.decode(devicesResponse.body);

      print('\n🔍 ==========================================');
      print('🔍 RESPUESTA COMPLETA DE DEVICES');
      print('🔍 ==========================================');
      print('📦 Tipo de respuesta: ${devicesData.runtimeType}');
      print('📦 Respuesta completa (formateada):');
      print(const JsonEncoder.withIndent('  ').convert(devicesData));

      // Buscar el primer dispositivo
      print('\n🔍 ==========================================');
      print('🔍 PRIMER DISPOSITIVO ENCONTRADO');
      print('🔍 ==========================================');

      if (devicesData is List && devicesData.isNotEmpty) {
        // La respuesta es un array de grupos
        for (var group in devicesData) {
          if (group is Map && group['items'] != null) {
            final items = group['items'] as List;
            if (items.isNotEmpty) {
              final firstDevice = items[0];
              print('\n📦 ESTRUCTURA DEL PRIMER DISPOSITIVO:');
              print(const JsonEncoder.withIndent('  ').convert(firstDevice));

              print('\n🔍 CAMPOS CLAVE ENCONTRADOS:');
              if (firstDevice is Map) {
                print('   - ID: ${firstDevice['id']}');
                print('   - Name: ${firstDevice['name']}');
                print('   - Label: ${firstDevice['label']}');
                print('   - Alias: ${firstDevice['alias']}');
                print('   - Plate: ${firstDevice['plate']}');
                print('   - Title: ${firstDevice['title']}');
                print('   - Odometer: ${firstDevice['odometer']}');
                print('   - TotalDistance: ${firstDevice['totalDistance']}');
                print('   - Total_distance: ${firstDevice['total_distance']}');
                print('   - Lat: ${firstDevice['lat']}');
                print('   - Lng: ${firstDevice['lng']}');
                print('   - Timestamp: ${firstDevice['timestamp']}');
                print('   - Time: ${firstDevice['time']}');
                print('   - Speed: ${firstDevice['speed']}');
                print('   - Course: ${firstDevice['course']}');
                print('\n📋 TODOS LOS CAMPOS DISPONIBLES:');
                for (var key in firstDevice.keys) {
                  print(
                    '   - $key: ${firstDevice[key]} (${firstDevice[key].runtimeType})',
                  );
                }
              }
              break; // Solo mostrar el primer dispositivo
            }
          }
        }
      } else {
        print('⚠️ La respuesta no es un array o está vacía');
        print('   Tipo: ${devicesData.runtimeType}');
      }

      print('\n🔍 ==========================================');
      print('🔍 FIN DEL DEBUG GPS STRUCTURE');
      print('🔍 ==========================================');
    } catch (e, stackTrace) {
      print('❌ Error en debugGpsStructure: $e');
      print('   Stack trace: $stackTrace');
    }
  }

  /// Obtiene la lista de dispositivos GPS directamente del API
  /// Retorna una lista de maps con los datos de cada dispositivo
  Future<List<Map<String, dynamic>>> getDevicesFromGPS() async {
    try {
      print('📡 Obteniendo dispositivos del API GPS...');

      // Usar credenciales por defecto
      const email = 'luisr@rastrear.com.co';
      const password = '2023';

      // Autenticarse
      final apiKey = await login(email, password);
      if (apiKey == null || apiKey.isEmpty) {
        print('❌ No se pudo autenticar con el GPS');
        return [];
      }

      // Obtener dispositivos
      const devicesUrl = 'https://plataforma.sistemagps.online/api/get_devices';
      final devicesUri = Uri.parse(
        devicesUrl,
      ).replace(queryParameters: {'user_api_hash': apiKey, 'lang': 'es'});

      final response = await http
          .get(
            devicesUri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Flutter-App/1.0',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        print('❌ Error al obtener dispositivos: ${response.statusCode}');
        return [];
      }

      final devicesData = json.decode(response.body);
      final List<Map<String, dynamic>> allDevices = [];

      if (devicesData is List) {
        for (var group in devicesData) {
          if (group is Map && group['items'] != null) {
            final items = group['items'] as List;
            for (var item in items) {
              if (item is Map<String, dynamic>) {
                allDevices.add(item);
              }
            }
          }
        }
      }

      print('✅ Dispositivos obtenidos del GPS: ${allDevices.length}');
      return allDevices;
    } catch (e) {
      print('❌ Error en getDevicesFromGPS: $e');
      return [];
    }
  }
}
