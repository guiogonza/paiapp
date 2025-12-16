import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/maintenance_repository_impl.dart';
import 'package:pai_app/data/repositories/vehicle_repository_impl.dart';
import 'package:pai_app/domain/entities/maintenance_entity.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';
import 'package:pai_app/presentation/pages/maintenance/maintenance_form_page.dart';

class MaintenanceAlertsPage extends StatefulWidget {
  const MaintenanceAlertsPage({super.key});

  @override
  State<MaintenanceAlertsPage> createState() => _MaintenanceAlertsPageState();
}

class _MaintenanceAlertsPageState extends State<MaintenanceAlertsPage> {
  final _maintenanceRepository = MaintenanceRepositoryImpl();
  final _vehicleRepository = VehicleRepositoryImpl();
  
  List<MaintenanceEntity> _alerts = [];
  Map<String, VehicleEntity> _vehiclesMap = {};
  Map<String, double> _vehicleMileageMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
    });

    // Cargar alertas y vehículos en paralelo
    final alertsResult = await _maintenanceRepository.getPendingAlerts();
    final vehiclesResult = await _vehicleRepository.getVehicles();

    alertsResult.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar alertas: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      },
      (alerts) {
        if (mounted) {
          setState(() {
            _alerts = alerts;
          });
        }
      },
    );

    vehiclesResult.fold(
      (failure) {
        // Ignorar errores de vehículos, continuar sin ellos
      },
      (vehicles) {
        if (mounted) {
          final vehiclesMap = <String, VehicleEntity>{};
          final mileageMap = <String, double>{};
          
          for (var vehicle in vehicles) {
            if (vehicle.id != null) {
              vehiclesMap[vehicle.id!] = vehicle;
              if (vehicle.currentMileage != null) {
                mileageMap[vehicle.id!] = vehicle.currentMileage!;
              }
            }
          }
          
          setState(() {
            _vehiclesMap = vehiclesMap;
            _vehicleMileageMap = mileageMap;
            _isLoading = false;
          });
        }
      },
    );
  }

  // Lógica de Semáforo: 🟢 Bien | 🟡 Atención | 🔴 Vencido
  String _getAlertStatus(MaintenanceEntity maintenance) {
    final now = DateTime.now();
    bool isOverdue = false;
    bool needsAttention = false;

    // Verificar por kilometraje
    if (maintenance.nextChangeKm != null) {
      final vehicleMileage = _vehicleMileageMap[maintenance.vehicleId];
      if (vehicleMileage != null) {
        final kmRemaining = maintenance.nextChangeKm! - vehicleMileage;
        if (kmRemaining <= 0) {
          isOverdue = true;
        } else if (kmRemaining <= 2000) {
          needsAttention = true;
        }
      }
    }

    // Verificar por fecha
    if (maintenance.alertDate != null) {
      final daysRemaining = maintenance.alertDate!.difference(now).inDays;
      if (daysRemaining < 0) {
        isOverdue = true;
      } else if (daysRemaining <= 30) {
        needsAttention = true;
      }
    }

    if (isOverdue) return 'vencido';
    if (needsAttention) return 'atencion';
    return 'bien';
  }

  String _getAlertMessage(MaintenanceEntity maintenance) {
    final now = DateTime.now();
    final messages = <String>[];

    // Verificar alerta por kilometraje
    if (maintenance.nextChangeKm != null) {
      final vehicleMileage = _vehicleMileageMap[maintenance.vehicleId];
      if (vehicleMileage != null) {
        final kmRemaining = maintenance.nextChangeKm! - vehicleMileage;
        if (kmRemaining <= 0) {
          messages.add('⚠️ Vencido: ${(-kmRemaining).toStringAsFixed(0)} km atrás');
        } else if (kmRemaining <= 2000) {
          messages.add('🔔 Faltan ${kmRemaining.toStringAsFixed(0)} km');
        }
      }
    }

    // Verificar alerta por fecha
    if (maintenance.alertDate != null) {
      final daysRemaining = maintenance.alertDate!.difference(now).inDays;
      if (daysRemaining < 0) {
        messages.add('⚠️ Vencido hace ${-daysRemaining} días');
      } else if (daysRemaining <= 30) {
        messages.add('🔔 Faltan $daysRemaining días');
      }
    }

    return messages.join(' / ');
  }

  Color _getAlertColor(MaintenanceEntity maintenance) {
    final status = _getAlertStatus(maintenance);
    switch (status) {
      case 'vencido':
        return Colors.red;
      case 'atencion':
        return Colors.orange;
      case 'bien':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getAlertIcon(MaintenanceEntity maintenance) {
    final status = _getAlertStatus(maintenance);
    switch (status) {
      case 'vencido':
        return Icons.error;
      case 'atencion':
        return Icons.warning;
      case 'bien':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _getStatusEmoji(MaintenanceEntity maintenance) {
    final status = _getAlertStatus(maintenance);
    switch (status) {
      case 'vencido':
        return '🔴';
      case 'atencion':
        return '🟡';
      case 'bien':
        return '🟢';
      default:
        return '⚪';
    }
  }

  /// Obtiene el texto a mostrar para el tipo de servicio
  /// - Para "Llantas": "Llantas - Posición [X]"
  /// - Para "Otro": muestra custom_service_name en lugar de "Otro"
  /// - Para otros tipos: muestra el tipo directamente
  String _getServiceTypeDisplay(MaintenanceEntity maintenance) {
    if (maintenance.serviceType == 'Llantas' && maintenance.tirePosition != null) {
      return 'Llantas - Posición ${maintenance.tirePosition}';
    }
    if (maintenance.serviceType == 'Otro' && maintenance.customServiceName != null && maintenance.customServiceName!.isNotEmpty) {
      return maintenance.customServiceName!;
    }
    return maintenance.serviceType;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas de Mantenimiento'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts,
            tooltip: 'Actualizar alertas',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay alertas pendientes',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Todos los mantenimientos están al día',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAlerts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _alerts.length,
                    itemBuilder: (context, index) {
                      final alert = _alerts[index];
                      final vehicle = _vehiclesMap[alert.vehicleId];
                      final vehiclePlate = vehicle?.placa ?? 'Vehículo desconocido';
                      final alertColor = _getAlertColor(alert);
                      final alertIcon = _getAlertIcon(alert);
                      final alertMessage = _getAlertMessage(alert);
                      final statusEmoji = _getStatusEmoji(alert);

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: alertColor.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: alertColor.withOpacity(0.2),
                            child: Icon(
                              alertIcon,
                              color: alertColor,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                statusEmoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  vehiclePlate,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                _getServiceTypeDisplay(alert),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                alertMessage,
                                style: TextStyle(
                                  color: alertColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (alert.nextChangeKm != null)
                                Text(
                                  'Próximo cambio: ${alert.nextChangeKm!.toStringAsFixed(0)} km',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              if (alert.alertDate != null)
                                Text(
                                  'Fecha alerta: ${DateFormat('dd/MM/yyyy').format(alert.alertDate!)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Botón Renovar
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                color: AppColors.paiOrange,
                                onPressed: () {
                                  Navigator.pop(context); // Cerrar cualquier diálogo abierto
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MaintenanceFormPage(
                                        preSelectedVehicleId: alert.vehicleId,
                                        preSelectedServiceType: alert.serviceType,
                                        preSelectedTirePosition: alert.tirePosition,
                                      ),
                                    ),
                                  ).then((_) {
                                    // Recargar alertas después de renovar
                                    _loadAlerts();
                                  });
                                },
                                tooltip: 'Renovar mantenimiento',
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                          onTap: () {
                            // Mostrar detalles de la alerta
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Alerta: ${_getServiceTypeDisplay(alert)}'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Vehículo: $vehiclePlate'),
                                    const SizedBox(height: 8),
                                    Text('Fecha servicio: ${DateFormat('dd/MM/yyyy').format(alert.serviceDate)}'),
                                    const SizedBox(height: 8),
                                    Text('Kilometraje servicio: ${alert.kmAtService.toStringAsFixed(0)} km'),
                                    if (alert.nextChangeKm != null) ...[
                                      const SizedBox(height: 8),
                                      Text('Próximo cambio: ${alert.nextChangeKm!.toStringAsFixed(0)} km'),
                                    ],
                                    if (alert.alertDate != null) ...[
                                      const SizedBox(height: 8),
                                      Text('Fecha alerta: ${DateFormat('dd/MM/yyyy').format(alert.alertDate!)}'),
                                    ],
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: alertColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        alertMessage,
                                        style: TextStyle(
                                          color: alertColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cerrar'),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MaintenanceFormPage(
                                            preSelectedVehicleId: alert.vehicleId,
                                            preSelectedServiceType: alert.serviceType,
                                            preSelectedTirePosition: alert.tirePosition,
                                          ),
                                        ),
                                      ).then((_) {
                                        _loadAlerts();
                                      });
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Renovar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.paiOrange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

