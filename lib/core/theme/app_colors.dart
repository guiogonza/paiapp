import 'package:flutter/material.dart';

/// Colores del manual de marca I°PAI
class AppColors {
  // Azules
  static const Color navyBlue = Color(0xFF1A237E); // Azul oscuro
  static const Color royalBlue = Color(0xFF1976D2); // Azul real
  static const Color lightBlue = Color(0xFF42A5F5); // Azul claro
  
  // Cyan
  static const Color cyan = Color(0xFF00BCD4);
  static const Color lightCyan = Color(0xFF4DD0E1);
  
  // Naranja (color de acento) - Ajustado según mockups
  static const Color orange = Color(0xFFFF6F00);
  static const Color lightOrange = Color(0xFFFFB74D);
  static const Color orangeAccent = Color(0xFFFF9800); // Naranja más vibrante para acciones
  
  // Colores de marca PAI (según manual)
  // Primario: Azul profundo PAI
  static const Color paiNavy = Color(0xFF040136);
  // Azul acento PAI
  static const Color paiBlue = Color(0xFF2201B2);
  // Naranjas PAI
  static const Color paiOrangeDeep = Color(0xFFE1421A);
  static const Color paiOrange = Color(0xFFFE7429);

  // Colores neutros
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color darkGray = Color(0xFF424242);
  static const Color lightGray = Color(0xFFE0E0E0);
  
  // Colores del tema
  static const Color primary = paiNavy;
  static const Color secondary = paiBlue;
  static const Color accent = paiOrange;
  static const Color background = white;
  static const Color surface = white;
  
  // Colores de texto
  static const Color textPrimary = paiNavy;
  static const Color textSecondary = darkGray;
  static const Color textOnPrimary = white;
  
  AppColors._();
}

