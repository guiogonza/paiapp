import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/vehicle_history_repository_impl.dart';
import 'package:pai_app/data/services/vehicle_history_service.dart';
import 'package:pai_app/domain/entities/vehicle_history_entity.dart';

class VehicleHistoryPage extends StatefulWidget {
  final String vehicleId;
  final String vehiclePlate;

  const VehicleHistoryPage({
    super.key,
    required this.vehicleId,
    required this.vehiclePlate,
  });

  @override
  State<VehicleHistoryPage> createState() => _VehicleHistoryPageState();
}

class _VehicleHistoryPageState extends State<VehicleHistoryPage> {
  final _historyRepository = VehicleHistoryRepositoryImpl();
  final _historyService = VehicleHistoryService();
  List<VehicleHistoryEntity> _history = [];
  bool _isLoading = true;
  DateTime? _fromDate;
  DateTime? _toDate;
  MapController? _flutterMapController;
  gmaps.GoogleMapController? _mapController;
  bool _loadingFromApi = false;

  // Ubicación por defecto: Bogotá, Colombia
  static const gmaps.LatLng _defaultLocation = gmaps.LatLng(4.7110, -74.0721);
  static const latlng.LatLng _defaultLocationFlutter = latlng.LatLng(4.7110, -74.0721);

  @override
  void initState() {
    super.initState();
    // Por defecto, cargar últimas 24 horas
    _toDate = DateTime.now();
    _fromDate = _toDate!.subtract(const Duration(days: 1));
    
    if (kIsWeb) {
      _flutterMapController = MapController();
    }
    
    // Pequeño delay para asegurar que el widget esté montado
    Future.delayed(const Duration(milliseconds: 100), () {
      _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    if (kDebugMode) {
      print('📊 Cargando historial para vehículo ${widget.vehicleId} (${widget.vehiclePlate})');
      print('   Desde: ${_fromDate?.toString() ?? "null"}');
      print('   Hasta: ${_toDate?.toString() ?? "null"}');
    }

    try {
      // Primero intentar obtener de Supabase
      final result = await _historyRepository.getVehicleHistory(
        widget.vehicleId,
        from: _fromDate,
        to: _toDate,
      );

      result.fold(
        (failure) {
          if (kDebugMode) {
            print('❌ Error al cargar de Supabase: ${failure.message}');
          }
          
          // Si no hay datos en Supabase, intentar obtener del API directamente
          _loadHistoryFromApi();
        },
        (history) {
          if (kDebugMode) {
            print('✅ Historial obtenido de Supabase: ${history.length} puntos');
          }
          
          if (history.isEmpty) {
            // Si no hay datos en Supabase, intentar obtener del API
            if (kDebugMode) {
              print('⚠️ No hay datos en Supabase, intentando obtener del API...');
            }
            _loadHistoryFromApi();
          } else {
            // Ordenar por timestamp ascendente para dibujar la ruta correctamente
            history.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            
            setState(() {
              _history = history;
              _isLoading = false;
            });
            
            // Centrar el mapa en la ruta después de que se renderice
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _centerMapOnRoute();
              });
            }
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al cargar historial: ${e.toString()}');
      }
      
      // Si falla Supabase, intentar del API
      _loadHistoryFromApi();
    }
  }

  Future<void> _loadHistoryFromApi() async {
    setState(() {
      _loadingFromApi = true;
    });

    if (kDebugMode) {
      print('📡 Obteniendo historial directamente del API de GPS...');
    }

    try {
      final history = await _historyService.getVehicleHistory(
        widget.vehicleId,
        widget.vehiclePlate,
        from: _fromDate,
        to: _toDate,
      );

      if (kDebugMode) {
        print('✅ Historial obtenido del API: ${history.length} puntos');
      }

      if (history.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay historial disponible para este vehículo en el rango de fechas seleccionado'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
        setState(() {
          _history = [];
          _isLoading = false;
          _loadingFromApi = false;
        });
        return;
      }

      // Ordenar por timestamp ascendente
      history.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      setState(() {
        _history = history;
        _isLoading = false;
        _loadingFromApi = false;
      });

      // Guardar en Supabase para futuras consultas (en segundo plano)
      _saveHistoryToSupabase(history);

      // Centrar el mapa en la ruta después de que se renderice
      // Usar un pequeño delay para asegurar que el mapa esté listo
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _centerMapOnRoute();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al obtener historial del API: ${e.toString()}');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al obtener historial: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      setState(() {
        _history = [];
        _isLoading = false;
        _loadingFromApi = false;
      });
    }
  }

  Future<void> _saveHistoryToSupabase(List<VehicleHistoryEntity> history) async {
    try {
      if (kDebugMode) {
        print('💾 Guardando ${history.length} puntos en Supabase...');
      }
      
      final result = await _historyRepository.saveVehicleHistory(history);
      result.fold(
        (failure) {
          if (kDebugMode) {
            print('⚠️ No se pudo guardar en Supabase: ${failure.message}');
          }
        },
        (_) {
          if (kDebugMode) {
            print('✅ Historial guardado en Supabase exitosamente');
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error al guardar en Supabase: ${e.toString()}');
      }
    }
  }

  void _centerMapOnRoute() {
    if (_history.isEmpty) return;

    if (kIsWeb) {
      // Verificar que el controlador esté listo y el mapa renderizado
      if (_flutterMapController == null) return;
      
      // Calcular el centro de la ruta para flutter_map
      double avgLat = 0;
      double avgLng = 0;
      for (var point in _history) {
        avgLat += point.lat;
        avgLng += point.lng;
      }
      avgLat /= _history.length;
      avgLng /= _history.length;

      // Usar un pequeño delay para asegurar que el mapa esté completamente renderizado
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _flutterMapController != null) {
          try {
            _flutterMapController!.move(
              latlng.LatLng(avgLat, avgLng),
              13.0,
            );
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Error al centrar mapa: $e');
            }
          }
        }
      });
    } else {
      // Calcular el centro y bounds para Google Maps
      double minLat = _history.first.lat;
      double maxLat = _history.first.lat;
      double minLng = _history.first.lng;
      double maxLng = _history.first.lng;

      for (var point in _history) {
        if (point.lat < minLat) minLat = point.lat;
        if (point.lat > maxLat) maxLat = point.lat;
        if (point.lng < minLng) minLng = point.lng;
        if (point.lng > maxLng) maxLng = point.lng;
      }

      _mapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngBounds(
          gmaps.LatLngBounds(
            southwest: gmaps.LatLng(minLat, minLng),
            northeast: gmaps.LatLng(maxLat, maxLng),
          ),
          100, // padding en píxeles
        ),
      );
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final initialFrom = _fromDate ?? now.subtract(const Duration(days: 1));
    final initialTo = _toDate ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: initialFrom,
        end: initialTo,
      ),
      locale: const Locale('es', 'ES'),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
      });
      _loadHistory();
    }
  }

  List<gmaps.LatLng> _getGoogleMapsPolyline() {
    return _history.map((point) => gmaps.LatLng(point.lat, point.lng)).toList();
  }

  List<latlng.LatLng> _getFlutterMapPolyline() {
    return _history.map((point) => latlng.LatLng(point.lat, point.lng)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial: ${widget.vehiclePlate}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _selectDateRange,
            tooltip: 'Filtrar por fecha',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  if (_loadingFromApi) ...[
                    const SizedBox(height: 16),
                    const Text('Obteniendo historial del API...'),
                  ] else ...[
                    const SizedBox(height: 16),
                    const Text('Cargando historial...'),
                  ],
                ],
              ),
            )
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay historial disponible',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No se encontraron puntos de historial para el rango de fechas seleccionado',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.date_range),
                        label: const Text('Seleccionar rango de fechas'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    // Mapa
                    kIsWeb
                        ? FlutterMap(
                            mapController: _flutterMapController,
                            options: MapOptions(
                              initialCenter: _history.isNotEmpty
                                  ? latlng.LatLng(_history.first.lat, _history.first.lng)
                                  : _defaultLocationFlutter,
                              initialZoom: 13.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.pai_app',
                              ),
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _getFlutterMapPolyline(),
                                    strokeWidth: 4.0,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  // Marcador inicial
                                  if (_history.isNotEmpty)
                                    Marker(
                                      point: latlng.LatLng(
                                        _history.first.lat,
                                        _history.first.lng,
                                      ),
                                      width: 30,
                                      height: 30,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                                      ),
                                    ),
                                  // Marcador final
                                  if (_history.isNotEmpty)
                                    Marker(
                                      point: latlng.LatLng(
                                        _history.last.lat,
                                        _history.last.lng,
                                      ),
                                      width: 30,
                                      height: 30,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(Icons.stop, color: Colors.white, size: 16),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          )
                        : gmaps.GoogleMap(
                            onMapCreated: (controller) {
                              _mapController = controller;
                              _centerMapOnRoute();
                            },
                            initialCameraPosition: gmaps.CameraPosition(
                              target: _history.isNotEmpty
                                  ? gmaps.LatLng(_history.first.lat, _history.first.lng)
                                  : _defaultLocation,
                              zoom: 13.0,
                            ),
                            polylines: {
                              gmaps.Polyline(
                                polylineId: const gmaps.PolylineId('route'),
                                points: _getGoogleMapsPolyline(),
                                color: AppColors.primary,
                                width: 4,
                              ),
                            },
                            markers: {
                              // Marcador inicial
                              if (_history.isNotEmpty)
                                gmaps.Marker(
                                  markerId: const gmaps.MarkerId('start'),
                                  position: gmaps.LatLng(
                                    _history.first.lat,
                                    _history.first.lng,
                                  ),
                                  icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                                    gmaps.BitmapDescriptor.hueGreen,
                                  ),
                                  infoWindow: gmaps.InfoWindow(
                                    title: 'Inicio',
                                    snippet: DateFormat('dd/MM/yyyy HH:mm').format(_history.first.timestamp),
                                  ),
                                ),
                              // Marcador final
                              if (_history.isNotEmpty)
                                gmaps.Marker(
                                  markerId: const gmaps.MarkerId('end'),
                                  position: gmaps.LatLng(
                                    _history.last.lat,
                                    _history.last.lng,
                                  ),
                                  icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                                    gmaps.BitmapDescriptor.hueRed,
                                  ),
                                  infoWindow: gmaps.InfoWindow(
                                    title: 'Fin',
                                    snippet: DateFormat('dd/MM/yyyy HH:mm').format(_history.last.timestamp),
                                  ),
                                ),
                            },
                            mapType: gmaps.MapType.normal,
                            zoomControlsEnabled: true,
                            zoomGesturesEnabled: true,
                            scrollGesturesEnabled: true,
                            tiltGesturesEnabled: true,
                            rotateGesturesEnabled: true,
                          ),
                    // Panel de información
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.route, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ruta recorrida',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildInfoItem(
                                    Icons.location_on,
                                    'Puntos',
                                    '${_history.length}',
                                  ),
                                  _buildInfoItem(
                                    Icons.access_time,
                                    'Desde',
                                    _fromDate != null
                                        ? DateFormat('dd/MM/yyyy').format(_fromDate!)
                                        : '--',
                                  ),
                                  _buildInfoItem(
                                    Icons.access_time,
                                    'Hasta',
                                    _toDate != null
                                        ? DateFormat('dd/MM/yyyy').format(_toDate!)
                                        : '--',
                                  ),
                                ],
                              ),
                              if (_history.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildInfoItem(
                                      Icons.play_arrow,
                                      'Inicio',
                                      DateFormat('HH:mm').format(_history.first.timestamp),
                                    ),
                                    _buildInfoItem(
                                      Icons.stop,
                                      'Fin',
                                      DateFormat('HH:mm').format(_history.last.timestamp),
                                    ),
                                    if (_history.any((h) => h.speed != null))
                                      _buildInfoItem(
                                        Icons.speed,
                                        'Vel. máx',
                                        '${_history.map((h) => h.speed ?? 0).reduce((a, b) => a > b ? a : b).toStringAsFixed(0)} km/h',
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

