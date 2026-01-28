import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/profile_repository_impl.dart';
import 'package:pai_app/data/repositories/remittance_repository_impl.dart';
import 'package:pai_app/data/repositories/vehicle_repository_impl.dart';
import 'package:pai_app/domain/entities/remittance_with_route_entity.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';
import 'package:pai_app/presentation/pages/driver/remittance_signing_page.dart';

class DriverRemittanceListPage extends StatefulWidget {
  const DriverRemittanceListPage({super.key});

  @override
  State<DriverRemittanceListPage> createState() =>
      _DriverRemittanceListPageState();
}

class _DriverRemittanceListPageState extends State<DriverRemittanceListPage> {
  final RemittanceRepositoryImpl _remittanceRepository =
      RemittanceRepositoryImpl();
  final ProfileRepositoryImpl _profileRepository = ProfileRepositoryImpl();
  final VehicleRepositoryImpl _vehicleRepository = VehicleRepositoryImpl();
  List<RemittanceWithRouteEntity> _pendingRemittances = [];
  bool _isLoading = true;
  Map<String, VehicleEntity> _vehiclesById = {};
  String? _driverName;

  @override
  void initState() {
    super.initState();
    _loadDriverRemittances();
  }

  Future<void> _loadDriverRemittances() async {
    setState(() {
      _isLoading = true;
    });

    // Obtener perfil del usuario actual
    final profileResult = await _profileRepository.getCurrentUserProfile();
    await profileResult.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar perfil: ${failure.message}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
      },
      (profile) async {
        // Obtener el email del usuario autenticado para buscar remisiones
        // El driver_name en routes puede ser el email o el nombre completo
        // TODO: Obtener usuario actual desde backend
        const dynamic currentUser = null;
        final userEmail = currentUser?.email;

        // Usar email si está disponible, sino usar fullName
        _driverName = userEmail ?? profile.fullName;

        if (_driverName == null || _driverName!.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No se encontró información del conductor en tu perfil',
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Obtener remisiones pendientes del conductor
        // Buscar tanto por email como por nombre completo
        final result = await _remittanceRepository.getDriverPendingRemittances(
          _driverName!,
        );

        await result.fold(
          (failure) async {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Error al cargar remisiones: ${failure.message}',
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            setState(() {
              _pendingRemittances = [];
              _isLoading = false;
            });
          },
          (remittances) async {
            // Cargar vehículos una sola vez para mostrar placa
            await _loadVehicles();
            setState(() {
              _pendingRemittances = remittances;
              _isLoading = false;
            });
          },
        );
      },
    );
  }

  Future<void> _loadVehicles() async {
    final result = await _vehicleRepository.getVehicles();
    result.fold(
      (failure) {
        _vehiclesById = {};
      },
      (vehicles) {
        final map = <String, VehicleEntity>{};
        for (final vehicle in vehicles) {
          if (vehicle.id != null) {
            map[vehicle.id!] = vehicle;
          }
        }
        _vehiclesById = map;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Remisiones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDriverRemittances,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingRemittances.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: AppColors.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '¡Todo al día!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No tienes remisiones pendientes por firmar.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDriverRemittances,
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _pendingRemittances.length,
                itemBuilder: (context, index) {
                  final remittance = _pendingRemittances[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RemittanceSigningPage(
                              remittanceWithRoute: remittance,
                              onRemittanceUpdated: _loadDriverRemittances,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.description,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cliente: ${remittance.clientName?.isNotEmpty == true ? remittance.clientName! : remittance.receiverName}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Viaje: ${remittance.startLocation} → ${remittance.endLocation}',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Vehículo: ${_buildVehicleLabel(remittance.vehicleId)}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fecha: ${remittance.createdAt != null ? DateFormat('dd/MM/yyyy').format(remittance.createdAt!) : 'N/A'}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Pendiente de firma',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _buildVehicleLabel(String vehicleId) {
    final vehicle = _vehiclesById[vehicleId];
    if (vehicle == null) {
      return '-';
    }
    return vehicle.placa;
  }
}
