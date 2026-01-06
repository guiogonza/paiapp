import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/auth_repository_impl.dart';
import 'package:pai_app/data/services/vehicle_location_service.dart';
import 'package:pai_app/domain/entities/vehicle_location_entity.dart';
import 'package:pai_app/presentation/pages/login/login_page.dart';
import 'package:pai_app/presentation/pages/vehicle_history/vehicle_history_page.dart';
import 'package:pai_app/presentation/pages/billing/billing_dashboard_page.dart';
import 'package:pai_app/presentation/pages/trips/trips_list_page.dart';
import 'package:pai_app/presentation/pages/expenses/expenses_page.dart';
import 'package:pai_app/presentation/pages/documents/documents_management_page.dart';
import 'package:pai_app/presentation/pages/drivers/drivers_management_page.dart';
import 'package:pai_app/presentation/pages/maintenance/maintenance_page.dart';
import 'package:pai_app/data/repositories/maintenance_repository_impl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/data/repositories/trip_repository_impl.dart';
import 'package:pai_app/data/repositories/expense_repository_impl.dart';
import 'package:pai_app/data/repositories/remittance_repository_impl.dart';
import 'package:pai_app/presentation/pages/fleet_monitoring/fleet_monitoring_page.dart';
import 'package:pai_app/data/repositories/document_repository_impl.dart';
import 'package:pai_app/data/repositories/profile_repository_impl.dart';
import 'package:pai_app/presentation/pages/super_admin/super_admin_dashboard_page.dart';

