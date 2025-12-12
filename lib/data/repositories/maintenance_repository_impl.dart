import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
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

  @override
  Future<Either<MaintenanceFailure, List<MaintenanceEntity>>> getHistory(String vehicleId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('vehicle_id', vehicleId)
          .order('date', ascending: false);

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
    double newMileage,
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
      print('📝 Nuevo kilometraje: $newMileage km');

      // Transacción: Insertar mantenimiento y actualizar kilometraje
      // Nota: Supabase no soporta transacciones reales, pero hacemos ambas operaciones
      
      // 1. Insertar mantenimiento
      final maintenanceResponse = await _supabase
          .from(_tableName)
          .insert(maintenanceData)
          .select()
          .single();

      print('✅ Mantenimiento registrado: ${maintenanceResponse['id']}');

      // 2. Actualizar kilometraje del vehículo
      await _supabase
          .from(_vehiclesTableName)
          .update({'current_mileage': newMileage})
          .eq('id', maintenance.vehicleId);

      print('✅ Kilometraje actualizado: $newMileage km');

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
      print('🔍 Obteniendo kilometraje GPS para dispositivo: $gpsDeviceId');
      
      // Autenticación
      final email = 'luisr@rastrear.com';
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

      // Buscar el dispositivo específico
      final devicesData = json.decode(response.body);
      double? mileage;

      if (devicesData is List) {
        for (var group in devicesData) {
          if (group is Map && group['items'] != null) {
            final items = group['items'] as List;
            for (var device in items) {
              final deviceId = device['id']?.toString() ?? '';
              if (deviceId == gpsDeviceId) {
                // Buscar odómetro en diferentes campos
                if (device['odometer'] != null) {
                  mileage = (device['odometer'] as num).toDouble() / 1000; // Convertir a km
                } else if (device['totalDistance'] != null) {
                  mileage = (device['totalDistance'] as num).toDouble() / 1000;
                } else if (device['total_distance'] != null) {
                  mileage = (device['total_distance'] as num).toDouble() / 1000;
                } else if (device['other'] != null) {
                  // Intentar parsear XML en el campo 'other'
                  final otherStr = device['other'].toString();
                  final totalDistanceMatch = RegExp(r'<totaldistance>([0-9.]+)</totaldistance>', caseSensitive: false)
                      .firstMatch(otherStr);
                  if (totalDistanceMatch != null) {
                    final distanceValue = double.tryParse(totalDistanceMatch.group(1) ?? '') ?? 0.0;
                    mileage = distanceValue / 1000; // Convertir a km
                  }
                }
                break;
              }
            }
          }
        }
      }

      if (mileage != null) {
        print('✅ Kilometraje GPS obtenido: $mileage km');
        return Right(mileage);
      } else {
        print('⚠️ No se encontró kilometraje para el dispositivo $gpsDeviceId');
        return const Right(null);
      }
    } catch (e) {
      print('❌ Error al obtener kilometraje GPS: $e');
      return Left(MaintenanceUnknownFailure('Error al obtener kilometraje: $e'));
    }
  }

  String _mapPostgrestError(PostgrestException e) {
    return e.message;
  }

  String _mapGenericError(dynamic e) {
    return e.toString().isNotEmpty ? e.toString() : 'Error desconocido';
  }
}

