import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/maintenance_repository_impl.dart';
import 'package:pai_app/domain/entities/maintenance_entity.dart';
import 'package:pai_app/presentation/pages/maintenance/maintenance_form_page.dart';
import 'package:pai_app/presentation/pages/maintenance/maintenance_history_page.dart';
import 'package:pai_app/presentation/pages/maintenance/maintenance_alerts_page.dart';

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  final _maintenanceRepository = MaintenanceRepositoryImpl();
  List<MaintenanceEntity> _maintenanceList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaintenance();
  }

  Future<void> _loadMaintenance() async {
    setState(() => _isLoading = true);

    final result = await _maintenanceRepository.getAllMaintenance();

    result.fold(
      (failure) {
        debugPrint('Error cargando mantenimientos: ${failure.toString()}');
        setState(() => _isLoading = false);
      },
      (maintenanceList) {
        setState(() {
          _maintenanceList = maintenanceList;
          _isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mantenimiento'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMaintenance,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Botones grandes tipo tarjeta
              _buildActionCards(context),

              const SizedBox(height: 24),

              // Título de la tabla
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Últimos Mantenimientos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Tabla de mantenimientos
              _buildMaintenanceTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCards(BuildContext context) {
    return Row(
      children: [
        // Registrar Mantenimiento
        Expanded(
          child: _ActionCard(
            icon: Icons.build_circle,
            title: 'Registrar',
            subtitle: 'Nuevo mantenimiento',
            color: AppColors.primary,
            onTap: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const MaintenanceFormPage()),
              );
              if (result == true) {
                _loadMaintenance();
              }
            },
          ),
        ),
        const SizedBox(width: 12),

        // Ver Alertas
        Expanded(
          child: _ActionCard(
            icon: Icons.notifications_active,
            title: 'Alertas',
            subtitle: 'Próximos servicios',
            color: AppColors.orangeAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MaintenanceAlertsPage(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),

        // Ver Historial
        Expanded(
          child: _ActionCard(
            icon: Icons.history,
            title: 'Historial',
            subtitle: 'Ver todos',
            color: AppColors.secondary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MaintenanceHistoryPage(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMaintenanceTable() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_maintenanceList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          children: [
            Icon(Icons.build_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No hay mantenimientos registrados',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Registra tu primer mantenimiento',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              AppColors.primary.withOpacity(0.1),
            ),
            columns: const [
              DataColumn(
                label: Text(
                  'Fecha',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Tipo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Km',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Costo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Próximo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: _maintenanceList.take(10).map((m) {
              return DataRow(
                cells: [
                  DataCell(Text(dateFormat.format(m.serviceDate))),
                  DataCell(
                    _buildServiceTypeChip(m.serviceType, m.customServiceName),
                  ),
                  DataCell(Text('${m.kmAtService.toStringAsFixed(0)} km')),
                  DataCell(Text(currencyFormat.format(m.cost))),
                  DataCell(
                    Text(
                      m.nextChangeKm != null
                          ? '${m.nextChangeKm!.toStringAsFixed(0)} km'
                          : '-',
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTypeChip(String serviceType, String? customName) {
    Color chipColor;
    String displayName = serviceType;

    switch (serviceType.toLowerCase()) {
      case 'aceite':
        chipColor = Colors.amber;
        break;
      case 'llantas':
        chipColor = Colors.blue;
        break;
      case 'frenos':
        chipColor = Colors.red;
        break;
      case 'filtro aire':
        chipColor = Colors.green;
        break;
      case 'batería':
        chipColor = Colors.purple;
        break;
      case 'otro':
        chipColor = Colors.grey;
        displayName = customName ?? 'Otro';
        break;
      default:
        chipColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.5)),
      ),
      child: Text(
        displayName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: chipColor,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
