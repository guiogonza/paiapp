/// Clase para manejar errores tipados del dominio de mantenimiento
abstract class MaintenanceFailure {
  final String message;
  const MaintenanceFailure(this.message);
  
  @override
  String toString() => message;
}

class MaintenanceDatabaseFailure extends MaintenanceFailure {
  const MaintenanceDatabaseFailure([String? message])
      : super(message ?? 'Error en la base de datos');
}

class MaintenanceNetworkFailure extends MaintenanceFailure {
  const MaintenanceNetworkFailure([String? message])
      : super(message ?? 'Error de conexión');
}

class MaintenanceNotFoundFailure extends MaintenanceFailure {
  const MaintenanceNotFoundFailure([String? message])
      : super(message ?? 'Mantenimiento no encontrado');
}

class MaintenanceValidationFailure extends MaintenanceFailure {
  const MaintenanceValidationFailure([String? message])
      : super(message ?? 'Datos inválidos');
}

class MaintenanceUnknownFailure extends MaintenanceFailure {
  const MaintenanceUnknownFailure([String? message])
      : super(message ?? 'Error desconocido');
}

