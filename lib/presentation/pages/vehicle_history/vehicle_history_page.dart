// TODO: Migrar toda la lógica de historial de vehículos a PostgreSQL/API REST.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
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
  final _historyService = VehicleHistoryService();
  List<VehicleHistoryEntity> _history = [];
  bool _isLoading = true;
  DateTime? _fromDate;
  DateTime? _toDate;
  MapController? _flutterMapController;
  gmaps.GoogleMapController? _mapController;
  final bool _loadingFromApi = false;
  VehicleHistoryEntity? _selectedPoint;
  OverlayEntry? _overlayEntry;

  // Ubicación por defecto: Bogotá, Colombia
  static const gmaps.LatLng _defaultLocation = gmaps.LatLng(4.7110, -74.0721);
  static const latlng.LatLng _defaultLocationFlutter = latlng.LatLng(
    4.7110,
    -74.0721,
  );

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
      print(
        '📊 Cargando historial para vehículo ${widget.vehicleId} (${widget.vehiclePlate})',
      );
      print('   Desde: ${_fromDate?.toString() ?? "null"}');
      print('   Hasta: ${_toDate?.toString() ?? "null"}');
    }

    try {
      // Primero intentar obtener de Supabase
      final history = await _historyService.getVehicleHistory(
        widget.vehicleId,
        widget.vehiclePlate,
        from: _fromDate,
        to: _toDate,
      );

      if (kDebugMode) {
        print('✅ Historial obtenido: ${history.length} puntos');
      }

      if (history.isEmpty) {
        // Si no hay datos, mostrar mensaje
        if (kDebugMode) {
          print('⚠️ No hay datos de historial disponibles');
        }
        setState(() {
          _history = [];
          _isLoading = false;
        });
      } else {
        // Ordenar por timestamp ascendente para dibujar la ruta correctamente
        history.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        setState(() {
          _history = history;
          _isLoading = false;
        });

        // Centrar el mapa en la ruta después de que se renderice
        // Usar un pequeño delay para asegurar que el mapa esté listo
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _centerMapOnRoute();
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al cargar historial: ${e.toString()}');
      }

      setState(() {
        _isLoading = false;
        _history = [];
      });
    }
  }

  // Centra el mapa en la ruta recorrida
  void _centerMapOnRoute() {
    if (_history.isEmpty || _mapController == null) return;
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

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final initialFrom = _fromDate ?? now.subtract(const Duration(days: 1));
    final initialTo = _toDate ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: DateTimeRange(start: initialFrom, end: initialTo),
      locale: const Locale('es', 'ES'),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end
            .add(const Duration(days: 1))
            .subtract(const Duration(seconds: 1));
      });
      _loadHistory();
    }
  }

  List<gmaps.LatLng> _getGoogleMapsPolyline() {
    return _history.map((point) => gmaps.LatLng(point.lat, point.lng)).toList();
  }

  /// Construye polylines segmentadas por estado de ignition para Google Maps
  Set<gmaps.Polyline> _buildGoogleMapsPolylinesWithIgnition() {
    if (_history.isEmpty) return {};

    final polylines = <gmaps.Polyline>{};
    List<gmaps.LatLng> currentSegment = [];
    bool? currentIgnition;
    int segmentIndex = 0;

    for (var point in _history) {
      final ignition = point.ignition;

      // Si cambia el estado de ignition, crear un nuevo segmento
      if (currentIgnition != null && currentIgnition != ignition) {
        if (currentSegment.length > 1) {
          polylines.add(
            gmaps.Polyline(
              polylineId: gmaps.PolylineId('route_segment_$segmentIndex'),
              points: List.from(currentSegment),
              color: currentIgnition == true ? Colors.green : Colors.red,
              width: 4,
            ),
          );
          segmentIndex++;
        }
        currentSegment = [];
      }

      currentSegment.add(gmaps.LatLng(point.lat, point.lng));
      currentIgnition = ignition;
    }

    // Agregar el último segmento
    if (currentSegment.length > 1) {
      polylines.add(
        gmaps.Polyline(
          polylineId: gmaps.PolylineId('route_segment_$segmentIndex'),
          points: currentSegment,
          color: currentIgnition == true ? Colors.green : Colors.red,
          width: 4,
        ),
      );
    }

    // Si no hay información de ignition, usar color por defecto
    if (polylines.isEmpty && _history.isNotEmpty) {
      polylines.add(
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('route'),
          points: _getGoogleMapsPolyline(),
          color: AppColors.primary,
          width: 4,
        ),
      );
    }

    return polylines;
  }

  List<latlng.LatLng> _getFlutterMapPolyline() {
    return _history
        .map((point) => latlng.LatLng(point.lat, point.lng))
        .toList();
  }

  /// Construye polylines segmentadas por estado de ignition
  /// Verde: vehículo encendido (ignition: true)
  /// Rojo: vehículo apagado (ignition: false)
  List<Polyline> _buildPolylinesWithIgnition() {
    if (_history.isEmpty) return [];

    final polylines = <Polyline>[];
    List<latlng.LatLng> currentSegment = [];
    bool? currentIgnition;

    for (var point in _history) {
      final ignition = point.ignition;

      // Si cambia el estado de ignition, crear un nuevo segmento
      if (currentIgnition != null && currentIgnition != ignition) {
        if (currentSegment.length > 1) {
          polylines.add(
            Polyline(
              points: List.from(currentSegment),
              strokeWidth: 4.0,
              color: currentIgnition == true ? Colors.green : Colors.red,
            ),
          );
        }
        currentSegment = [];
      }

      currentSegment.add(latlng.LatLng(point.lat, point.lng));
      currentIgnition = ignition;
    }

    // Agregar el último segmento
    if (currentSegment.length > 1) {
      polylines.add(
        Polyline(
          points: currentSegment,
          strokeWidth: 4.0,
          color: currentIgnition == true ? Colors.green : Colors.red,
        ),
      );
    }

    // Si no hay información de ignition, usar color por defecto
    if (polylines.isEmpty && _history.isNotEmpty) {
      polylines.add(
        Polyline(
          points: _getFlutterMapPolyline(),
          strokeWidth: 4.0,
          color: AppColors.primary,
        ),
      );
    }

    return polylines;
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
                              ? latlng.LatLng(
                                  _history.first.lat,
                                  _history.first.lng,
                                )
                              : _defaultLocationFlutter,
                          initialZoom: 13.0,
                          onTap: (tapPosition, point) {
                            _handleMapTap(point);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.pai_app',
                          ),
                          PolylineLayer(
                            polylines: _buildPolylinesWithIgnition(),
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
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 16,
                                    ),
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
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.stop,
                                      color: Colors.white,
                                      size: 16,
                                    ),
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
                        onTap: (position) {
                          _handleGoogleMapTap(position);
                        },
                        initialCameraPosition: gmaps.CameraPosition(
                          target: _history.isNotEmpty
                              ? gmaps.LatLng(
                                  _history.first.lat,
                                  _history.first.lng,
                                )
                              : _defaultLocation,
                          zoom: 13.0,
                        ),
                        polylines: _buildGoogleMapsPolylinesWithIgnition(),
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
                                snippet: DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                ).format(_history.first.timestamp),
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
                                snippet: DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                ).format(_history.last.timestamp),
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
                // Leyenda de colores (si hay información de ignition)
                if (_history.any((h) => h.ignition != null))
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estado del vehículo',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Encendido',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Apagado',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
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
                                    ? DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(_fromDate!)
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
                                  DateFormat(
                                    'HH:mm',
                                  ).format(_history.first.timestamp),
                                ),
                                _buildInfoItem(
                                  Icons.stop,
                                  'Fin',
                                  DateFormat(
                                    'HH:mm',
                                  ).format(_history.last.timestamp),
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
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// Encuentra el punto más cercano a la posición del tap
  VehicleHistoryEntity? _findNearestPoint(double lat, double lng) {
    if (_history.isEmpty) return null;

    VehicleHistoryEntity? nearest;
    double minDistance = double.infinity;

    for (var point in _history) {
      final distance = _calculateDistance(lat, lng, point.lat, point.lng);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = point;
      }
    }

    // Solo retornar si está dentro de un radio razonable (50 metros)
    return minDistance < 0.0005 ? nearest : null;
  }

  /// Calcula la distancia entre dos puntos en grados (aproximación)
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = lat2 - lat1;
    final dLng = lng2 - lng1;
    return (dLat * dLat) + (dLng * dLng);
  }

  /// Maneja el tap en FlutterMap (web)
  void _handleMapTap(latlng.LatLng point) {
    final nearest = _findNearestPoint(point.latitude, point.longitude);
    if (nearest != null) {
      setState(() {
        _selectedPoint = nearest;
      });
      _showInfoPopup(point.latitude, point.longitude);
    } else {
      _hideInfoPopup();
    }
  }

  /// Maneja el tap en Google Maps (móvil)
  void _handleGoogleMapTap(gmaps.LatLng position) {
    final nearest = _findNearestPoint(position.latitude, position.longitude);
    if (nearest != null) {
      setState(() {
        _selectedPoint = nearest;
      });
      _showInfoPopup(position.latitude, position.longitude);
    } else {
      _hideInfoPopup();
    }
  }

  /// Muestra el popup con información del punto
  void _showInfoPopup(double lat, double lng) {
    final point = _selectedPoint;
    if (point == null) return;

    _hideInfoPopup();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: MediaQuery.of(context).size.width / 2 - 150,
        top: 100,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Información del Punto',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _hideInfoPopup,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.access_time,
                  'Hora',
                  DateFormat('dd/MM/yyyy HH:mm:ss').format(point.timestamp),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.speed,
                  'Velocidad',
                  point.speed != null
                      ? '${point.speed!.toStringAsFixed(1)} km/h'
                      : 'No disponible',
                ),
                if (point.ignition != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    point.ignition == true ? Icons.power : Icons.power_off,
                    'Estado',
                    point.ignition == true ? 'Encendido' : 'Apagado',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Oculta el popup
  void _hideInfoPopup() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _selectedPoint = null;
    });
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _hideInfoPopup();
    _mapController?.dispose();
    super.dispose();
  }
}
