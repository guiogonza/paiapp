import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de autenticación para la API de GPS
class GPSAuthService {
  static const String _loginUrl = 'http://178.63.27.106/api/login';
  static const String _apiKeyStorageKey = 'gps_api_key';

  /// Realiza login y guarda el API key
  Future<String?> login(String email, String password) async {
    try {
      final response = await http.get(
        Uri.parse('$_loginUrl?email=$email&password=$password'),
      );

      print('🔐 Intentando login con: $email');
      print('📡 URL: $_loginUrl?email=$email&password=$password');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Respuesta del login: $data');
        
        // Extraer el API key de la respuesta
        // El endpoint devuelve: {"status":1,"user_api_hash":"..."}
        final apiKey = data['user_api_hash'] ??
                      data['api_key'] ?? 
                      data['apikey'] ?? 
                      data['key'] ?? 
                      data['token'] ?? 
                      data['apiKey'] ??
                      data['access_token'] ??
                      (data is String ? data : null); // Si la respuesta es directamente el string
        
        if (apiKey != null) {
          // Guardar el API key
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_apiKeyStorageKey, apiKey.toString());
          print('✅ API Key guardada exitosamente: ${apiKey.toString().substring(0, apiKey.toString().length > 20 ? 20 : apiKey.toString().length)}...');
          return apiKey.toString();
        } else {
          print('❌ No se encontró API key en la respuesta. Estructura recibida:');
          print('   Keys disponibles: ${data.keys.toList()}');
          print('   Respuesta completa: ${response.body}');
          return null;
        }
      } else {
        print('❌ Error en login: ${response.statusCode}');
        print('   Respuesta: ${response.body}');
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
}

