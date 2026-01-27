import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pai_app/data/models/maintenance_model.dart';
import 'package:pai_app/data/services/gps_auth_service.dart';
import 'package:pai_app/data/services/local_api_client.dart';
import 'package:pai_app/domain/entities/maintenance_entity.dart';
import 'package:pai_app/domain/failures/maintenance_failure.dart';
import 'package:pai_app/domain/repositories/maintenance_repository.dart';

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  final LocalApiClient _localApi = LocalApiClient();
  final GPSAuthService _gpsAuthService = GPSAuthService();
  static const String _tableName = 'maintenance';
  static const String _vehiclesTableName = 'vehicles';
  static const String _devicesUrl =
      'https://plataforma.sistemagps.online/api/get_devices';

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
      final regex = RegExp(
        '<$tag>\\s*([\\d\\.]+)\\s*<\\/$tag>',
        caseSensitive: false,
      );
      final match = regex.firstMatch(cleanData);

      if (match != null) {
        final valueStr = match.group(1)?.trim();
        debugPrint(
          '--- DEBUG: Match encontrado para tag "$tag" con valor: "$valueStr" ---',
        );
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
  Future<Either<MaintenanceFailure, List<MaintenanceEntity>>> getHistory(
    String vehicleId,
  ) async {
    try {
      final response = await _localApi.getMaintenance(vehicleId: vehicleId);

      final maintenanceList = response
          .map((json) => MaintenanceModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(maintenanceList);
    } on SocketException catch (_) {
      return const Left(MaintenanceNetworkFailure());
    } catch (e) {
      return Left(MaintenanceUnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<MaintenanceFailure, List<MaintenanceEntity>>>
  getAllMaintenance() async {
    try {
      final response = await _localApi.getMaintenance();

      final maintenanceList = response
          .map((json) => MaintenanceModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(maintenanceList);
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
      final currentUser = _localApi.currentUser;
      if (currentUser == null) {
        return const Left(
          MaintenanceValidationFailure('Usuario no autenticado'),
        );
      }

      final maintenanceModel = MaintenanceModel.fromEntity(maintenance);
      final maintenanceData = maintenanceModel.toJson();

      print('📝 Registrando mantenimiento: $maintenanceData');
      print('📝 Kilometraje al servicio: ${maintenance.kmAtService} km');

      // 1. Insertar mantenimiento
      final maintenanceResponse = await _localApi.createMaintenance(
        maintenanceData,
      );

      print('✅ Mantenimiento registrado: ${maintenanceResponse['id']}');

      // 2. Actualizar kilometraje del vehículo con km_at_service
      await _localApi.updateVehicle(maintenance.vehicleId, {
        'current_mileage': maintenance.kmAtService,
      });

      print('✅ Kilometraje actualizado: ${maintenance.kmAtService} km');

      // 3. Limpiar alertas pendientes del mismo tipo
      await _localApi.clearMaintenanceAlerts(
        vehicleId: maintenance.vehicleId,
        serviceType: maintenance.serviceType,
        excludeId: maintenanceResponse['id'] as String,
        tirePosition: maintenance.tirePosition,
      );

      print(
        '✅ Alertas anteriores limpiadas para ${maintenance.serviceType}${maintenance.tirePosition != null ? ' - Posición ${maintenance.tirePosition}' : ''}',
      );

      final createdMaintenance = MaintenanceModel.fromJson(maintenanceResponse);
      return Right(createdMaintenance.toEntity());
    } on SocketException catch (_) {
      return const Left(MaintenanceNetworkFailure());
    } catch (e) {
      return Left(MaintenanceUnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<MaintenanceFailure, double?>> getLiveGpsMileage(
    String gpsDeviceId,
  ) async {
    try {
      // VALIDACIÓN CRÍTICA: No permitir búsqueda sin ID específico
      if (gpsDeviceId.isEmpty) {
        print(
          '❌ ERROR: gpsDeviceId está vacío. No se puede buscar sin ID específico.',
        );
        return const Left(
          MaintenanceValidationFailure(
            'ID del dispositivo GPS no proporcionado',
          ),
        );
      }

      print(
        '🔍 Obteniendo kilometraje GPS para dispositivo específico: $gpsDeviceId',
      );

      // Autenticación
      final email = 'luisr@rastrear.com.co';
      final password = '2023';

      final apiKey = await _gpsAuthService.login(email, password);
      if (apiKey == null || apiKey.isEmpty) {
        return const Left(
          MaintenanceNetworkFailure('Error al autenticar con GPS'),
        );
      }

      // Obtener dispositivos
      final devicesUri = Uri.parse(
        _devicesUrl,
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
        return Left(
          MaintenanceNetworkFailure(
            'Error ${response.statusCode} al obtener dispositivos',
          ),
        );
      }

      // Buscar SOLO el dispositivo específico con el ID exacto
      final devicesData = json.decode(response.body);
      double? mileage;
      bool deviceFound = false;

      print('🔍🔍🔍 Buscando ID específico: $gpsDeviceId');
      print('🔍 Tipo de gpsDeviceId: ${gpsDeviceId.runtimeType}');

      if (devicesData is List) {
        // Usar label para poder hacer break del loop externo
        deviceSearchLoop:
        for (var group in devicesData) {
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
              final matchesAsNumber =
                  deviceIdNum != null && deviceIdNum.toString() == gpsDeviceId;
              final matches = matchesAsString || matchesAsNumber;

              print(
                '🔍 Comparando: dispositivo.id=$deviceIdStr (tipo: ${deviceId.runtimeType}) vs buscado=$gpsDeviceId -> $matches',
              );

              if (matches) {
                deviceFound = true;
                print(
                  '✅✅✅✅✅ Dispositivo ENCONTRADO: ID=$deviceIdStr (buscado: $gpsDeviceId) ✅✅✅✅✅',
                );
                print('🔍 Campos disponibles: ${device.keys.toList()}');

                // Buscar odómetro en diferentes campos
                if (device['odometer'] != null) {
                  mileage =
                      (device['odometer'] as num).toDouble() /
                      1000; // Convertir a km
                  print(
                    '✅ Kilometraje encontrado en campo odometer: $mileage km',
                  );
                } else if (device['totalDistance'] != null) {
                  mileage = (device['totalDistance'] as num).toDouble() / 1000;
                  print(
                    '✅ Kilometraje encontrado en campo totalDistance: $mileage km',
                  );
                } else if (device['total_distance'] != null) {
                  mileage = (device['total_distance'] as num).toDouble() / 1000;
                  print(
                    '✅ Kilometraje encontrado en campo total_distance: $mileage km',
                  );
                } else if (device['other'] != null) {
                  print(
                    '🔍 Campo other encontrado, tipo: ${device['other'].runtimeType}',
                  );

                  // El campo 'other' puede venir como string XML o como objeto parseado
                  final otherValue = device['other'];

                  if (otherValue is String) {
                    // Es un string XML, usar extractMileage
                    print('🔍 other es String, llamando extractMileage...');
                    final otherStr = otherValue;
                    print(
                      '🔍 Llamando extractMileage con: ${otherStr.length > 200 ? '${otherStr.substring(0, 200)}...' : otherStr}',
                    );
                    mileage = extractMileage(otherStr);
                    if (mileage == null) {
                      print('⚠️ extractMileage devolvió null');
                    } else {
                      print('✅ extractMileage devolvió: $mileage km');
                    }
                  } else if (otherValue is Map) {
                    // Es un objeto parseado, buscar totaldistance directamente
                    print(
                      '🔍 other es Map, buscando totaldistance en el objeto...',
                    );
                    if (otherValue['totaldistance'] != null) {
                      final meters = (otherValue['totaldistance'] as num)
                          .toDouble();
                      mileage = meters / 1000.0;
                      print(
                        '✅ Kilometraje encontrado en other.totaldistance: $meters m -> $mileage km',
                      );
                    } else if (otherValue['total_distance'] != null) {
                      final meters = (otherValue['total_distance'] as num)
                          .toDouble();
                      mileage = meters / 1000.0;
                      print(
                        '✅ Kilometraje encontrado en other.total_distance: $meters m -> $mileage km',
                      );
                    } else if (otherValue['odometer'] != null) {
                      final meters = (otherValue['odometer'] as num).toDouble();
                      mileage = meters / 1000.0;
                      print(
                        '✅ Kilometraje encontrado en other.odometer: $meters m -> $mileage km',
                      );
                    } else {
                      print(
                        '⚠️ No se encontró totaldistance en el objeto other',
                      );
                      print(
                        '🔍 Claves disponibles en other: ${otherValue.keys.toList()}',
                      );
                      // Intentar convertir a string y parsear como XML
                      final otherStr = otherValue.toString();
                      print(
                        '🔍 Intentando parsear como XML: ${otherStr.length > 200 ? '${otherStr.substring(0, 200)}...' : otherStr}',
                      );
                      mileage = extractMileage(otherStr);
                    }
                  } else {
                    // Otro tipo, intentar convertir a string
                    print(
                      '🔍 other es de tipo ${otherValue.runtimeType}, convirtiendo a string...',
                    );
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
        print(
          '❌❌❌ ERROR: Dispositivo con ID $gpsDeviceId NO encontrado en la lista de dispositivos GPS',
        );
        return Left(
          MaintenanceValidationFailure(
            'Dispositivo GPS con ID $gpsDeviceId no encontrado',
          ),
        );
      }

      if (mileage != null) {
        print(
          '✅✅✅ Kilometraje GPS obtenido exitosamente para dispositivo $gpsDeviceId: $mileage km',
        );
        print('✅✅✅ Retornando Right($mileage)');
        return Right(mileage);
      } else {
        print(
          '⚠️⚠️⚠️ Dispositivo $gpsDeviceId encontrado pero no tiene kilometraje disponible',
        );
        print('⚠️⚠️⚠️ Retornando Right(null)');
        return const Right(null);
      }
    } catch (e) {
      print('❌ Error al obtener kilometraje GPS: $e');
      return Left(
        MaintenanceUnknownFailure('Error al obtener kilometraje: $e'),
      );
    }
  }

  @override
  Future<Either<MaintenanceFailure, List<MaintenanceEntity>>>
  getPendingAlerts() async {
    try {
      // 1. Obtener todos los mantenimientos
      final maintenanceResponse = await _localApi.getMaintenance();

      final allMaintenance = maintenanceResponse
          .map((json) => MaintenanceModel.fromJson(json))
          .map((model) => model.toEntity())
          .where((m) => m.nextChangeKm != null || m.alertDate != null)
          .toList();

      if (allMaintenance.isEmpty) {
        return const Right([]);
      }

      // 2. Obtener los vehículos con su kilometraje actual
      final vehiclesResponse = await _localApi.getVehicles();

      // Crear un mapa de vehicle_id -> current_mileage
      final vehicleMileageMap = <String, double>{};
      for (var vehicle in vehiclesResponse) {
        if (vehicle['id'] != null && vehicle['current_mileage'] != null) {
          vehicleMileageMap[vehicle['id'] as String] =
              (vehicle['current_mileage'] as num).toDouble();
        }
      }

      // 3. Filtrar mantenimientos que están dentro del rango de alerta
      final now = DateTime.now();
      final alertThresholdKm = 2000.0; // 2000 km de antelación
      final alertThresholdDays = 30; // 30 días de antelación

      final pendingAlerts = <MaintenanceEntity>[];

      for (final maintenance in allMaintenance) {
        bool shouldAlert = false;

        // Verificar alerta por kilometraje
        if (maintenance.nextChangeKm != null) {
          final vehicleMileage = vehicleMileageMap[maintenance.vehicleId];
          if (vehicleMileage != null) {
            final kmRemaining = maintenance.nextChangeKm! - vehicleMileage;
            if (kmRemaining <= alertThresholdKm) {
              shouldAlert = true;
            }
          }
        }

        // Verificar alerta por fecha
        if (maintenance.alertDate != null) {
          final daysRemaining = maintenance.alertDate!.difference(now).inDays;
          if (daysRemaining <= alertThresholdDays) {
            shouldAlert = true;
          }
        }

        if (shouldAlert) {
          pendingAlerts.add(maintenance);
        }
      }

      return Right(pendingAlerts);
    } on SocketException catch (_) {
      return const Left(MaintenanceNetworkFailure());
    } catch (e) {
      return Left(MaintenanceUnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<MaintenanceFailure, int>> checkActiveAlerts() async {
    try {
      final currentUser = _localApi.currentUser;
      if (currentUser == null) {
        return const Left(
          MaintenanceValidationFailure('Usuario no autenticado'),
        );
      }

      // Obtener alertas pendientes
      final alertsResult = await getPendingAlerts();
      
      return alertsResult.fold(
        (failure) => Left(failure),
        (alerts) => Right(alerts.length),
      );
    } catch (e) {
      return Left(MaintenanceUnknownFailure(_mapGenericError(e)));
    }
  }

  String _mapGenericError(dynamic e) {
    return e.toString().isNotEmpty ? e.toString() : 'Error desconocido';
  }
}
