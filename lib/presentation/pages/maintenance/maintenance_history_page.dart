import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/maintenance_repository_impl.dart';
import 'package:pai_app/data/repositories/vehicle_repository_impl.dart';
import 'package:pai_app/domain/entities/maintenance_entity.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';

class MaintenanceHistoryPage extends StatefulWidget {
  final String? vehicleId;
  
  const MaintenanceHistoryPage({super.key, this.vehicleId});

  @override
  State<MaintenanceHistoryPage> createState() => _MaintenanceHistoryPageState();
}

class _MaintenanceHistoryPageState extends State<MaintenanceHistoryPage> {
  final _maintenanceRepository = MaintenanceRepositoryImpl();
  final _vehicleRepository = VehicleRepositoryImpl();
  
  List<MaintenanceEntity> _maintenanceList = [];
  List<VehicleEntity> _vehicles = [];
  VehicleEntity? _selectedVehicle;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    if (widget.vehicleId != null) {
      _loadHistory(widget.vehicleId!);
    }
  }

  Future<void> _loadVehicles() async {
    final result = await _vehicleRepository.getVehicles();
    result.fold(
      (failure) {
        // Ignorar errores
      },
      (vehicles) {
        if (mounted) {
          setState(() {
            _vehicles = vehicles;
            if (widget.vehicleId != null) {
              _selectedVehicle = vehicles.firstWhere(
                (v) => v.id == widget.vehicleId,
                orElse: () => vehicles.first,
              );
            }
          });
        }
      },
    );
  }

  Future<void> _loadHistory(String vehicleId) async {
    setState(() {
      _isLoading = true;
    });

    final result = await _maintenanceRepository.getHistory(vehicleId);
    
    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar historial: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      },
      (maintenanceList) {
        if (mounted) {
          setState(() {
            _maintenanceList = maintenanceList;
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Mantenimiento'),
      ),
      body: Column(
        children: [
          // Selector de vehículo
          if (widget.vehicleId == null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<VehicleEntity>(
                value: _selectedVehicle,
                decoration: InputDecoration(
                  labelText: 'Seleccionar Vehículo',
                  prefixIcon: const Icon(Icons.directions_car),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _vehicles.map((vehicle) {
                  return DropdownMenuItem(
                    value: vehicle,
                    child: Text(vehicle.placa),
                  );
                }).toList(),
                onChanged: (vehicle) {
                  if (vehicle != null) {
                    setState(() {
                      _selectedVehicle = vehicle;
                    });
                    _loadHistory(vehicle.id!);
                  }
                },
              ),
            ),
          
          // Lista de mantenimientos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _maintenanceList.isEmpty
                    ? const Center(
                        child: Text('No hay registros de mantenimiento'),
                      )
                    : ListView.builder(
                        itemCount: _maintenanceList.length,
                        padding: const EdgeInsets.all(16.0),
                        itemBuilder: (context, index) {
                          final maintenance = _maintenanceList[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  maintenance.type[0],
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                maintenance.type,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fecha: ${DateFormat('dd/MM/yyyy').format(maintenance.date)}',
                                  ),
                                  Text(
                                    'Costo: \$${NumberFormat('#,##0.00').format(maintenance.cost)}',
                                  ),
                                  if (maintenance.description != null && maintenance.description!.isNotEmpty)
                                    Text(
                                      maintenance.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

