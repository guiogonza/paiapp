import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pai_app/data/services/gps_auth_service.dart';
import 'package:pai_app/domain/entities/vehicle_location_entity.dart';

/// Servicio que consume la API real de GPS
class VehicleLocationService {
  static const String _devicesUrl = 'https://plataforma.sistemagps.online/api/get_devices';
  final GPSAuthService _authService = GPSAuthService();

  /// Obtiene las ubicaciones de todos los vehículos desde la API real
  Future<List<VehicleLocationEntity>> getVehicleLocations() async {
    try {
      // Obtener el API key
      final apiKey = await _authService.getApiKey();
      
      if (apiKey == null || apiKey.isEmpty) {
        // Si no hay API key, intentar hacer login automático
        print('⚠️ No hay API key, intentando login automático...');
        final newApiKey = await _authService.login(
          'luisr@rastrear.com.co',
          '2023',
        );
        
        if (newApiKey == null) {
          throw Exception('No se pudo obtener el API key');
        }
      }

      // Obtener el API key actualizado (por si se hizo login)
      final currentApiKey = await _authService.getApiKey();
      
      if (currentApiKey == null || currentApiKey.isEmpty) {
        throw Exception('No se pudo obtener el API key');
      }
      
      // Hacer la petición a la API
      // El endpoint requiere: user_api_hash (no api_key) y lang=es
      final uri = Uri.parse(_devicesUrl).replace(queryParameters: {
        'user_api_hash': currentApiKey,
        'lang': 'es',
      });
      
      print('📡 Consultando devices en: ${uri.toString()}');
      print('📡 API Key (primeros 30 chars): ${currentApiKey.substring(0, currentApiKey.length > 30 ? 30 : currentApiKey.length)}...');
      
      // Hacer la petición con headers
      // Nota: En web puede haber problemas de CORS, pero intentamos de todas formas
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Flutter-App/1.0',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout al consultar devices');
        },
      );
      
      print('📡 Status Code: ${response.statusCode}');
      
      
      print('📡 Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        return _parseDevicesResponse(response);
      } else {
        print('❌ Error al obtener devices: ${response.statusCode}');
        print('   Respuesta: ${response.body}');
        print('   Headers: ${response.headers}');
        throw Exception('Error al obtener ubicaciones: ${response.statusCode} - ${response.body}');
      }
    } on http.ClientException catch (e) {
      print('❌ Error de cliente HTTP: ${e.toString()}');
      print('   Esto puede ser un problema de CORS o conectividad');
      throw Exception('Error de conexión: ${e.toString()}. Verifica que el servidor permita peticiones desde tu origen.');
    } catch (e) {
      print('❌ Error de conexión: ${e.toString()}');
      throw Exception('Error de conexión: ${e.toString()}');
    }
  }

  /// Parsea la respuesta de devices a una lista de VehicleLocationEntity
  /// La respuesta es un array de objetos con estructura: [{"id":0,"title":"Sin grupo","items":[...]}]
  List<VehicleLocationEntity> _parseDevicesResponse(http.Response response) {
    final responseData = json.decode(response.body);
    print('📦 Respuesta completa de devices: ${responseData.runtimeType}');
    
    // La respuesta es un array de grupos
    final List<dynamic> groups = responseData is List ? responseData : [];
    
    final vehicles = <VehicleLocationEntity>[];
    
    // Iterar sobre cada grupo
    for (var group in groups) {
      // Cada grupo tiene un array de items
      final List<dynamic> items = group['items'] ?? [];
      
      print('📦 Grupo "${group['title'] ?? 'Sin título'}": ${items.length} devices');
      
      // Mapear cada item a VehicleLocationEntity
      for (var item in items) {
        final name = item['name'] ?? '';
        final id = item['id']?.toString() ?? '';
        print('🚗 Device encontrado - ID: $id, Name: $name');
        
        // Extraer coordenadas
        final lat = (item['lat'] ?? item['lastValidLatitude'] ?? 0.0).toDouble();
        final lng = (item['lng'] ?? item['lastValidLongitude'] ?? 0.0).toDouble();
        
        // Convertir timestamp Unix a DateTime
        DateTime? timestamp;
        if (item['timestamp'] != null) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(
            (item['timestamp'] as int) * 1000,
          );
        } else if (item['time'] != null) {
          // Intentar parsear el formato "05-12-2025 11:57:52"
          try {
            final timeStr = item['time'] as String;
            final parts = timeStr.split(' ');
            if (parts.length == 2) {
              final dateParts = parts[0].split('-');
              final timeParts = parts[1].split(':');
              if (dateParts.length == 3 && timeParts.length == 3) {
                timestamp = DateTime(
                  int.parse(dateParts[2]), // año
                  int.parse(dateParts[1]), // mes
                  int.parse(dateParts[0]), // día
                  int.parse(timeParts[0]), // hora
                  int.parse(timeParts[1]), // minuto
                  int.parse(timeParts[2]), // segundo
                );
              }
            }
          } catch (e) {
            print('⚠️ Error al parsear fecha: ${item['time']} - $e');
          }
        }
        
        // Extraer velocidad y dirección
        final speed = item['speed'] != null ? (item['speed'] as num).toDouble() : null;
        final heading = item['course'] != null ? (item['course'] as num).toDouble() : null;
        
        vehicles.add(
          VehicleLocationEntity(
            id: id,
            plate: name,
            lat: lat,
            lng: lng,
            timestamp: timestamp,
            speed: speed,
            heading: heading,
          ),
        );
      }
    }
    
    print('✅ Total de vehículos procesados: ${vehicles.length}');
    return vehicles;
  }

  /// Obtiene la ubicación de un vehículo específico
  Future<VehicleLocationEntity?> getVehicleLocation(String vehicleId) async {
    try {
      final locations = await getVehicleLocations();
      try {
        return locations.firstWhere((loc) => loc.id == vehicleId);
      } catch (_) {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
