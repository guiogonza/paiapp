import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/auth_repository_impl.dart';
import 'package:pai_app/data/repositories/vehicle_history_repository_impl.dart';
import 'package:pai_app/data/services/vehicle_location_service.dart';
import 'package:pai_app/data/services/vehicle_history_service.dart';
import 'package:pai_app/data/services/gps_auth_service.dart';
import 'package:pai_app/domain/entities/vehicle_location_entity.dart';
import 'package:pai_app/presentation/pages/login/login_page.dart';
import 'package:pai_app/presentation/pages/vehicle_history/vehicle_history_page.dart';
import 'package:pai_app/presentation/pages/billing/billing_dashboard_page.dart';
import 'package:pai_app/presentation/pages/trips/trips_list_page.dart';
import 'package:pai_app/presentation/pages/expenses/expenses_page.dart';
import 'package:pai_app/presentation/pages/vehicles/vehicles_list_page.dart';
import 'package:pai_app/presentation/pages/documents/documents_management_page.dart';
import 'package:pai_app/presentation/pages/drivers/drivers_management_page.dart';
import 'package:pai_app/presentation/pages/maintenance/maintenance_page.dart';
import 'package:pai_app/data/services/fleet_sync_service.dart';
import 'package:pai_app/data/repositories/maintenance_repository_impl.dart';

