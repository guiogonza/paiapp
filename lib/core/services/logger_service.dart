import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para registrar acciones de usuarios en app_logs
/// Usado para analítica y monitoreo del MVP
class LoggerService {
  static const String _tableName = 'app_logs';
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Registra una acción en app_logs
  /// 
  /// [action] - Nombre de la acción (ej: 'login', 'create_trip', 'add_expense')
  /// [details] - Detalles opcionales de la acción (JSON string o texto descriptivo)
  static Future<void> logAction(String action, {String? details}) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        // No registrar si no hay usuario autenticado
        print('⚠️ LoggerService: No hay usuario autenticado, no se registra la acción: $action');
        return;
      }

      await _supabase.from(_tableName).insert({
        'user_id': currentUser.id,
        'action': action,
        if (details != null) 'details': details,
        // created_at se maneja automáticamente por la BD con DEFAULT timezone('utc'::text, now())
      });

      print('✅ LoggerService: Acción registrada - $action (user: ${currentUser.id})');
    } catch (e) {
      // No fallar la aplicación si el logging falla
      print('❌ LoggerService: Error al registrar acción $action: $e');
    }
  }
}

