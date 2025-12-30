import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/core/theme/app_colors.dart';

/// Dashboard confidencial de Super Admin para analítica y monitoreo del MVP
/// Solo accesible para usuarios con role 'super_admin'
class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  State<SuperAdminDashboardPage> createState() => _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic> _kpis = {};

  @override
  void initState() {
    super.initState();
    _loadKPIs();
  }

  Future<void> _loadKPIs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // KPI 1: Flota Operativa Real
      final assignedVehiclesResult = await _supabase
          .from('profiles')
          .select('assigned_vehicle_id')
          .not('assigned_vehicle_id', 'is', null);
      final assignedCount = (assignedVehiclesResult as List).length;

      final totalVehiclesResult = await _supabase
          .from('vehicles')
          .select('id');
      final totalVehicles = (totalVehiclesResult as List).length;

      // KPI 2: Tasa de Registro de Gastos
      // Primero obtener todos los trip_id únicos de expenses
      final expensesResult = await _supabase
          .from('expenses')
          .select('trip_id');
      final tripIdsWithExpenses = (expensesResult as List)
          .map((e) => e['trip_id'] as String)
          .toSet()
          .toList();
      final routesWithExpenses = tripIdsWithExpenses.length;

      final totalRoutesResult = await _supabase
          .from('routes')
          .select('id');
      final totalRoutes = (totalRoutesResult as List).length;
      final expenseRate = totalRoutes > 0 ? (routesWithExpenses / totalRoutes * 100) : 0.0;

      // KPI 3: Intensidad de Uso (Excluyendo Login)
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final usageLogsResult = await _supabase
          .from('app_logs')
          .select('id')
          .neq('action', 'login')
          .gte('created_at', sevenDaysAgo);
      final usageIntensity = (usageLogsResult as List).length;

      // KPI 4: Ratio Disciplinario
      final memosResult = await _supabase
          .from('remittances')
          .select('id');
      final totalMemos = (memosResult as List).length;
      final disciplinaryRatio = totalRoutes > 0 ? (totalMemos / totalRoutes) : 0.0;

      // KPI 5: Conductores Activos (Health Check)
      final fortyEightHoursAgo = DateTime.now().subtract(const Duration(hours: 48)).toIso8601String();
      final activeDriversResult = await _supabase
          .from('app_logs')
          .select('user_id')
          .gte('created_at', fortyEightHoursAgo);
      final activeDriverIds = (activeDriversResult as List)
          .map((e) => e['user_id'] as String)
          .toSet()
          .toList();

      // Verificar que sean conductores
      // Filtrar los IDs que son conductores
      final driversResult = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'driver');
      final driverIds = (driversResult as List)
          .map((e) => e['id'] as String)
          .toSet();
      // Contar cuántos de los conductores activos están en la lista de conductores
      final activeDrivers = activeDriverIds.where((id) => driverIds.contains(id)).length;

      // KPI 6: Cobertura de Mantenimiento
      final vehiclesWithMaintenanceResult = await _supabase
          .from('maintenance')
          .select('vehicle_id');
      final vehiclesWithMaintenance = (vehiclesWithMaintenanceResult as List)
          .map((e) => e['vehicle_id'] as String)
          .toSet()
          .toList()
          .length;
      final maintenanceCoverage = totalVehicles > 0 ? (vehiclesWithMaintenance / totalVehicles * 100) : 0.0;

      setState(() {
        _kpis = {
          'assignedVehicles': assignedCount,
          'totalVehicles': totalVehicles,
          'expenseRate': expenseRate,
          'usageIntensity': usageIntensity,
          'disciplinaryRatio': disciplinaryRatio,
          'activeDrivers': activeDrivers,
          'maintenanceCoverage': maintenanceCoverage,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error cargando KPIs: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildKPICard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Métricas MVP (Confidencial)'),
        backgroundColor: Colors.black87, // Color distintivo para Super Admin
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadKPIs,
            tooltip: 'Actualizar métricas',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadKPIs,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Advertencia de confidencialidad
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.security, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Información confidencial - Solo Super Admin',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[900],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Grid de KPIs (2 columnas)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                      children: [
                        // KPI 1: Flota Operativa Real
                        _buildKPICard(
                          icon: Icons.directions_car,
                          title: 'Flota Operativa',
                          value: '${_kpis['assignedVehicles'] ?? 0}/${_kpis['totalVehicles'] ?? 0}',
                          color: Colors.blue,
                        ),
                        // KPI 2: Tasa de Registro de Gastos
                        _buildKPICard(
                          icon: Icons.receipt,
                          title: 'Tasa de Gastos',
                          value: '${(_kpis['expenseRate'] ?? 0.0).toStringAsFixed(1)}%',
                          color: Colors.green,
                        ),
                        // KPI 3: Intensidad de Uso
                        _buildKPICard(
                          icon: Icons.trending_up,
                          title: 'Intensidad de Uso\n(7 días)',
                          value: '${_kpis['usageIntensity'] ?? 0}',
                          color: Colors.orange,
                        ),
                        // KPI 4: Ratio Disciplinario
                        _buildKPICard(
                          icon: Icons.warning,
                          title: 'Ratio Disciplinario',
                          value: '${(_kpis['disciplinaryRatio'] ?? 0.0).toStringAsFixed(2)}',
                          color: Colors.red,
                        ),
                        // KPI 5: Conductores Activos
                        _buildKPICard(
                          icon: Icons.people,
                          title: 'Conductores Activos\n(48h)',
                          value: '${_kpis['activeDrivers'] ?? 0}',
                          color: Colors.purple,
                        ),
                        // KPI 6: Cobertura de Mantenimiento
                        _buildKPICard(
                          icon: Icons.build,
                          title: 'Cobertura Mantenimiento',
                          value: '${(_kpis['maintenanceCoverage'] ?? 0.0).toStringAsFixed(1)}%',
                          color: Colors.teal,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

