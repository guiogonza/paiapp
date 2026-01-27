import 'package:flutter/foundation.dart';
import 'package:pai_app/data/models/gps_device_model.dart';
import 'package:pai_app/data/services/gps_auth_service.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';

/// Proveedor centralizado de vehículos GPS
/// Usa GPSAuthService para obtener dispositivos y los convierte a VehicleEntity
/// Esto asegura consistencia en cómo se mapean las placas en toda la app
class GPSVehicleProvider {
  static final GPSVehicleProvider _instance = GPSVehicleProvider._internal();
  factory GPSVehicleProvider() => _instance;
  GPSVehicleProvider._internal();

  final GPSAuthService _gpsAuthService = GPSAuthService();

  // Cache de vehículos para evitar llamadas repetidas
  List<VehicleEntity>? _cachedVehicles;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Obtiene los vehículos del GPS como VehicleEntity
  /// Usa cache de 5 minutos para evitar llamadas excesivas
  Future<List<VehicleEntity>> getVehicles({bool forceRefresh = false}) async {
    // Verificar cache
    if (!forceRefresh &&
        _cachedVehicles != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      debugPrint(
        '[GPSVehicleProvider] Usando cache: ${_cachedVehicles!.length} vehículos',
      );
      return _cachedVehicles!;
    }

    try {
      debugPrint('[GPSVehicleProvider] Obteniendo vehículos del GPS...');
      final gpsDevices = await _gpsAuthService.getDevicesFromGPS();

      if (gpsDevices.isEmpty) {
        debugPrint(
          '[GPSVehicleProvider] No se obtuvieron dispositivos del GPS',
        );
        return [];
      }

      // Convertir a modelos tipados
      final devices = gpsDevices
          .map((d) => GPSDeviceModel.fromJson(d))
          .toList();

      // Log de estructura del primer dispositivo para debug
      if (gpsDevices.isNotEmpty) {
        debugPrint('[GPSVehicleProvider] Estructura del primer dispositivo:');
        final first = gpsDevices.first;
        first.forEach((key, value) {
          debugPrint('  $key: $value (${value.runtimeType})');
        });
      }

      // Convertir a VehicleEntity
      final vehicles = devices.map((device) {
        return VehicleEntity(
          id: device.id,
          placa: device.placa, // Usa la lógica del modelo: name > label > plate
          marca: 'GPS',
          modelo: 'Sincronizado',
          ano: DateTime.now().year,
          gpsDeviceId: device.id,
        );
      }).toList();

      // Actualizar cache
      _cachedVehicles = vehicles;
      _cacheTime = DateTime.now();

      debugPrint('[GPSVehicleProvider] ${vehicles.length} vehículos cargados:');
      for (var v in vehicles.take(5)) {
        debugPrint('  - ${v.placa} (ID: ${v.id})');
      }
      if (vehicles.length > 5) {
        debugPrint('  ... y ${vehicles.length - 5} más');
      }

      return vehicles;
    } catch (e, stackTrace) {
      debugPrint('[GPSVehicleProvider] Error: $e');
      debugPrint('[GPSVehicleProvider] Stack: $stackTrace');
      return [];
    }
  }

  /// Limpia el cache para forzar recarga en la próxima llamada
  void clearCache() {
    _cachedVehicles = null;
    _cacheTime = null;
    debugPrint('[GPSVehicleProvider] Cache limpiado');
  }

  /// Obtiene los dispositivos GPS como modelos tipados (para uso avanzado)
  Future<List<GPSDeviceModel>> getDeviceModels({
    bool forceRefresh = false,
  }) async {
    try {
      final gpsDevices = await _gpsAuthService.getDevicesFromGPS();
      return gpsDevices.map((d) => GPSDeviceModel.fromJson(d)).toList();
    } catch (e) {
      debugPrint('[GPSVehicleProvider] Error obteniendo modelos: $e');
      return [];
    }
  }
}
