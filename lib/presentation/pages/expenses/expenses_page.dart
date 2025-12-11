import 'package:flutter/material.dart';
import 'package:pai_app/presentation/pages/expenses/trip_selection_page.dart';

/// Punto de entrada al módulo de gastos
/// Navega directamente a la selección de viaje
class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Navegar directamente a la selección de viaje
    return const TripSelectionPage();
  }
}

