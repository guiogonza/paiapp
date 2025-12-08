import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pai_app/data/services/gps_auth_service.dart';
import 'package:pai_app/domain/entities/vehicle_history_entity.dart';
import 'package:flutter/foundation.dart';

/// Servicio que obtiene el historial de ubicaciones de vehículos desde la API de GPS
class VehicleHistoryService {
  static const String _historyUrl = 'https://plataforma.sistemagps.online/api/get_history';
  final GPSAuthService _authService = GPSAuthService();

  /// Obtiene el historial de un vehículo específico
  /// 
  /// [vehicleId] - ID del vehículo
  /// [from] - Fecha de inicio (opcional, por defecto últimas 24 horas)
  /// [to] - Fecha de fin (opcional, por defecto ahora)
  Future<List<VehicleHistoryEntity>> getVehicleHistory(
    String vehicleId,
    String plate, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      // Obtener el API key
      final apiKey = await _authService.getApiKey();
      
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('No se pudo obtener el API key');
      }

      // Construir los parámetros de la URL
      // El API de GPS requiere: id (del GPS obtenido de get_devices), fecha inicio, hora inicio, fecha fin, hora fin
      // IMPORTANTE: Usar 'id' (no 'device_id') con el ID del GPS que viene de get_devices
      final params = <String, String>{
        'user_api_hash': apiKey,
        'lang': 'es',
        'id': vehicleId, // ID del GPS obtenido de get_devices
      };

      // Agregar fechas y horas separadas - SON OBLIGATORIAS según el error 422
      // El API espera: from_date, from_time, to_date, to_time (separados)
      // Si no se proporcionan, usar valores por defecto (últimas 24 horas)
      final fromDate = from ?? DateTime.now().subtract(const Duration(days: 1));
      final toDate = to ?? DateTime.now();
      
      params['from_date'] = _formatDateOnly(fromDate);
      params['from_time'] = _formatTimeOnly(fromDate);
      params['to_date'] = _formatDateOnly(toDate);
      params['to_time'] = _formatTimeOnly(toDate);
      
      if (kDebugMode) {
        print('📅 Enviando fechas obligatorias:');
        print('   from_date: ${params['from_date']}');
        print('   from_time: ${params['from_time']}');
        print('   to_date: ${params['to_date']}');
        print('   to_time: ${params['to_time']}');
      }

      // Construir la URL - Uri.parse maneja automáticamente la codificación de espacios
      final uri = Uri.parse(_historyUrl).replace(queryParameters: params);
      
      if (kDebugMode) {
        print('📡 Consultando historial para vehículo $vehicleId ($plate)');
        print('   URL completa: ${uri.toString()}');
        print('   Parámetros:');
        params.forEach((key, value) {
          print('     $key: $value');
        });
      }

