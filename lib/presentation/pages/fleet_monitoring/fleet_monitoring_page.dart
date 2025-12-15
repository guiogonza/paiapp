import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/services/vehicle_location_service.dart';
import 'package:pai_app/domain/entities/vehicle_location_entity.dart';
import 'package:pai_app/presentation/pages/vehicle_history/vehicle_history_page.dart';

class FleetMonitoringPage extends StatefulWidget {
  const FleetMonitoringPage({super.key});

  @override
  State<FleetMonitoringPage> createState() => _FleetMonitoringPageState();
}

class _FleetMonitoringPageState extends State<FleetMonitoringPage> {
  final _locationService = VehicleLocationService();
  gmaps.GoogleMapController? _mapController;
  MapController? _flutterMapController;
  List<VehicleLocationEntity> _vehicleLocations = [];
  VehicleLocationEntity? _selectedVehicle;
  bool _isLoading = true;
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
    _loadVehicleLocations();
  }

  Future<void> _loadVehicleLocations() async {
    setState(() {
      _isLoading = true;
    });

    debugPrint('🔄 Cargando ubicaciones de vehículos...');
    final locations = await _locationService.getVehicleLocations();
    debugPrint('✅ Ubicaciones cargadas: ${locations.length} vehículos');

    if (mounted) {
      setState(() {
        _vehicleLocations = locations;
        _isLoading = false;
      });

      if (locations.isNotEmpty) {
        _centerMapOnVehicles();
        _updateMarkers();
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
            width: 80,
            height: 80,
            child: GestureDetector(
              onTap: () => _onVehicleTap(vehicle),
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
              snippet: 'Último reporte: $timeStr${vehicle.speed != null ? '\nVelocidad: ${vehicle.speed!.toStringAsFixed(1)} km/h' : ''}',
            ),
            onTap: () => _onVehicleTap(vehicle),
          ),
        );
      }
      setState(() {
        _markers = markers;
      });
    }
  }

  void _onVehicleTap(VehicleLocationEntity vehicle) {
    setState(() {
      _selectedVehicle = vehicle;
    });
    _showVehicleInfoSheet();
  }

  void _showVehicleInfoSheet() {
    if (_selectedVehicle == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Vehículo ${_selectedVehicle!.plate}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Última actualización', _selectedVehicle!.timestamp != null
                        ? '${_selectedVehicle!.timestamp!.day}/${_selectedVehicle!.timestamp!.month}/${_selectedVehicle!.timestamp!.year} ${_selectedVehicle!.timestamp!.hour.toString().padLeft(2, '0')}:${_selectedVehicle!.timestamp!.minute.toString().padLeft(2, '0')}'
                        : 'N/A'),
                    if (_selectedVehicle!.speed != null)
                      _buildInfoRow('Velocidad', '${_selectedVehicle!.speed!.toStringAsFixed(1)} km/h'),
                    _buildInfoRow('Ubicación', '${_selectedVehicle!.lat.toStringAsFixed(6)}, ${_selectedVehicle!.lng.toStringAsFixed(6)}'),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VehicleHistoryPage(
                                vehicleId: _selectedVehicle!.id,
                                vehiclePlate: _selectedVehicle!.plate,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Ver Historial',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Text(
            vehicle.plate,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoreo de Flota'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVehicleLocations,
            tooltip: 'Actualizar ubicaciones',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Mapa
                kIsWeb
                    ? FlutterMap(
                        mapController: _flutterMapController,
                        options: MapOptions(
                          initialCenter: _vehicleLocations.isNotEmpty
                              ? _calculateCenter()
                              : _defaultLocationFlutter,
                          initialZoom: 8.0,
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
                        zoomControlsEnabled: true,
                        zoomGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                      ),
                // Botones flotantes
                Positioned(
                  right: 16,
                  top: 16,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'center',
                        onPressed: _centerMapOnVehicles,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.center_focus_strong, color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'zoom_in',
                        onPressed: () {
                          if (kIsWeb && _flutterMapController != null) {
                            _flutterMapController!.move(
                              _flutterMapController!.camera.center,
                              _flutterMapController!.camera.zoom + 1,
                            );
                          } else if (_mapController != null) {
                            _mapController!.animateCamera(gmaps.CameraUpdate.zoomIn());
                          }
                        },
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.zoom_in, color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'zoom_out',
                        onPressed: () {
                          if (kIsWeb && _flutterMapController != null) {
                            _flutterMapController!.move(
                              _flutterMapController!.camera.center,
                              _flutterMapController!.camera.zoom - 1,
                            );
                          } else if (_mapController != null) {
                            _mapController!.animateCamera(gmaps.CameraUpdate.zoomOut());
                          }
                        },
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.zoom_out, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

