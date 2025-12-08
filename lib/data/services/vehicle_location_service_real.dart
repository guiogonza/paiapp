import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pai_app/domain/entities/vehicle_location_entity.dart';

/// Servicio real que consume la API externa de GPS
/// Reemplaza el servicio mock cuando tengas el endpoint real
class VehicleLocationServiceReal {
  // TODO: Reemplaza con tu endpoint real
  static const String _baseUrl = 'TU_ENDPOINT_AQUI';
  
  // TODO: Si requiere autenticación, agrega aquí
  // static const String _apiKey = 'TU_API_KEY';
  // static const Map<String, String> _headers = {
  //   'Authorization': 'Bearer $_apiKey',
  //   'Content-Type': 'application/json',
  // };

  /// Obtiene las ubicaciones de todos los vehículos desde la API real
  Future<List<VehicleLocationEntity>> getVehicleLocations() async {
    try {
      // TODO: Ajusta la URL y los headers según tu API
      final response = await http.get(
        Uri.parse('$_baseUrl/devices'), // Ajusta la ruta según tu API
        // headers: _headers, // Descomenta si necesitas headers
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // TODO: Ajusta el mapeo según la estructura de tu respuesta JSON
        return data.map((json) {
          return VehicleLocationEntity(
            id: json['id']?.toString() ?? json['device_id']?.toString() ?? '',
            plate: json['plate'] ?? json['license_plate'] ?? json['placa'] ?? '',
            lat: (json['lat'] ?? json['latitude'] ?? 0.0).toDouble(),
            lng: (json['lng'] ?? json['longitude'] ?? json['lng'] ?? 0.0).toDouble(),
            timestamp: json['timestamp'] != null
                ? DateTime.parse(json['timestamp'])
                : json['last_update'] != null
                    ? DateTime.parse(json['last_update'])
                    : null,
            speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
            heading: json['heading'] != null ? (json['heading'] as num).toDouble() : null,
          );
        }).toList();
      } else {
        throw Exception('Error al obtener ubicaciones: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: ${e.toString()}');
    }
  }

  /// Obtiene la ubicación de un vehículo específico
  Future<VehicleLocationEntity?> getVehicleLocation(String vehicleId) async {
    try {
      // TODO: Ajusta la URL según tu API
      final response = await http.get(
        Uri.parse('$_baseUrl/devices/$vehicleId'),
        // headers: _headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        return VehicleLocationEntity(
          id: jsonData['id']?.toString() ?? jsonData['device_id']?.toString() ?? '',
          plate: jsonData['plate'] ?? jsonData['license_plate'] ?? jsonData['placa'] ?? '',
          lat: (jsonData['lat'] ?? jsonData['latitude'] ?? 0.0).toDouble(),
          lng: (jsonData['lng'] ?? jsonData['longitude'] ?? jsonData['lng'] ?? 0.0).toDouble(),
          timestamp: jsonData['timestamp'] != null
              ? DateTime.parse(jsonData['timestamp'])
              : jsonData['last_update'] != null
                  ? DateTime.parse(jsonData['last_update'])
                  : null,
          speed: jsonData['speed'] != null ? (jsonData['speed'] as num).toDouble() : null,
          heading: jsonData['heading'] != null ? (jsonData['heading'] as num).toDouble() : null,
        );
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}

