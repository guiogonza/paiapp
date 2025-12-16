import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/data/models/maintenance_model.dart';
import 'package:pai_app/data/services/gps_auth_service.dart';
import 'package:pai_app/domain/entities/maintenance_entity.dart';
import 'package:pai_app/domain/failures/maintenance_failure.dart';
import 'package:pai_app/domain/repositories/maintenance_repository.dart';

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GPSAuthService _gpsAuthService = GPSAuthService();
  static const String _tableName = 'maintenance';
  static const String _vehiclesTableName = 'vehicles';
  static const String _devicesUrl = 'https://plataforma.sistemagps.online/api/get_devices';

  /// Extrae el kilometraje del XML sucio del GPS
  /// Algoritmo robusto que busca múltiples etiquetas en orden de prioridad
  double? extractMileage(String rawData) {
    // 1. Normalización: Todo a minúsculas y trim para evitar errores de case/espacios
    final cleanData = rawData.toLowerCase().trim();
    debugPrint('--- DEBUG GPS RAW: $cleanData ---'); // Vital para depurar

    // 2. Definición de Targets: Qué etiquetas buscar (en orden de prioridad)
    final tags = ['totaldistance', 'total_distance', 'odometer', 'distance'];

    for (final tag in tags) {
      // 3. Regex Permisiva: Busca CUALQUIER_COSA
      // El ([\d.]+) captura solo números y puntos.
      // Usar regex más flexible que permita espacios y caracteres especiales
      final regex = RegExp('<$tag>\\s*([\\d\\.]+)\\s*<\\/$tag>', caseSensitive: false);
      final match = regex.firstMatch(cleanData);

      if (match != null) {
        final valueStr = match.group(1)?.trim();
        debugPrint('--- DEBUG: Match encontrado para tag "$tag" con valor: "$valueStr" ---');
        if (valueStr != null && valueStr.isNotEmpty) {
          try {
            final meters = double.parse(valueStr);
            // 4. Regla de Negocio: Convertir Metros a Kilómetros
            final kms = meters / 1000.0;
            debugPrint('--- ÉXITO: Encontrado $tag: $meters m -> $kms km ---');
            return kms;
          } catch (e) {
            debugPrint('--- ERROR PARSEANDO NUMERO: $valueStr - Error: $e ---');
          }
        } else {
          debugPrint('--- DEBUG: valueStr es null o vacío para tag "$tag" ---');
        }
      } else {
        debugPrint('--- DEBUG: No match para tag "$tag" ---');
      }
    }
    debugPrint('--- FALLO: No se encontró ninguna etiqueta de kilometraje ---');
    return null;
  }

  @override
  Future<Either<MaintenanceFailure, List<MaintenanceEntity>>> getHistory(String vehicleId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('vehicle_id', vehicleId)
          .order('service_date', ascending: false);

      final maintenanceList = (response as List)
          .map((json) => MaintenanceModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(maintenanceList);
    } on PostgrestException catch (e) {
      return Left(MaintenanceDatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(MaintenanceNetworkFailure());
    } catch (e) {
      return Left(MaintenanceUnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<MaintenanceFailure, List<MaintenanceEntity>>> getAllMaintenance() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .order('service_date', ascending: false);

      final maintenanceList = (response as List)
          .map((json) => MaintenanceModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(maintenanceList);
    } on PostgrestException catch (e) {
      return Left(MaintenanceDatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(MaintenanceNetworkFailure());
    } catch (e) {
      return Left(MaintenanceUnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<MaintenanceFailure, MaintenanceEntity>> registerMaintenance(
    MaintenanceEntity maintenance,
  ) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return const Left(MaintenanceValidationFailure('Usuario no autenticado'));
      }

      final maintenanceModel = MaintenanceModel.fromEntity(maintenance);
      final maintenanceData = maintenanceModel.toJson();
      
      // CRÍTICO: Asegurar que created_by sea el ID del usuario actual
      maintenanceData['created_by'] = currentUser.id;

      print('📝 Registrando mantenimiento: $maintenanceData');
      print('📝 Kilometraje al servicio: ${maintenance.kmAtService} km');

      // Transacción: Insertar mantenimiento y actualizar kilometraje
      // Nota: Supabase no soporta transacciones reales, pero hacemos ambas operaciones
      
      // 1. Insertar mantenimiento
      final maintenanceResponse = await _supabase
          .from(_tableName)
          .insert(maintenanceData)
          .select()
          .single();

      print('✅ Mantenimiento registrado: ${maintenanceResponse['id']}');

      // 2. Actualizar kilometraje del vehículo con km_at_service
      await _supabase
          .from(_vehiclesTableName)
          .update({'current_mileage': maintenance.kmAtService})
          .eq('id', maintenance.vehicleId);

      print('✅ Kilometraje actualizado: ${maintenance.kmAtService} km');

      // 3. Limpiar alertas pendientes del mismo tipo (y posición si es llanta) para este vehículo
      // Esto hace que las alertas anteriores desaparezcan de la lista
      var alertCleanupQuery = _supabase
          .from(_tableName)
          .update({
            'next_change_km': null,
            'alert_date': null,
          })
          .eq('vehicle_id', maintenance.vehicleId)
          .eq('service_type', maintenance.serviceType)
          .neq('id', maintenanceResponse['id'] as String); // Excluir el mantenimiento recién creado

      // Si es llanta, también filtrar por posición
      if (maintenance.serviceType == 'Llantas' && maintenance.tirePosition != null) {
        final tirePos = maintenance.tirePosition!; // Safe: ya verificamos que no es null
        alertCleanupQuery = alertCleanupQuery.eq('tire_position', tirePos);
      }

      await alertCleanupQuery;

      print('✅ Alertas anteriores limpiadas para ${maintenance.serviceType}${maintenance.tirePosition != null ? ' - Posición ${maintenance.tirePosition}' : ''}');

      final createdMaintenance = MaintenanceModel.fromJson(maintenanceResponse);
      return Right(createdMaintenance.toEntity());
    } on PostgrestException catch (e) {
      return Left(MaintenanceDatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(MaintenanceNetworkFailure());
    } catch (e) {
      return Left(MaintenanceUnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<MaintenanceFailure, double?>> getLiveGpsMileage(String gpsDeviceId) async {
    try {
      // VALIDACIÓN CRÍTICA: No permitir búsqueda sin ID específico
      if (gpsDeviceId.isEmpty) {
        print('❌ ERROR: gpsDeviceId está vacío. No se puede buscar sin ID específico.');
        return const Left(MaintenanceValidationFailure('ID del dispositivo GPS no proporcionado'));
      }
      
      print('🔍 Obteniendo kilometraje GPS para dispositivo específico: $gpsDeviceId');
      
      // Autenticación
      final email = 'luisr@rastrear.com.co';
      final password = '2023';
      
      final apiKey = await _gpsAuthService.login(email, password);
      if (apiKey == null || apiKey.isEmpty) {
        return const Left(MaintenanceNetworkFailure('Error al autenticar con GPS'));
      }

      // Obtener dispositivos
      final devicesUri = Uri.parse(_devicesUrl).replace(queryParameters: {
        'user_api_hash': apiKey,
        'lang': 'es',
      });

      final response = await http.get(
        devicesUri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Flutter-App/1.0',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return Left(MaintenanceNetworkFailure('Error ${response.statusCode} al obtener dispositivos'));
      }

      // Buscar SOLO el dispositivo específico con el ID exacto
      final devicesData = json.decode(response.body);
      double? mileage;
      bool deviceFound = false;
      
      print('🔍🔍🔍 Buscando ID específico: $gpsDeviceId');
      print('🔍 Tipo de gpsDeviceId: ${gpsDeviceId.runtimeType}');

      if (devicesData is List) {
        // Usar label para poder hacer break del loop externo
        deviceSearchLoop: for (var group in devicesData) {
          if (group is Map && group['items'] != null) {
            final items = group['items'] as List;
            print('🔍 Procesando grupo con ${items.length} dispositivos');
            
            // ITERAR sobre TODOS los dispositivos y buscar el que coincida EXACTAMENTE
            for (var device in items) {
              final deviceId = device['id'];
              final deviceIdStr = deviceId?.toString() ?? '';
              final deviceIdNum = deviceId is num ? deviceId.toInt() : null;
              
              // Comparar tanto como string como número para asegurar coincidencia
              final matchesAsString = deviceIdStr == gpsDeviceId;
              final matchesAsNumber = deviceIdNum != null && deviceIdNum.toString() == gpsDeviceId;
              final matches = matchesAsString || matchesAsNumber;
              
              print('🔍 Comparando: dispositivo.id=$deviceIdStr (tipo: ${deviceId.runtimeType}) vs buscado=$gpsDeviceId -> $matches');
              
              if (matches) {
                deviceFound = true;
                print('✅✅✅✅✅ Dispositivo ENCONTRADO: ID=$deviceIdStr (buscado: $gpsDeviceId) ✅✅✅✅✅');
                print('🔍 Campos disponibles: ${device.keys.toList()}');
                
                // Buscar odómetro en diferentes campos
                if (device['odometer'] != null) {
                  mileage = (device['odometer'] as num).toDouble() / 1000; // Convertir a km
                  print('✅ Kilometraje encontrado en campo odometer: $mileage km');
                } else if (device['totalDistance'] != null) {
                  mileage = (device['totalDistance'] as num).toDouble() / 1000;
                  print('✅ Kilometraje encontrado en campo totalDistance: $mileage km');
                } else if (device['total_distance'] != null) {
                  mileage = (device['total_distance'] as num).toDouble() / 1000;
                  print('✅ Kilometraje encontrado en campo total_distance: $mileage km');
                } else if (device['other'] != null) {
                  print('🔍 Campo other encontrado, tipo: ${device['other'].runtimeType}');
                  
                  // El campo 'other' puede venir como string XML o como objeto parseado
                  final otherValue = device['other'];
                  
                  if (otherValue is String) {
                    // Es un string XML, usar extractMileage
                    print('🔍 other es String, llamando extractMileage...');
                    final otherStr = otherValue;
                    print('🔍 Llamando extractMileage con: ${otherStr.length > 200 ? otherStr.substring(0, 200) + '...' : otherStr}');
                    mileage = extractMileage(otherStr);
                    if (mileage == null) {
                      print('⚠️ extractMileage devolvió null');
                    } else {
                      print('✅ extractMileage devolvió: $mileage km');
                    }
                  } else if (otherValue is Map) {
                    // Es un objeto parseado, buscar totaldistance directamente
                    print('🔍 other es Map, buscando totaldistance en el objeto...');
                    if (otherValue['totaldistance'] != null) {
                      final meters = (otherValue['totaldistance'] as num).toDouble();
                      mileage = meters / 1000.0;
                      print('✅ Kilometraje encontrado en other.totaldistance: $meters m -> $mileage km');
                    } else if (otherValue['total_distance'] != null) {
                      final meters = (otherValue['total_distance'] as num).toDouble();
                      mileage = meters / 1000.0;
                      print('✅ Kilometraje encontrado en other.total_distance: $meters m -> $mileage km');
                    } else if (otherValue['odometer'] != null) {
                      final meters = (otherValue['odometer'] as num).toDouble();
                      mileage = meters / 1000.0;
                      print('✅ Kilometraje encontrado en other.odometer: $meters m -> $mileage km');
                    } else {
                      print('⚠️ No se encontró totaldistance en el objeto other');
                      print('🔍 Claves disponibles en other: ${otherValue.keys.toList()}');
                      // Intentar convertir a string y parsear como XML
                      final otherStr = otherValue.toString();
                      print('🔍 Intentando parsear como XML: ${otherStr.length > 200 ? otherStr.substring(0, 200) + '...' : otherStr}');
                      mileage = extractMileage(otherStr);
                    }
                  } else {
                    // Otro tipo, intentar convertir a string
                    print('🔍 other es de tipo ${otherValue.runtimeType}, convirtiendo a string...');
                    final otherStr = otherValue.toString();
                    mileage = extractMileage(otherStr);
                  }
                } else {
                  print('⚠️ No se encontró campo other en el dispositivo');
                }
                
                // Si encontramos el dispositivo específico, salir de TODOS los loops
                break deviceSearchLoop;
              }
              // Si no coincide, continuar con el siguiente dispositivo
            }
          }
        }
      }

      // Validar que se encontró el dispositivo
      if (!deviceFound) {
        print('❌❌❌ ERROR: Dispositivo con ID $gpsDeviceId NO encontrado en la lista de dispositivos GPS');
        return Left(MaintenanceValidationFailure('Dispositivo GPS con ID $gpsDeviceId no encontrado'));
      }
      
      if (mileage != null) {
        print('✅✅✅ Kilometraje GPS obtenido exitosamente para dispositivo $gpsDeviceId: $mileage km');
        print('✅✅✅ Retornando Right($mileage)');
        return Right(mileage);
      } else {
        print('⚠️⚠️⚠️ Dispositivo $gpsDeviceId encontrado pero no tiene kilometraje disponible');
        print('⚠️⚠️⚠️ Retornando Right(null)');
        return const Right(null);
      }
    } catch (e) {
      print('❌ Error al obtener kilometraje GPS: $e');
      return Left(MaintenanceUnknownFailure('Error al obtener kilometraje: $e'));
    }
  }

  @override
  Future<Either<MaintenanceFailure, List<MaintenanceEntity>>> getPendingAlerts() async {
    try {
      // 1. Obtener todos los mantenimientos con next_change_km o alert_date
      final maintenanceResponse = await _supabase
          .from(_tableName)
          .select()
          .or('next_change_km.not.is.null,alert_date.not.is.null')
          .order('service_date', ascending: false);

      final allMaintenance = (maintenanceResponse as List)
          .map((json) => MaintenanceModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      if (allMaintenance.isEmpty) {
        return const Right([]);
      }

      // 2. Obtener los vehículos únicos con su kilometraje actual
      final vehicleIds = allMaintenance.map((m) => m.vehicleId).toSet().toList();
      
      // Supabase no tiene .in_(), así que hacemos queries individuales o usamos un filtro
      // Por eficiencia, obtenemos todos los vehículos y filtramos en memoria
      final vehiclesResponse = await _supabase
          .from(_vehiclesTableName)
          .select('id, current_mileage');

      // Crear un mapa de vehicle_id -> current_mileage (solo para los vehículos relevantes)
      final vehicleMileageMap = <String, double>{};
      final vehiclesList = vehiclesResponse as List;
      for (var vehicle in vehiclesList) {
        final vehicleMap = vehicle as Map<String, dynamic>;
        if (vehicleMap['id'] != null) {
          final vehicleId = vehicleMap['id'] as String;
          // Solo incluir si está en nuestra lista de vehículos relevantes
          if (vehicleIds.contains(vehicleId) && vehicleMap['current_mileage'] != null) {
            vehicleMileageMap[vehicleId] = 
                (vehicleMap['current_mileage'] as num).toDouble();
          }
        }
      }

      // 3. Filtrar mantenimientos que están dentro del rango de alerta
      final now = DateTime.now();
      final alertThresholdKm = 2000.0; // 2000 km de antelación
      final alertThresholdDays = 30; // 30 días de antelación

      final pendingAlerts = <MaintenanceEntity>[];

      for (final maintenance in allMaintenance) {
        bool shouldAlert = false;
        String? alertReason;

        // Verificar alerta por kilometraje
        if (maintenance.nextChangeKm != null) {
          final vehicleMileage = vehicleMileageMap[maintenance.vehicleId];
          if (vehicleMileage != null) {
            final kmRemaining = maintenance.nextChangeKm! - vehicleMileage;
            if (kmRemaining <= alertThresholdKm && kmRemaining > 0) {
              shouldAlert = true;
              alertReason = 'Faltan ${kmRemaining.toStringAsFixed(0)} km';
            } else if (kmRemaining <= 0) {
              // Ya pasó el kilometraje, también alertar
              shouldAlert = true;
              alertReason = 'Vencido: ${(-kmRemaining).toStringAsFixed(0)} km atrás';
            }
          }
        }

        // Verificar alerta por fecha
        if (maintenance.alertDate != null) {
          final daysRemaining = maintenance.alertDate!.difference(now).inDays;
          if (daysRemaining <= alertThresholdDays && daysRemaining >= 0) {
            shouldAlert = true;
            alertReason = alertReason != null 
                ? '$alertReason / Faltan $daysRemaining días'
                : 'Faltan $daysRemaining días';
          } else if (daysRemaining < 0) {
            // Ya pasó la fecha, también alertar
            shouldAlert = true;
            alertReason = alertReason != null
                ? '$alertReason / Vencido hace ${-daysRemaining} días'
                : 'Vencido hace ${-daysRemaining} días';
          }
        }

        if (shouldAlert) {
          pendingAlerts.add(maintenance);
        }
      }

      return Right(pendingAlerts);
    } on PostgrestException catch (e) {
      return Left(MaintenanceDatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(MaintenanceNetworkFailure());
    } catch (e) {
      return Left(MaintenanceUnknownFailure(_mapGenericError(e)));
    }
  }

  String _mapPostgrestError(PostgrestException e) {
    return e.message;
  }

  @override
  Future<Either<MaintenanceFailure, int>> checkActiveAlerts() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return const Left(MaintenanceValidationFailure('Usuario no autenticado'));
      }

      // 1. Obtener todos los mantenimientos con next_change_km o alert_date
      final maintenanceResponse = await _supabase
          .from(_tableName)
          .select('*, vehicles!inner(id, current_mileage)')
          .eq('created_by', currentUser.id)
          .or('next_change_km.not.is.null,alert_date.not.is.null');

      final allMaintenance = (maintenanceResponse as List)
          .map((json) => MaintenanceModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      if (allMaintenance.isEmpty) {
        return const Right(0);
      }

      // 2. Obtener kilometraje actual de vehículos
      final vehicleMileageMap = <String, double>{};
      for (var maintenanceJson in maintenanceResponse) {
        final vehicle = maintenanceJson['vehicles'];
        if (vehicle != null && vehicle['id'] != null && vehicle['current_mileage'] != null) {
          final vehicleId = vehicle['id'] as String;
          final currentMileage = (vehicle['current_mileage'] as num).toDouble();
          vehicleMileageMap[vehicleId] = currentMileage;
        }
      }

      // 3. Verificar alertas activas
      final now = DateTime.now();
      int activeAlertsCount = 0;
      const alertKmThreshold = 2000.0; // 2000 km antes

      for (final maintenance in allMaintenance) {
        bool isActive = false;

        // Verificar alerta por kilometraje
        if (maintenance.nextChangeKm != null) {
          final vehicleMileage = vehicleMileageMap[maintenance.vehicleId];
          if (vehicleMileage != null) {
            // Alerta activa si: current_km >= (next_change_km - 2000)
            final alertKm = maintenance.nextChangeKm! - alertKmThreshold;
            if (vehicleMileage >= alertKm) {
              isActive = true;
            }
          }
        }

        // Verificar alerta por fecha
        if (maintenance.alertDate != null) {
          // Alerta activa si: current_date >= alert_date
          if (now.isAfter(maintenance.alertDate!) || now.isAtSameMomentAs(maintenance.alertDate!)) {
            isActive = true;
          }
        }

        if (isActive) {
          activeAlertsCount++;
        }
      }

      return Right(activeAlertsCount);
    } on PostgrestException catch (e) {
      return Left(MaintenanceDatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(MaintenanceNetworkFailure());
    } catch (e) {
      return Left(MaintenanceUnknownFailure(_mapGenericError(e)));
    }
  }

  String _mapGenericError(dynamic e) {
    return e.toString().isNotEmpty ? e.toString() : 'Error desconocido';
  }
}

