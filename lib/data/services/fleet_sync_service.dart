import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/data/services/gps_auth_service.dart';

/// Servicio para sincronizar la flota desde el API de GPS a Supabase
class FleetSyncService {
  final GPSAuthService _gpsAuthService = GPSAuthService();
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _devicesUrl =
      'https://plataforma.sistemagps.online/api/get_devices';
  static const String _tableName = 'vehicles';

  /// Sincroniza los primeros 5 dispositivos del API de GPS a la base de datos
  /// Busca por placa (name) y hace upsert (update si existe, insert si no)
  Future<Map<String, dynamic>> syncFleetLimited() async {
    try {
      print(
        '🔄 Iniciando sincronización de flota (primeros 5 dispositivos)...',
      );

      // Paso 1: Autenticación con credenciales del usuario
      final credentials = await _gpsAuthService.getGpsCredentialsLocally();
      if (credentials == null) {
        return {
          'success': false,
          'message':
              'No hay credenciales GPS configuradas. Inicia sesión primero.',
          'synced': 0,
        };
      }

      final apiKey = await _gpsAuthService.login(
        credentials['email']!,
        credentials['password']!,
      );
      if (apiKey == null || apiKey.isEmpty) {
        return {
          'success': false,
          'message': 'Error al autenticar con el API de GPS',
          'synced': 0,
        };
      }

      print('✅ Autenticación exitosa');

      // Paso 2: Obtener dispositivos
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
        return {
          'success': false,
          'message': 'Error al obtener dispositivos: ${response.statusCode}',
          'synced': 0,
        };
      }

      // Paso 3: Parsear respuesta y tomar primeros 5
      final devicesData = json.decode(response.body);
      final List<dynamic> allDevices = [];

      if (devicesData is List) {
        for (var group in devicesData) {
          if (group is Map && group['items'] != null) {
            final items = group['items'] as List;
            allDevices.addAll(items);
          }
        }
      }

      // Tomar solo los primeros 5
      final devicesToSync = allDevices.take(5).toList();
      print('📦 Dispositivos a sincronizar: ${devicesToSync.length}');

      // Paso 4: Obtener el ID del usuario actual
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
          'synced': 0,
        };
      }
      final ownerId = currentUser.id;
      print('👤 Owner ID: $ownerId');

      // Paso 5: Upsert para cada dispositivo
      int synced = 0;
      int updated = 0;
      int created = 0;
      final errors = <String>[];

      for (var device in devicesToSync) {
        try {
          final deviceId = device['id']?.toString() ?? '';
          final deviceName =
              device['name']?.toString() ??
              device['label']?.toString() ??
              device['alias']?.toString() ??
              device['plate']?.toString() ??
              'Sin nombre';

          // Extraer odómetro (puede estar en diferentes campos)
          double? odometer;
          if (device['odometer'] != null) {
            odometer =
                (device['odometer'] as num).toDouble() / 1000; // Convertir a km
          } else if (device['totalDistance'] != null) {
            odometer = (device['totalDistance'] as num).toDouble() / 1000;
          } else if (device['total_distance'] != null) {
            odometer = (device['total_distance'] as num).toDouble() / 1000;
          }

          print('🚗 Procesando: $deviceName (ID GPS: $deviceId)');

          // Buscar vehículo existente por placa
          final existingVehicles = await _supabase
              .from(_tableName)
              .select('id')
              .eq('plate', deviceName)
              .limit(1);

          if (existingVehicles.isNotEmpty) {
            // Actualizar vehículo existente
            final vehicleId = existingVehicles[0]['id'] as String;
            await _supabase
                .from(_tableName)
                .update({
                  'gps_device_id': deviceId,
                  if (odometer != null) 'current_mileage': odometer,
                })
                .eq('id', vehicleId);

            print('   ✅ Actualizado: $deviceName');
            updated++;
          } else {
            // Crear nuevo vehículo
            await _supabase.from(_tableName).insert({
              'plate': deviceName,
              'brand': 'GPS', // Valor por defecto
              'model': 'Sincronizado',
              'year': DateTime.now().year,
              'gps_device_id': deviceId,
              'owner_id': ownerId,
              if (odometer != null) 'current_mileage': odometer,
            });

            print('   ✅ Creado: $deviceName');
            created++;
          }

          synced++;
        } catch (e) {
          final errorMsg =
              'Error al sincronizar ${device['name'] ?? 'desconocido'}: $e';
          print('   ❌ $errorMsg');
          errors.add(errorMsg);
        }
      }

      return {
        'success': true,
        'message':
            'Sincronización completada: $synced dispositivos procesados ($created creados, $updated actualizados)',
        'synced': synced,
        'created': created,
        'updated': updated,
        'errors': errors,
      };
    } catch (e, stackTrace) {
      print('❌ Error en syncFleetLimited: $e');
      print('   Stack trace: $stackTrace');
      return {'success': false, 'message': 'Error inesperado: $e', 'synced': 0};
    }
  }
}