class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  final _locationService = VehicleLocationService();
  final _historyService = VehicleHistoryService();
  final _historyRepository = VehicleHistoryRepositoryImpl();
  final _location = Location();
  final _gpsAuthService = GPSAuthService();
  final _fleetSyncService = FleetSyncService();
  final _maintenanceRepository = MaintenanceRepositoryImpl();
  bool _isSyncing = false;
  
  gmaps.GoogleMapController? _mapController;
  MapController? _flutterMapController;
  LocationData? _currentLocation;
  List<VehicleLocationEntity> _vehicleLocations = [];
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  Set<gmaps.Marker> _markers = {};
  List<Marker> _flutterMarkers = [];
  int _activeAlertsCount = 0; // Contador de alertas activas

  // Ubicación por defecto: Bogotá, Colombia
  static const gmaps.LatLng _defaultLocation = gmaps.LatLng(4.7110, -74.0721);
  static const latlng.LatLng _defaultLocationFlutter = latlng.LatLng(4.7110, -74.0721);

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _requestLocationPermission();
    } else {
      // En web, no se pueden solicitar permisos de ubicación
      // pero no mostramos error
      setState(() {
        _hasLocationPermission = false;
      });
    }
    _loadVehicleLocations();
    _checkActiveAlerts(); // Verificar alertas al iniciar
    if (kIsWeb) {
      _flutterMapController = MapController();
    }
  }

  /// Verifica alertas activas de mantenimiento
  Future<void> _checkActiveAlerts() async {
    final result = await _maintenanceRepository.checkActiveAlerts();
    result.fold(
      (failure) {
        // Silenciar errores, no bloquear el dashboard
        debugPrint('Error al verificar alertas: ${failure.message}');
      },
      (count) {
        if (mounted) {
          setState(() {
            _activeAlertsCount = count;
          });
          debugPrint('🔔 Alertas activas encontradas: $count');
        }
      },
    );
  }

  Future<void> _requestLocationPermission() async {
    try {
      // Verificar si ya tenemos permisos
      final serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        final serviceRequested = await _location.requestService();
        if (!serviceRequested) {
          setState(() {
            _hasLocationPermission = false;
          });
          return;
        }
      }

      // Solicitar permisos
      final permission = await Permission.location.request();
      if (permission.isGranted) {
        setState(() {
          _hasLocationPermission = true;
        });
        await _getCurrentLocation();
      } else {
        setState(() {
          _hasLocationPermission = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Se necesitan permisos de ubicación para mostrar tu posición'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al solicitar permisos: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationData = await _location.getLocation();
      setState(() {
        _currentLocation = locationData;
      });
      
      // Mover el mapa a la ubicación actual
      if (_mapController != null && _currentLocation != null) {
        _mapController!.animateCamera(
          gmaps.CameraUpdate.newLatLng(
            gmaps.LatLng(
              _currentLocation!.latitude!,
              _currentLocation!.longitude!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al obtener ubicación: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadVehicleLocations() async {
    setState(() {
      _isLoading = true;
    });

    // El servicio ahora retorna lista vacía en caso de error, no lanza excepciones
    print('🔄 Cargando ubicaciones de vehículos...');
    final locations = await _locationService.getVehicleLocations();
    print('✅ Ubicaciones cargadas: ${locations.length} vehículos');
    
    setState(() {
      _vehicleLocations = locations;
      _isLoading = false;
    });
    
    // Solo actualizar marcadores y centrar si hay vehículos
    if (locations.isNotEmpty) {
      _updateMarkers();
      _centerMapOnVehicles();
      
      // Cargar y guardar el historial de cada vehículo en segundo plano
      _loadAndSaveVehicleHistory(locations);
    } else {
      // Si no hay vehículos, simplemente no mostrar marcadores
      // La interfaz sigue siendo funcional (menú, botones, etc.)
      _updateMarkers(); // Esto limpiará los marcadores
    }
  }

  Widget _buildVehicleMarker(VehicleLocationEntity vehicle) {
    final timeStr = vehicle.timestamp != null
        ? '${vehicle.timestamp!.hour.toString().padLeft(2, '0')}:${vehicle.timestamp!.minute.toString().padLeft(2, '0')}'
        : '--:--';
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono del vehículo moderno
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.directions_car,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          // Placa
          Text(
            vehicle.plate,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          // Hora
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSyncFleet() async {
    setState(() {
      _isSyncing = true;
    });

    final result = await _fleetSyncService.syncFleetLimited();

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Sincronización completada'),
          backgroundColor: result['success'] == true ? Colors.green : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );

      // Si se sincronizaron vehículos, recargar ubicaciones
      if (result['success'] == true && result['synced'] > 0) {
        _loadVehicleLocations();
      }
    }
  }

  /// Construye una tarjeta de módulo con diseño moderno tipo mockups
  Widget _buildModuleCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateMarkers() {
    if (kIsWeb) {
      // Usar flutter_map markers para web
      final markers = <Marker>[];

      // Agregar marcador de ubicación actual si está disponible
      if (_currentLocation != null) {
        markers.add(
          Marker(
            point: latlng.LatLng(
              _currentLocation!.latitude!,
              _currentLocation!.longitude!,
            ),
            width: 40,
            height: 40,
            child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
          ),
        );
      }

      // Agregar marcadores de vehículos con diseño moderno
      for (final vehicle in _vehicleLocations) {
        markers.add(
          Marker(
            point: latlng.LatLng(vehicle.lat, vehicle.lng),
            width: 80,
            height: 80,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VehicleHistoryPage(
                      vehicleId: vehicle.id,
                      vehiclePlate: vehicle.plate,
                    ),
                  ),
                );
              },
              child: _buildVehicleMarker(vehicle),
            ),
          ),
        );
      }

      setState(() {
        _flutterMarkers = markers;
      });
    } else {
      // Usar Google Maps markers para móvil
      final markers = <gmaps.Marker>{};

      // Agregar marcador de ubicación actual si está disponible
      if (_currentLocation != null) {
        markers.add(
          gmaps.Marker(
            markerId: const gmaps.MarkerId('current_location'),
            position: gmaps.LatLng(
              _currentLocation!.latitude!,
              _currentLocation!.longitude!,
            ),
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueBlue),
            infoWindow: const gmaps.InfoWindow(
              title: 'Mi Ubicación',
              snippet: 'Tu posición actual',
            ),
          ),
        );
      }

      // Agregar marcadores de vehículos
      for (final vehicle in _vehicleLocations) {
        final timeStr = vehicle.timestamp != null
            ? '${vehicle.timestamp!.hour.toString().padLeft(2, '0')}:${vehicle.timestamp!.minute.toString().padLeft(2, '0')}'
            : '--:--';
        
        markers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId(vehicle.id),
            position: gmaps.LatLng(vehicle.lat, vehicle.lng),
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
            infoWindow: gmaps.InfoWindow(
              title: 'Vehículo ${vehicle.plate}',
              snippet: 'Último reporte: $timeStr${vehicle.speed != null ? '\nVelocidad: ${vehicle.speed!.toStringAsFixed(1)} km/h' : ''}\nToca para ver historial',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VehicleHistoryPage(
                    vehicleId: vehicle.id,
                    vehiclePlate: vehicle.plate,
                  ),
                ),
              );
            },
          ),
        );
      }

      setState(() {
        _markers = markers;
      });
    }
  }

  void _onMapCreated(gmaps.GoogleMapController controller) {
    _mapController = controller;
    _updateMarkers();
    _centerMapOnVehicles();
  }

  latlng.LatLng _calculateCenter() {
    if (_vehicleLocations.isEmpty) return _defaultLocationFlutter;
    
    double avgLat = 0;
    double avgLng = 0;
    for (var vehicle in _vehicleLocations) {
      avgLat += vehicle.lat;
      avgLng += vehicle.lng;
    }
    avgLat /= _vehicleLocations.length;
    avgLng /= _vehicleLocations.length;
    
    return latlng.LatLng(avgLat, avgLng);
  }

  gmaps.LatLng _calculateGoogleMapsCenter() {
    if (_vehicleLocations.isEmpty) return _defaultLocation;
    
    double avgLat = 0;
    double avgLng = 0;
    for (var vehicle in _vehicleLocations) {
      avgLat += vehicle.lat;
      avgLng += vehicle.lng;
    }
    avgLat /= _vehicleLocations.length;
    avgLng /= _vehicleLocations.length;
    
    return gmaps.LatLng(avgLat, avgLng);
  }

  void _centerMapOnVehicles() {
    if (_vehicleLocations.isEmpty) return;

    if (kIsWeb) {
      final center = _calculateCenter();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _flutterMapController != null) {
          try {
            _flutterMapController!.move(
              center,
              8.0, // Zoom amplio
            );
          } catch (e) {
            // Ignorar errores
          }
        }
      });
    } else {
      // Calcular bounds para Google Maps
      double minLat = _vehicleLocations.first.lat;
      double maxLat = _vehicleLocations.first.lat;
      double minLng = _vehicleLocations.first.lng;
      double maxLng = _vehicleLocations.first.lng;

      for (var vehicle in _vehicleLocations) {
        if (vehicle.lat < minLat) minLat = vehicle.lat;
        if (vehicle.lat > maxLat) maxLat = vehicle.lat;
        if (vehicle.lng < minLng) minLng = vehicle.lng;
        if (vehicle.lng > maxLng) maxLng = vehicle.lng;
      }

      _mapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngBounds(
          gmaps.LatLngBounds(
            southwest: gmaps.LatLng(minLat, minLng),
            northeast: gmaps.LatLng(maxLat, maxLng),
          ),
          100, // padding
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Principal'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Icono de notificación de alertas (rojo si hay alertas activas)
          if (_activeAlertsCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () {
                    // Navegar a la página de alertas
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MaintenancePage(),
                      ),
                    ).then((_) {
                      // Recargar alertas al volver
                      _checkActiveAlerts();
                    });
                  },
                  tooltip: 'Tienes $_activeAlertsCount alertas de mantenimiento',
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _activeAlertsCount > 9 ? '9+' : '$_activeAlertsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          // Botón temporal de debug GPS
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: () async {
              print('🔍 Iniciando debug GPS JSON...');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ejecutando debug GPS... Revisa la consola del navegador (F12)'),
                  duration: Duration(seconds: 3),
                ),
              );
              await _gpsAuthService.debugGpsStructure();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Debug completado. Revisa la consola (F12 → Console)'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            tooltip: 'TEST GPS JSON (Debug)',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadVehicleLocations();
              _checkActiveAlerts(); // Recargar alertas al actualizar
            },
            tooltip: 'Actualizar ubicaciones',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authRepository = AuthRepositoryImpl();
              await authRepository.logout();
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Stack(
              children: [
                // Usar flutter_map para web, Google Maps para móvil
                kIsWeb
                    ? FlutterMap(
                        mapController: _flutterMapController,
                        options: MapOptions(
                          initialCenter: _vehicleLocations.isNotEmpty
                              ? _calculateCenter()
                              : _defaultLocationFlutter,
                          initialZoom: 8.0, // Zoom más amplio para ver todos los vehículos
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.pai_app',
                          ),
                          MarkerLayer(
                            markers: _flutterMarkers,
                          ),
                        ],
                      )
                    : gmaps.GoogleMap(
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: gmaps.CameraPosition(
                              target: _vehicleLocations.isNotEmpty
                                  ? _calculateGoogleMapsCenter()
                                  : _defaultLocation,
                              zoom: 8.0, // Zoom más amplio para ver todos los vehículos
                            ),
                        markers: _markers,
                        myLocationEnabled: _hasLocationPermission,
                        myLocationButtonEnabled: _hasLocationPermission,
                        mapType: gmaps.MapType.normal,
                        zoomControlsEnabled: true,
                        zoomGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                      ),
                // Banner de alertas activas
                if (_activeAlertsCount > 0)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.red,
                      child: InkWell(
                        onTap: () {
                          // Navegar a la página de alertas
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MaintenancePage(),
                            ),
                          ).then((_) {
                            // Recargar alertas al volver
                            _checkActiveAlerts();
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade700, width: 2),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Tienes $_activeAlertsCount mantenimiento${_activeAlertsCount > 1 ? 's' : ''} pendiente${_activeAlertsCount > 1 ? 's' : ''} o que requieren pre-aviso',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // Panel de información mejorado - Scrolleable
                Positioned(
                  top: _activeAlertsCount > 0 ? 80 : 16, // Ajustar posición si hay banner
                  left: 16,
                  right: 16,
                  bottom: 80, // Espacio para el FAB
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header con vehículos en ruta
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.royalBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.directions_car,
                                  color: AppColors.royalBlue,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Vehículos en ruta: ${_vehicleLocations.length}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  // Mostrar lista de vehículos para ver historial
                                  showModalBottomSheet(
                                    context: context,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                    ),
                                    builder: (context) => Container(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 4,
                                            margin: const EdgeInsets.only(bottom: 16),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[300],
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          const Text(
                                            'Ver historial de vehículo',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          ..._vehicleLocations.map((vehicle) {
                                            final timeStr = vehicle.timestamp != null
                                                ? '${vehicle.timestamp!.hour.toString().padLeft(2, '0')}:${vehicle.timestamp!.minute.toString().padLeft(2, '0')}'
                                                : '--:--';
                                            return ListTile(
                                              leading: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: AppColors.royalBlue.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.directions_car,
                                                  color: AppColors.royalBlue,
                                                  size: 20,
                                                ),
                                              ),
                                              title: Text(
                                                vehicle.plate,
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                              subtitle: Text('Último reporte: $timeStr'),
                                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                              onTap: () {
                                                Navigator.pop(context);
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => VehicleHistoryPage(
                                                      vehicleId: vehicle.id,
                                                      vehiclePlate: vehicle.plate,
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.history, size: 18),
                                label: const Text('Ver historiales'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.royalBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Sección de Módulos
                          const Text(
                            'Módulos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Botones de módulos en grid - Diseño moderno tipo mockups
                          GridView.count(
                            crossAxisCount: 3, // 3 columnas
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.0, // Más compacto
                            children: [
                              // Vehículos
                              _buildModuleCard(
                                context,
                                icon: Icons.directions_car,
                                label: 'Vehículos',
                                color: AppColors.royalBlue,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const VehiclesListPage(),
                                    ),
                                  );
                                },
                              ),
                              // Conductores
                              _buildModuleCard(
                                context,
                                icon: Icons.people,
                                label: 'Conductores',
                                color: AppColors.royalBlue,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const DriversManagementPage(),
                                    ),
                                  );
                                },
                              ),
                              // Viajes
                              _buildModuleCard(
                                context,
                                icon: Icons.route,
                                label: 'Viajes',
                                color: AppColors.royalBlue,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const TripsListPage(),
                                    ),
                                  );
                                },
                              ),
                              // Cobranza
                              _buildModuleCard(
                                context,
                                icon: Icons.payment,
                                label: 'Cobranza',
                                color: AppColors.orangeAccent,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const BillingDashboardPage(),
                                    ),
                                  );
                                },
                              ),
                              // Gastos
                              _buildModuleCard(
                                context,
                                icon: Icons.receipt,
                                label: 'Gastos',
                                color: AppColors.orangeAccent,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const ExpensesPage(),
                                    ),
                                  );
                                },
                              ),
                              // Documentos
                              _buildModuleCard(
                                context,
                                icon: Icons.description,
                                label: 'Documentos',
                                color: AppColors.royalBlue,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const DocumentsManagementPage(),
                                    ),
                                  );
                                },
                              ),
                              // Mantenimiento
                              _buildModuleCard(
                                context,
                                icon: Icons.build,
                                label: 'Mantenimiento',
                                color: AppColors.darkGray,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const MaintenancePage(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          if (!_hasLocationPermission && !kIsWeb) ...[
                            const SizedBox(height: 8),
                            const Text(
                              '⚠ Permisos de ubicación no concedidos',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón de sincronización de flota
          FloatingActionButton.extended(
            onPressed: _isSyncing ? null : _handleSyncFleet,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.sync),
            label: Text(_isSyncing ? 'Sincronizando...' : 'Sync Flota (Test)'),
            backgroundColor: Colors.green,
            heroTag: 'sync_fleet',
          ),
          const SizedBox(height: 8),
          // Botón de ubicación actual
          if (kIsWeb)
            FloatingActionButton(
              onPressed: () {
                if (_currentLocation != null && _flutterMapController != null) {
                  _flutterMapController!.move(
                    latlng.LatLng(
                      _currentLocation!.latitude!,
                      _currentLocation!.longitude!,
                    ),
                    14.0,
                  );
                }
              },
              tooltip: 'Ir a mi ubicación',
              child: const Icon(Icons.my_location),
              heroTag: 'my_location',
            )
          else if (_hasLocationPermission)
            FloatingActionButton(
              onPressed: _getCurrentLocation,
              tooltip: 'Ir a mi ubicación',
              child: const Icon(Icons.my_location),
              heroTag: 'my_location',
            ),
        ],
      ),
    );
  }

  /// Carga y guarda el historial de cada vehículo en segundo plano
  Future<void> _loadAndSaveVehicleHistory(List<VehicleLocationEntity> vehicles) async {
    // Obtener historial de las últimas 24 horas para cada vehículo
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    for (var vehicle in vehicles) {
      try {
        print('📊 Cargando historial para vehículo ${vehicle.plate} (${vehicle.id})...');
        
        // Obtener historial del API
        final history = await _historyService.getVehicleHistory(
          vehicle.id,
          vehicle.plate,
          from: yesterday,
          to: now,
        );

        if (history.isNotEmpty) {
          print('✅ Historial obtenido: ${history.length} puntos para ${vehicle.plate}');
          
          // Guardar en Supabase
          final result = await _historyRepository.saveVehicleHistory(history);
          result.fold(
            (failure) {
              print('❌ Error al guardar historial de ${vehicle.plate}: ${failure.message}');
            },
            (_) {
              print('✅ Historial guardado exitosamente para ${vehicle.plate}');
            },
          );
        } else {
          print('⚠️ No hay historial disponible para ${vehicle.plate}');
        }
      } catch (e) {
        print('❌ Error al cargar historial de ${vehicle.plate}: ${e.toString()}');
        // Continuar con el siguiente vehículo aunque falle uno
      }
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