class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  final _locationService = VehicleLocationService();
  final _maintenanceRepository = MaintenanceRepositoryImpl();
  final _profileRepository = ProfileRepositoryImpl();
  List<VehicleLocationEntity> _vehicleLocations = [];
  String? _userRole; // Role del usuario actual
  int _activeAlertsCount = 0; // Contador de alertas activas
  double _currentMonthRevenue = 0.0;
  double _currentMonthExpenses = 0.0; // Gastos de viajes
  double _currentMonthMaintenanceExpenses = 0.0; // Gastos de mantenimiento
  int _activeTripsCount = 0; // Viajes activos (en ruta)
  int _pendingRemittancesCount = 0; // Remisiones pendientes de cobro
  int _expiredDocumentsCount = 0; // Documentos vencidos
  
  // Controllers para mapas
  gmaps.GoogleMapController? _mapController;
  MapController? _flutterMapController;
  Set<gmaps.Marker> _markers = {};
  List<Marker> _flutterMarkers = [];
  
  // Ubicación por defecto: Bogotá, Colombia
  static const gmaps.LatLng _defaultLocation = gmaps.LatLng(4.7110, -74.0721);
  static const latlng.LatLng _defaultLocationFlutter = latlng.LatLng(4.7110, -74.0721);

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _flutterMapController = MapController();
    }
    _loadUserRole(); // Cargar role del usuario
    _loadVehicleLocations();
    _checkActiveAlerts(); // Verificar alertas al iniciar
    _loadFinancialKpi(); // Cargar KPI financiero
    _loadOperationalKpis(); // Cargar KPIs operativos
    _loadDocumentAlerts(); // Cargar alertas de documentos
  }

  /// Carga el role del usuario actual
  Future<void> _loadUserRole() async {
    final result = await _profileRepository.getCurrentUserProfile();
    result.fold(
      (failure) => debugPrint('Error al cargar perfil: ${failure.message}'),
      (profile) {
        if (mounted) {
          setState(() {
            _userRole = profile.role;
          });
        }
      },
    );
  }

  /// Carga los KPIs operativos (viajes activos y remisiones pendientes)
  Future<void> _loadOperationalKpis() async {
    try {
      final tripRepository = TripRepositoryImpl();
      final remittanceRepository = RemittanceRepositoryImpl();

      // Obtener viajes activos (viajes que han iniciado pero no han terminado)
      final tripsResult = await tripRepository.getTrips();
      tripsResult.fold(
        (failure) => debugPrint('Error al cargar viajes: ${failure.message}'),
        (trips) {
          final now = DateTime.now();
          int activeCount = 0;
          for (var trip in trips) {
            // Un viaje está activo si tiene startDate pero no tiene endDate, o si endDate es futuro
            if (trip.startDate != null) {
              if (trip.endDate == null || trip.endDate!.isAfter(now)) {
                activeCount++;
              }
            }
          }
          if (mounted) {
            setState(() {
              _activeTripsCount = activeCount;
            });
          }
        },
      );

      // Obtener remisiones pendientes (todas las que no están cobradas)
      final remittancesResult = await remittanceRepository.getPendingRemittancesWithRoutes();
      remittancesResult.fold(
        (failure) => debugPrint('Error al cargar remisiones: ${failure.message}'),
        (remittances) {
          if (mounted) {
            setState(() {
              _pendingRemittancesCount = remittances.length;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error al cargar KPIs operativos: $e');
    }
  }

  /// Carga las alertas de documentos vencidos
  Future<void> _loadDocumentAlerts() async {
    try {
      final documentRepository = DocumentRepositoryImpl();
      final documentsResult = await documentRepository.getDocuments();
      
      documentsResult.fold(
        (failure) {
          debugPrint('Error al cargar documentos: ${failure.message}');
          if (mounted) {
            setState(() {
              _expiredDocumentsCount = 0;
            });
          }
        },
        (documents) {
          final now = DateTime.now();
          // Normalizar la fecha actual para comparar solo fechas (sin hora)
          final today = DateTime(now.year, now.month, now.day);
          
          int expiredCount = 0;
          for (var document in documents) {
            // Normalizar la fecha de expiración para comparar solo fechas
            final expirationDate = DateTime(
              document.expirationDate.year,
              document.expirationDate.month,
              document.expirationDate.day,
            );
            
            // Un documento está vencido si su fecha de expiración es anterior a hoy
            if (expirationDate.isBefore(today)) {
              expiredCount++;
            }
          }
          
          if (mounted) {
            setState(() {
              _expiredDocumentsCount = expiredCount;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error al cargar alertas de documentos: $e');
      if (mounted) {
        setState(() {
          _expiredDocumentsCount = 0;
        });
      }
    }
  }

  /// Carga el KPI financiero (ingresos y gastos del mes actual)
  Future<void> _loadFinancialKpi() async {
    try {
      final tripRepository = TripRepositoryImpl();
      final expenseRepository = ExpenseRepositoryImpl();
      
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Obtener ingresos del mes (viajes cobrados)
      final tripsResult = await tripRepository.getTrips();
      tripsResult.fold(
        (failure) => debugPrint('Error al cargar viajes: ${failure.message}'),
        (trips) {
          double revenue = 0.0;
          for (var trip in trips) {
            // Obtener el revenueAmount directamente del trip
            if (trip.revenueAmount > 0) {
              final tripDate = trip.startDate;
              if (tripDate != null &&
                  tripDate.isAfter(firstDayOfMonth) &&
                  tripDate.isBefore(lastDayOfMonth)) {
                revenue += trip.revenueAmount;
              }
            }
          }
          if (mounted) {
            setState(() {
              _currentMonthRevenue = revenue;
            });
          }
        },
      );

      // Obtener gastos de viajes del mes
      final expensesResult = await expenseRepository.getExpenses();
      expensesResult.fold(
        (failure) => debugPrint('Error al cargar gastos: ${failure.message}'),
        (expenses) {
          double totalExpenses = 0.0;
          for (var expense in expenses) {
            if (expense.date.isAfter(firstDayOfMonth) &&
                expense.date.isBefore(lastDayOfMonth)) {
              totalExpenses += expense.amount;
            }
          }
          if (mounted) {
            setState(() {
              _currentMonthExpenses = totalExpenses;
            });
          }
        },
      );

      // Obtener gastos de mantenimiento del mes
      final maintenanceResult = await _maintenanceRepository.getAllMaintenance();
      maintenanceResult.fold(
        (failure) => debugPrint('Error al cargar mantenimientos: ${failure.message}'),
        (maintenanceList) {
          double totalMaintenanceExpenses = 0.0;
          for (var maintenance in maintenanceList) {
            // Filtrar por fecha de servicio del mes actual
            if (maintenance.serviceDate.isAfter(firstDayOfMonth) &&
                maintenance.serviceDate.isBefore(lastDayOfMonth)) {
              totalMaintenanceExpenses += maintenance.cost;
            }
          }
          if (mounted) {
            setState(() {
              _currentMonthMaintenanceExpenses = totalMaintenanceExpenses;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error al cargar KPI financiero: $e');
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


  Future<void> _loadVehicleLocations() async {
    // El servicio ahora retorna lista vacía en caso de error, no lanza excepciones
    debugPrint('🔄 Cargando ubicaciones de vehículos...');
    final locations = await _locationService.getVehicleLocations();
    debugPrint('✅ Ubicaciones cargadas: ${locations.length} vehículos');
    
    if (mounted) {
      setState(() {
        _vehicleLocations = locations;
      });
      
      if (locations.isNotEmpty) {
        _updateMarkers();
        _centerMapOnVehicles();
      }
    }
  }

  void _updateMarkers() {
    if (kIsWeb) {
      final markers = <Marker>[];
      for (final vehicle in _vehicleLocations) {
        markers.add(
          Marker(
            point: latlng.LatLng(vehicle.lat, vehicle.lng),
            width: 60,
            height: 60,
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
      final markers = <gmaps.Marker>{};
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
              snippet: 'Último reporte: $timeStr',
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

  Widget _buildVehicleMarker(VehicleLocationEntity vehicle) {
    final timeStr = vehicle.timestamp != null
        ? '${vehicle.timestamp!.hour.toString().padLeft(2, '0')}:${vehicle.timestamp!.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.directions_car,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            vehicle.plate,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 7,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _centerMapOnVehicles() {
    if (_vehicleLocations.isEmpty) return;

    if (kIsWeb) {
      final center = _calculateCenter();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _flutterMapController != null) {
          try {
            _flutterMapController!.move(center, 8.0);
          } catch (e) {
            debugPrint('Error al centrar mapa: $e');
          }
        }
      });
    } else {
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
          100,
        ),
      );
    }
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

  void _onMapCreated(gmaps.GoogleMapController controller) {
    _mapController = controller;
    _updateMarkers();
    _centerMapOnVehicles();
  }


  /// Construye el isotipo PAI (logo geométrico)
  Widget _buildPaiIsotype() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'assets/images/ppai_isotipo.jpg',
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback si la imagen no existe
            debugPrint('Error cargando isotipo: $error');
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.image_not_supported,
                size: 20,
                color: AppColors.white,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Construye un chip de estado
  Widget _buildStatusChip({
    required Color color,
    required String label,
    required String value,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: compact ? 1.0 : 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 8,
            height: compact ? 6 : 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = (user?.email ?? 'PAI').split('@').first;

    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);

    final totalExpenses = _currentMonthExpenses + _currentMonthMaintenanceExpenses;
    final balance = _currentMonthRevenue - totalExpenses;
    
    // Formateador de números con separador de miles (punto)
    final numberFormat = NumberFormat('#,###', 'es_CO');

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Estructura principal: Column vertical
            Column(
              children: [
                // 1. HEADER SUPERIOR (Delgado y Fijo)
                Container(
                  height: 80,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            _buildPaiIsotype(),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Hola, $userName 👋',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Torre de control',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.white.withOpacity(0.9),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_activeAlertsCount > 0)
                              Stack(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.notifications, color: Colors.white, size: 20),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const MaintenancePage(),
                                        ),
                                      ).then((_) => _checkActiveAlerts());
                                    },
                                    tooltip: 'Tienes $_activeAlertsCount alertas',
                                  ),
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 14,
                                        minHeight: 14,
                                      ),
                                      child: Text(
                                        _activeAlertsCount > 9 ? '9+' : '$_activeAlertsCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            // Botón Super Admin (solo visible para super_admin)
                            if (_userRole == 'super_admin')
                              IconButton(
                                icon: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SuperAdminDashboardPage(),
                                    ),
                                  );
                                },
                                tooltip: 'Super Admin',
                              ),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                              onPressed: () {
                                _loadVehicleLocations();
                                _checkActiveAlerts();
                                _loadFinancialKpi();
                                _loadOperationalKpis();
                                _loadDocumentAlerts();
                              },
                              tooltip: 'Actualizar',
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout, color: Colors.white, size: 20),
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
                      ],
                    ),
                  ),
                ),
                // 2. MAPA EXPANSIVO (La Vista Principal)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FleetMonitoringPage(),
                        ),
                      );
                    },
                    child: kIsWeb
                        ? FlutterMap(
                            mapController: _flutterMapController,
                            options: MapOptions(
                              initialCenter: _vehicleLocations.isNotEmpty
                                  ? _calculateCenter()
                                  : _defaultLocationFlutter,
                              initialZoom: 8.0,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                              ),
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
                              zoom: 8.0,
                            ),
                            markers: _markers,
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            mapType: gmaps.MapType.normal,
                            zoomControlsEnabled: false,
                            zoomGesturesEnabled: true,
                            scrollGesturesEnabled: true,
                            tiltGesturesEnabled: false,
                            rotateGesturesEnabled: false,
                            onTap: (_) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const FleetMonitoringPage(),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                // 3. PANEL DE RESUMEN PAI (Fijo en la Base - Compacto)
                Container(
                  height: 150,
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI de Rentabilidad (compacto)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Balance mes actual',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '\$${numberFormat.format(balance.round())}',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: balance >= 0 ? AppColors.paiOrange : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.trending_up, size: 12, color: Colors.green),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        'Ing: \$${numberFormat.format(_currentMonthRevenue.round())}',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 9,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.trending_down, size: 12, color: Colors.red),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        'Gastos: \$${numberFormat.format((_currentMonthExpenses + _currentMonthMaintenanceExpenses).round())}',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 9,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 5 Chips de Alerta (2 filas para evitar scroll)
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Primera fila: Docs, Mantenimiento, Flota
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: _buildStatusChip(
                                    color: Colors.redAccent,
                                    label: 'Docs vencidos',
                                    value: '$_expiredDocumentsCount',
                                    compact: true,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildStatusChip(
                                    color: Colors.orangeAccent,
                                    label: 'Mantenimiento',
                                    value: '$_activeAlertsCount',
                                    compact: true,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildStatusChip(
                                    color: Colors.green,
                                    label: 'Flota',
                                    value: '${_vehicleLocations.length}',
                                    compact: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Segunda fila: Viajes, Remisiones
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: _buildStatusChip(
                                    color: Colors.blue,
                                    label: 'Viajes',
                                    value: '$_activeTripsCount',
                                    compact: true,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildStatusChip(
                                    color: Colors.orange,
                                    label: 'Remisiones',
                                    value: '$_pendingRemittancesCount',
                                    compact: true,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Espacio vacío para mantener el layout balanceado
                                const Expanded(child: SizedBox()),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 4. BOTONES FLOTANTES (UX Flotante Lateral)
            Positioned(
              right: 12,
              top: 100,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFloatingModuleButton(
                    icon: Icons.map,
                    label: 'Mapa',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FleetMonitoringPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildFloatingModuleButton(
                    icon: Icons.directions_car,
                    label: 'Vehículos',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FleetMonitoringPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildFloatingModuleButton(
                    icon: Icons.groups,
                    label: 'Conductores',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DriversManagementPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildFloatingModuleButton(
                    icon: Icons.route,
                    label: 'Viajes',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TripsListPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildFloatingModuleButton(
                    icon: Icons.build_circle,
                    label: 'Mantenimiento',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MaintenancePage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildFloatingModuleButton(
                    icon: Icons.receipt_long,
                    label: 'Gastos',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ExpensesPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildFloatingModuleButton(
                    icon: Icons.payments,
                    label: 'Cobranza',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BillingDashboardPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildFloatingModuleButton(
                    icon: Icons.description,
                    label: 'Documentos',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DocumentsManagementPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye un botón flotante pequeño para módulos
  Widget _buildFloatingModuleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: FloatingActionButton.small(
        heroTag: label,
        onPressed: onTap,
        backgroundColor: AppColors.paiOrange,
        foregroundColor: Colors.white,
        child: Icon(icon, size: 18),
      ),
    );
  }

}

