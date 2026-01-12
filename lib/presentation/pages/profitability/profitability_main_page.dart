import 'package:flutter/material.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/presentation/pages/profitability/profitability_by_vehicle_page.dart';
import 'package:pai_app/presentation/pages/profitability/profitability_by_route_page.dart';
import 'package:pai_app/presentation/pages/profitability/profitability_by_driver_page.dart';
import 'package:pai_app/presentation/pages/profitability/profitability_global_page.dart';

class ProfitabilityMainPage extends StatelessWidget {
  const ProfitabilityMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rentabilidad'),
        backgroundColor: AppColors.primary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFloatingModuleButton(
              context,
              icon: Icons.directions_car,
              label: 'Por Vehículo',
              backgroundColor: Colors.blue,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfitabilityByVehiclePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildFloatingModuleButton(
              context,
              icon: Icons.route,
              label: 'Por Ruta',
              backgroundColor: Colors.green,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfitabilityByRoutePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildFloatingModuleButton(
              context,
              icon: Icons.person,
              label: 'Por Conductor',
              backgroundColor: Colors.orange,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfitabilityByDriverPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildFloatingModuleButton(
              context,
              icon: Icons.bar_chart,
              label: 'Global',
              backgroundColor: Colors.purple,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfitabilityGlobalPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingModuleButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: FloatingActionButton.extended(
        heroTag: label,
        onPressed: onTap,
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