      // Hacer la petición
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Flutter-App/1.0',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout al consultar historial');
        },
      );

      if (kDebugMode) {
        print('📡 Status Code: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        return _parseHistoryResponse(response, vehicleId, plate);
      } else {
        if (kDebugMode) {
          print('❌ Error al obtener historial: ${response.statusCode}');
          print('   URL solicitada: ${uri.toString()}');
          print('   Respuesta del servidor: ${response.body}');
          print('   Headers de respuesta: ${response.headers}');
        }
        
        // Error 422 generalmente significa parámetros incorrectos
        if (response.statusCode == 422) {
          throw Exception('Error 422: Parámetros incorrectos. Verifica el formato de las fechas y el device_id. Respuesta: ${response.body}');
        }
        
        // Error 500 es un error del servidor, pero puede ser por parámetros incorrectos
        if (response.statusCode == 500) {
          final errorBody = response.body;
          if (kDebugMode) {
            print('❌ Error 500 del servidor. Respuesta completa: $errorBody');
          }
          throw Exception('Error 500: Error interno del servidor. El API puede estar teniendo problemas o los parámetros no son correctos. Respuesta: $errorBody');
        }
        
        throw Exception('Error al obtener historial: ${response.statusCode} - ${response.body}');
      }
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        print('❌ Error de cliente HTTP: ${e.toString()}');
      }
      throw Exception('Error de conexión: ${e.toString()}');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al obtener historial: ${e.toString()}');
      }
      throw Exception('Error al obtener historial: ${e.toString()}');
    }
  }

  /// Formatea solo la fecha: YYYY-MM-DD
  /// El API podría esperar DD-MM-YYYY, pero probamos primero con YYYY-MM-DD
  String _formatDateOnly(DateTime dateTime) {
    final year = dateTime.year.toString();
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    // Formato estándar: YYYY-MM-DD
    return '$year-$month-$day';
  }

  /// Formatea solo la hora: HH:MM:SS
  /// El API podría esperar HH:MM sin segundos, pero probamos primero con HH:MM:SS
  String _formatTimeOnly(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    // Formato: HH:MM:SS
    return '$hour:$minute:$second';
  }

  /// Parsea la respuesta del historial
  List<VehicleHistoryEntity> _parseHistoryResponse(
    http.Response response,
    String vehicleId,
    String plate,
  ) {
    final data = json.decode(response.body);
    
    if (kDebugMode) {
      print('📦 Respuesta de historial recibida');
    }

    // La respuesta puede tener diferentes estructuras
    // Intentar extraer los items del historial
    List<dynamic> items = [];
    
    if (data is List) {
      items = data;
    } else if (data is Map) {
      // Puede venir como {"items": [...]} o {"data": [...]} o directamente los items
      items = data['items'] ?? 
              data['data'] ?? 
              data['history'] ?? 
              data['positions'] ?? 
              [];
    }

    if (kDebugMode) {
      print('📦 Total de puntos de historial recibidos: ${items.length}');
    }

    final history = <VehicleHistoryEntity>[];
    
    for (var item in items) {
      try {
        // Extraer coordenadas
        final lat = (item['lat'] ?? item['latitude'] ?? 0.0).toDouble();
        final lng = (item['lng'] ?? item['longitude'] ?? item['lon'] ?? 0.0).toDouble();
        
        // Extraer timestamp
        DateTime? timestamp;
        if (item['timestamp'] != null) {
          // Puede venir como Unix timestamp (segundos o milisegundos)
          final ts = item['timestamp'];
          if (ts is int) {
            // Si es muy grande, probablemente está en milisegundos
            timestamp = ts > 1000000000000
                ? DateTime.fromMillisecondsSinceEpoch(ts)
                : DateTime.fromMillisecondsSinceEpoch(ts * 1000);
          }
        } else if (item['time'] != null) {
          // Intentar parsear formato de fecha string
          try {
            final timeStr = item['time'] as String;
            // Intentar diferentes formatos
            if (timeStr.contains('-') && timeStr.contains(':')) {
              // Formato: "05-12-2025 11:57:52" o "2025-12-05 11:57:52"
              final parts = timeStr.split(' ');
              if (parts.length == 2) {
                final dateParts = parts[0].split('-');
                final timeParts = parts[1].split(':');
                if (dateParts.length == 3 && timeParts.length == 3) {
                  // Determinar si el formato es DD-MM-YYYY o YYYY-MM-DD
                  if (dateParts[0].length == 4) {
                    // YYYY-MM-DD
                    timestamp = DateTime(
                      int.parse(dateParts[0]),
                      int.parse(dateParts[1]),
                      int.parse(dateParts[2]),
                      int.parse(timeParts[0]),
                      int.parse(timeParts[1]),
                      int.parse(timeParts[2]),
                    );
                  } else {
                    // DD-MM-YYYY
                    timestamp = DateTime(
                      int.parse(dateParts[2]),
                      int.parse(dateParts[1]),
                      int.parse(dateParts[0]),
                      int.parse(timeParts[0]),
                      int.parse(timeParts[1]),
                      int.parse(timeParts[2]),
                    );
                  }
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Error al parsear fecha: ${item['time']} - $e');
            }
          }
        }

        if (timestamp == null) {
          // Si no se pudo parsear, usar la fecha actual
          timestamp = DateTime.now();
        }

        // Extraer otros campos
        final speed = item['speed'] != null ? (item['speed'] as num).toDouble() : null;
        final heading = item['course'] != null 
            ? (item['course'] as num).toDouble() 
            : (item['heading'] != null ? (item['heading'] as num).toDouble() : null);
        final altitude = item['altitude'] != null ? (item['altitude'] as num).toDouble() : null;
        final valid = item['valid'] as bool?;

        history.add(
          VehicleHistoryEntity(
            vehicleId: vehicleId,
            plate: plate,
            lat: lat,
            lng: lng,
            timestamp: timestamp,
            speed: speed,
            heading: heading,
            altitude: altitude,
            valid: valid,
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error al parsear punto de historial: $e');
        }
      }
    }

    if (kDebugMode) {
      print('✅ Total de puntos de historial procesados: ${history.length}');
    }

    return history;
  }
}

