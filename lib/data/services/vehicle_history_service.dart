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

      // Construir los parámetros de la URL en el orden correcto
      // Orden correcto según el API: lang, user_api_hash, report_id, device_id, from_date, to_date, from_time, to_time
      final fromDate = from ?? DateTime.now().subtract(const Duration(days: 1));
      final toDate = to ?? DateTime.now();
      
      // Construir parámetros en el orden exacto requerido por el API
      final params = <String, String>{
        'lang': 'es',
        'user_api_hash': apiKey,
        'report_id': '1',
        'device_id': vehicleId, // ID del GPS obtenido de get_devices
        'from_date': _formatDateOnly(fromDate),
        'to_date': _formatDateOnly(toDate),
        'from_time': _formatTimeOnly(fromDate),
        'to_time': _formatTimeOnly(toDate),
      };
      
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
        if (kDebugMode) {
          print('✅ Respuesta exitosa (200)');
          print('📦 JSON completo de la respuesta:');
          print('   ${response.body}');
          try {
            final jsonData = json.decode(response.body);
            print('📦 JSON parseado:');
            print('   Tipo: ${jsonData.runtimeType}');
            if (jsonData is Map) {
              print('   Keys: ${jsonData.keys.toList()}');
            } else if (jsonData is List) {
              print('   Total de items: ${jsonData.length}');
              if (jsonData.isNotEmpty) {
                print('   Primer item: ${jsonData.first}');
              }
            }
          } catch (e) {
            print('⚠️ Error al parsear JSON: $e');
          }
        }
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
    if (kDebugMode) {
      print('📦 Parseando respuesta del historial...');
      print('   Body length: ${response.body.length} caracteres');
    }
    
    final data = json.decode(response.body);
    
    if (kDebugMode) {
      print('📦 Respuesta de historial recibida');
      print('   Tipo de dato: ${data.runtimeType}');
      if (data is Map) {
        print('   Estructura del Map:');
        data.forEach((key, value) {
          print('     $key: ${value.runtimeType}${value is List ? ' (${value.length} items)' : ''}');
        });
      } else if (data is List) {
        print('   Es una Lista con ${data.length} items');
        if (data.isNotEmpty) {
          print('   Estructura del primer item:');
          final firstItem = data.first;
          if (firstItem is Map) {
            firstItem.forEach((key, value) {
              print('     $key: $value (${value.runtimeType})');
            });
          }
        }
      }
    }

    // La respuesta tiene estructura anidada: {"items": [{"items": [...]}]}
    List<dynamic> items = [];
    
    if (data is Map) {
      // Buscar items en el nivel superior
      final topLevelItems = data['items'] as List?;
      if (topLevelItems != null && topLevelItems.isNotEmpty) {
        // La estructura es: items[0].items[] contiene los puntos reales
        for (var topItem in topLevelItems) {
          if (topItem is Map && topItem['items'] != null) {
            final nestedItems = topItem['items'] as List;
            items.addAll(nestedItems);
          }
        }
      } else {
        // Fallback: buscar en otras keys comunes
        items = data['data'] ?? 
                data['history'] ?? 
                data['positions'] ?? 
                [];
      }
    } else if (data is List) {
      items = data;
    }

    if (kDebugMode) {
      print('📦 Total de puntos de historial recibidos: ${items.length}');
      if (items.isNotEmpty) {
        print('   Estructura del primer punto:');
        final firstPoint = items.first;
        if (firstPoint is Map) {
          firstPoint.forEach((key, value) {
            print('     $key: $value');
          });
        }
      }
    }

    final history = <VehicleHistoryEntity>[];
    
    for (var item in items) {
      try {
        if (item is! Map) continue;
        
        // Extraer coordenadas (priorizar latitude/longitude, luego lat/lng)
        final lat = (item['latitude'] ?? item['lat'] ?? 0.0).toDouble();
        final lng = (item['longitude'] ?? item['lng'] ?? item['lon'] ?? 0.0).toDouble();
        
        // Extraer timestamp - usar 'time' con formato DD-MM-YYYY HH:MM:SS
        DateTime? timestamp;
        if (item['time'] != null) {
          try {
            final timeStr = item['time'] as String;
            // Formato esperado: "08-12-2025 09:20:39" (DD-MM-YYYY HH:MM:SS)
            if (timeStr.contains('-') && timeStr.contains(':')) {
              final parts = timeStr.split(' ');
              if (parts.length == 2) {
                final dateParts = parts[0].split('-');
                final timeParts = parts[1].split(':');
                if (dateParts.length == 3 && timeParts.length == 3) {
                  // Formato DD-MM-YYYY
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
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Error al parsear fecha: ${item['time']} - $e');
            }
          }
        }
        
        // Si no se pudo parsear 'time', intentar con 'raw_time' (formato YYYY-MM-DD)
        if (timestamp == null && item['raw_time'] != null) {
          try {
            final rawTimeStr = item['raw_time'] as String;
            timestamp = DateTime.parse(rawTimeStr);
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Error al parsear raw_time: ${item['raw_time']} - $e');
            }
          }
        }

        timestamp ??= DateTime.now();

        // Extraer otros campos
        final speed = item['speed'] != null ? (item['speed'] as num).toDouble() : null;
        final heading = item['course'] != null 
            ? (item['course'] as num).toDouble() 
            : (item['heading'] != null ? (item['heading'] as num).toDouble() : null);
        final altitude = item['altitude'] != null ? (item['altitude'] as num).toDouble() : null;
        
        // Extraer 'valid' - puede venir como 1/0 o true/false
        bool? valid;
        if (item['valid'] != null) {
          if (item['valid'] is bool) {
            valid = item['valid'] as bool;
          } else if (item['valid'] is int) {
            valid = (item['valid'] as int) == 1;
          }
        }
        
        // Extraer 'ignition' de other_arr
        bool? ignition;
        if (item['other_arr'] != null && item['other_arr'] is List) {
          final otherArr = item['other_arr'] as List;
          for (var otherItem in otherArr) {
            if (otherItem is String && otherItem.startsWith('ignition: ')) {
              final ignitionStr = otherItem.replaceFirst('ignition: ', '');
              ignition = ignitionStr.toLowerCase() == 'true';
              break;
            }
          }
        }

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
            ignition: ignition, // Agregar ignition
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error al parsear punto de historial: $e');
          print('   Item: $item');
        }
      }
    }

    if (kDebugMode) {
      print('✅ Total de puntos de historial procesados: ${history.length}');
    }

    return history;
  }
}

