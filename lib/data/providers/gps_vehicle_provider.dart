import 'package:flutter/foundation.dart';
import 'package:pai_app/data/models/gps_device_model.dart';
import 'package:pai_app/data/services/gps_auth_service.dart';
import 'package:pai_app/data/services/vehicle_location_service.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';

/// Proveedor centralizado de vehículos GPS
/// Usa VehicleLocationService para obtener dispositivos (mismas credenciales que el mapa)
/// Esto asegura consistencia en cómo se cargan los vehículos en toda la app
class GPSVehicleProvider {
  static final GPSVehicleProvider _instance = GPSVehicleProvider._internal();
  factory GPSVehicleProvider() => _instance;
  GPSVehicleProvider._internal();

  final GPSAuthService _gpsAuthService = GPSAuthService();
  final VehicleLocationService _vehicleLocationService =
      VehicleLocationService();

  // Cache de vehículos para evitar llamadas repetidas
  List<VehicleEntity>? _cachedVehicles;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Obtiene los vehículos del GPS como VehicleEntity
  /// Usa VehicleLocationService (mismas credenciales que el mapa)
  /// Cache de 5 minutos para evitar llamadas excesivas
  Future<List<VehicleEntity>> getVehicles({bool forceRefresh = false}) async {
    debugPrint(
      '[GPSVehicleProvider] getVehicles llamado (forceRefresh: $forceRefresh)',
    );

    // Verificar cache (solo si tiene datos)
    if (!forceRefresh &&
        _cachedVehicles != null &&
        _cachedVehicles!.isNotEmpty &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      debugPrint(
        '[GPSVehicleProvider] Usando cache: ${_cachedVehicles!.length} vehículos',
      );
      return _cachedVehicles!;
    }

    try {
      debugPrint(
        '[GPSVehicleProvider] Obteniendo vehículos del GPS usando VehicleLocationService...',
      );

      // Usar VehicleLocationService que es el que funciona en el mapa
      final vehicleLocations = await _vehicleLocationService
          .getVehicleLocations();
      debugPrint(
        '[GPSVehicleProvider] VehicleLocationService retornó: ${vehicleLocations.length} vehículos',
      );

      if (vehicleLocations.isEmpty) {
        debugPrint(
          '[GPSVehicleProvider] ⚠️ No se obtuvieron vehículos - NO se guarda en cache',
        );
        return [];
      }

      // Convertir VehicleLocationEntity a VehicleEntity
      final vehicles = vehicleLocations.map((location) {
        return VehicleEntity(
          id: location.id,
          placa: location.plate, // plate viene del name del GPS
          marca: 'GPS',
          modelo: 'Sincronizado',
          ano: DateTime.now().year,
          gpsDeviceId: location.id,
        );
      }).toList();

      // Actualizar cache
      _cachedVehicles = vehicles;
      _cacheTime = DateTime.now();

      debugPrint(
        '[GPSVehicleProvider] ✅ ${vehicles.length} vehículos cargados:',
      );
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
