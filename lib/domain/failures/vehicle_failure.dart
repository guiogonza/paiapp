/// Clase para manejar errores tipados del dominio de vehículos
abstract class VehicleFailure {
  final String message;
  const VehicleFailure(this.message);
}

class NetworkFailure extends VehicleFailure {
  const NetworkFailure([String? message])
      : super(message ?? 'Error de conexión. Verifica tu internet.');
}

class DatabaseFailure extends VehicleFailure {
  const DatabaseFailure([String? message])
      : super(message ?? 'Error en la base de datos. Intenta más tarde.');
}

class ValidationFailure extends VehicleFailure {
  const ValidationFailure(String message) : super(message);
}

class NotFoundFailure extends VehicleFailure {
  const NotFoundFailure([String? message])
      : super(message ?? 'Vehículo no encontrado.');
}

class UnknownFailure extends VehicleFailure {
  const UnknownFailure([String? message])
      : super(message ?? 'Error desconocido. Intenta más tarde.');
}

