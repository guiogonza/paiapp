/// Reglas de negocio para mantenimiento inteligente
/// Define los intervalos de alerta para cada tipo de servicio
class MaintenanceRules {
  // Intervalos en kilómetros para alertas automáticas
  static const Map<String, int> kmIntervals = {
    'Aceite': 10000,
    'Llantas': 9000,
    'Frenos': 50000,
    'Filtro Aire': 13000,
    'Filtros': 13000, // Alias para compatibilidad
  };

  // Intervalos en años para alertas por fecha (solo Batería)
  static const Map<String, int> yearIntervals = {
    'Batería': 4,
  };

  /// Obtiene el intervalo en km para un tipo de servicio
  /// Retorna null si el servicio no tiene regla por km
  static int? getKmInterval(String serviceType) {
    return kmIntervals[serviceType];
  }

  /// Obtiene el intervalo en años para un tipo de servicio
  /// Retorna null si el servicio no tiene regla por años
  static int? getYearInterval(String serviceType) {
    return yearIntervals[serviceType];
  }

  /// Verifica si un tipo de servicio es estándar (tiene reglas automáticas)
  static bool isStandardType(String serviceType) {
    return kmIntervals.containsKey(serviceType) || 
           yearIntervals.containsKey(serviceType);
  }

  // Umbrales de anticipación para alertas
  static const int alertKmThreshold = 2000; // 2000 km antes del próximo servicio
  static const int alertDaysThreshold = 30; // 30 días antes de la fecha de vencimiento

  /// Calcula el km de alerta basado en el km actual y el tipo de servicio
  /// Retorna el km donde se debe hacer el próximo cambio (sin umbral)
  static double? calculateNextChangeKm(double currentKm, String serviceType) {
    final interval = getKmInterval(serviceType);
    if (interval == null) return null;
    return currentKm + interval;
  }

  /// Calcula el km de alerta ANTICIPADA (con umbral de 2000 km)
  /// Esta es la fecha donde se debe notificar al usuario
  static double? calculateAlertKm(double currentKm, String serviceType) {
    final nextChangeKm = calculateNextChangeKm(currentKm, serviceType);
    if (nextChangeKm == null) return null;
    // Alerta 2000 km antes del próximo cambio
    return nextChangeKm - alertKmThreshold;
  }

  /// Calcula la fecha de vencimiento basada en la fecha actual y el tipo de servicio
  /// Retorna la fecha donde se debe hacer el próximo cambio (sin umbral)
  static DateTime? calculateNextChangeDate(DateTime currentDate, String serviceType) {
    final years = getYearInterval(serviceType);
    if (years == null) return null;
    return DateTime(
      currentDate.year + years,
      currentDate.month,
      currentDate.day,
    );
  }

  /// Calcula la fecha de alerta ANTICIPADA (con umbral de 30 días)
  /// Esta es la fecha donde se debe notificar al usuario
  static DateTime? calculateAlertDate(DateTime currentDate, String serviceType) {
    final nextChangeDate = calculateNextChangeDate(currentDate, serviceType);
    if (nextChangeDate == null) return null;
    // Alerta 30 días antes del vencimiento
    return nextChangeDate.subtract(const Duration(days: alertDaysThreshold));
  }

  /// Calcula la fecha de alerta ANTICIPADA desde una fecha de vencimiento manual
  /// Si el usuario proporciona una fecha manual, la alerta es 30 días antes
  static DateTime? calculateAlertDateFromManual(DateTime manualDate) {
    return manualDate.subtract(const Duration(days: alertDaysThreshold));
  }

  /// Lista de tipos estándar (con reglas automáticas)
  static const List<String> standardTypes = [
    'Aceite',
    'Llantas',
    'Frenos',
    'Filtro Aire',
    'Batería',
  ];
}

