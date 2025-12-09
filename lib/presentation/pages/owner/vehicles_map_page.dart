import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/services/vehicle_location_service.dart';
import 'package:pai_app/domain/entities/vehicle_location_entity.dart';
import 'package:pai_app/presentation/pages/vehicle_history/vehicle_history_page.dart';

class VehiclesMapPage extends StatefulWidget {
  const VehiclesMapPage({super.key});

  @override
  State<VehiclesMapPage> createState() => _VehiclesMapPageState();
}

class _VehiclesMapPageState extends State<VehiclesMapPage> {
  final _locationService = VehicleLocationService();
  MapController? _flutterMapController;
  gmaps.GoogleMapController? _mapController;
  List<VehicleLocationEntity> _vehicleLocations = [];
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

    try {
      final locations = await _locationService.getVehicleLocations();
      setState(() {
        _vehicleLocations = locations;
        _isLoading = false;
      });
      _updateMarkers();
      _centerMapOnVehicles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar ubicaciones: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
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
        markers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId(vehicle.id),
            position: gmaps.LatLng(vehicle.lat, vehicle.lng),
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
              gmaps.BitmapDescriptor.hueBlue,
            ),
            infoWindow: gmaps.InfoWindow(
              title: vehicle.plate,
              snippet: vehicle.timestamp != null
                  ? 'Actualizado: ${vehicle.timestamp!.toString().substring(0, 16)}'
                  : 'Sin actualización',
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
      // Calcular el centro de todos los vehículos
      double avgLat = 0;
      double avgLng = 0;
      for (var vehicle in _vehicleLocations) {
        avgLat += vehicle.lat;
        avgLng += vehicle.lng;
      }
      avgLat /= _vehicleLocations.length;
      avgLng /= _vehicleLocations.length;

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _flutterMapController != null) {
          try {
            _flutterMapController!.move(
              latlng.LatLng(avgLat, avgLng),
              11.0,
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
          100,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista de Vehículos'),
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
          : _vehicleLocations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 80,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No hay vehículos disponibles',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No se encontraron vehículos con ubicación',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    kIsWeb
                        ? FlutterMap(
                            mapController: _flutterMapController,
                            options: MapOptions(
                              initialCenter: _vehicleLocations.isNotEmpty
                                  ? latlng.LatLng(
                                      _vehicleLocations.first.lat,
                                      _vehicleLocations.first.lng,
                                    )
                                  : _defaultLocationFlutter,
                              initialZoom: 11.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.pai_app',
                              ),
                              MarkerLayer(markers: _flutterMarkers),
                            ],
                          )
                        : gmaps.GoogleMap(
                            onMapCreated: (controller) {
                              _mapController = controller;
                              _centerMapOnVehicles();
                            },
                            initialCameraPosition: gmaps.CameraPosition(
                              target: _vehicleLocations.isNotEmpty
                                  ? gmaps.LatLng(
                                      _vehicleLocations.first.lat,
                                      _vehicleLocations.first.lng,
                                    )
                                  : _defaultLocation,
                              zoom: 11.0,
                            ),
                            markers: _markers,
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
                          child: Row(
                            children: [
                              const Icon(Icons.directions_car, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                '${_vehicleLocations.length} vehículo${_vehicleLocations.length != 1 ? 's' : ''} en el mapa',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
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

