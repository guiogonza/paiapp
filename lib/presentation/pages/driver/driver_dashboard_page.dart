import 'package:flutter/material.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/auth_repository_impl.dart';
import 'package:pai_app/data/repositories/profile_repository_impl.dart';
import 'package:pai_app/data/repositories/vehicle_repository_impl.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';
import 'package:pai_app/presentation/pages/login/login_page.dart';
import 'package:pai_app/presentation/pages/driver/driver_remittance_list_page.dart';
import 'package:pai_app/presentation/pages/expenses/expenses_page.dart';
import 'package:pai_app/presentation/pages/trips/trips_list_page.dart';

class DriverDashboardPage extends StatefulWidget {
  const DriverDashboardPage({super.key});

  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage> {
  final _profileRepository = ProfileRepositoryImpl();
  final _vehicleRepository = VehicleRepositoryImpl();

  bool _isLoadingVehicle = true;
  String _vehicleLabel = 'Cargando vehículo asignado...';

  @override
  void initState() {
    super.initState();
    _loadAssignedVehicle();
  }

  Future<void> _loadAssignedVehicle() async {
    setState(() {
      _isLoadingVehicle = true;
      _vehicleLabel = 'Cargando vehículo asignado...';
    });

    try {
      final profileResult = await _profileRepository.getCurrentUserProfile();
      await profileResult.fold(
        (failure) async {
          if (!mounted) return;
          setState(() {
            _vehicleLabel = 'No se pudo cargar el perfil';
            _isLoadingVehicle = false;
          });
        },
        (profile) async {
          final assignedVehicleId = profile.assignedVehicleId;
          if (assignedVehicleId == null || assignedVehicleId.isEmpty) {
            if (!mounted) return;
            setState(() {
              _vehicleLabel = 'Sin vehículo asignado';
              _isLoadingVehicle = false;
            });
            return;
          }

          final vehicleResult =
              await _vehicleRepository.getVehicleById(assignedVehicleId);
          vehicleResult.fold(
            (failure) {
              if (!mounted) return;
              setState(() {
                _vehicleLabel = 'No se pudo cargar el vehículo asignado';
                _isLoadingVehicle = false;
              });
            },
            (VehicleEntity vehicle) {
              if (!mounted) return;
              final placa = vehicle.placa;
              final marca = vehicle.marca;
              final modelo = vehicle.modelo;
              String label = placa;
              if (marca.isNotEmpty || modelo.isNotEmpty) {
                label = '$placa - $marca $modelo'.trim();
              }
              setState(() {
                _vehicleLabel = label;
                _isLoadingVehicle = false;
              });
            },
          );
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vehicleLabel = 'No se pudo cargar el vehículo asignado';
        _isLoadingVehicle = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard - Conductor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authRepository = AuthRepositoryImpl();
              await authRepository.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.drive_eta,
              size: 80,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Dashboard del Conductor',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            // Tarjeta de vehículo asignado
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.directions_car,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Vehículo asignado',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _vehicleLabel,
                  style: TextStyle(
                    color: _isLoadingVehicle
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar vehículo',
                  onPressed: _loadAssignedVehicle,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Botón para Mis Viajes
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TripsListPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.route),
                label: const Text('Mis Viajes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Botón para Mis Remisiones
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DriverRemittanceListPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.description),
                label: const Text('Mis Remisiones'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Botón para Gastos
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ExpensesPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt),
                label: const Text('Registrar Gastos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

