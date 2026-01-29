import 'package:flutter/foundation.dart';

/// Utilidad para logs seguros que oculta información sensible en producción
class SecureLogger {
  static const bool _isProduction = kReleaseMode;

  /// Log normal - solo en debug
  static void log(String message) {
    if (!_isProduction) {
      debugPrint(message);
    }
  }

  /// Log de información - siempre visible pero sin datos sensibles
  static void info(String message) {
    debugPrint(message);
  }

  /// Log de error - siempre visible
  static void error(String message) {
    debugPrint('❌ $message');
  }

  /// Oculta parte de un string sensible (API keys, tokens, etc.)
  static String mask(String? value, {int visibleChars = 4}) {
    if (value == null || value.isEmpty) return '***';
    if (_isProduction) return '***';
    if (value.length <= visibleChars) return '***';
    return '${value.substring(0, visibleChars)}...***';
  }
}
