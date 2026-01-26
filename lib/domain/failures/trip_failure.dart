/// Clase para manejar errores tipados del dominio de viajes
abstract class TripFailure {
  final String message;
  const TripFailure(this.message);
}

class NetworkFailure extends TripFailure {
  const NetworkFailure([String? message])
      : super(message ?? 'Error de conexión. Verifica tu internet.');
}

class DatabaseFailure extends TripFailure {
  const DatabaseFailure([String? message])
      : super(message ?? 'Error en la base de datos. Intenta más tarde.');
}

class ValidationFailure extends TripFailure {
  const ValidationFailure(super.message);
}

class NotFoundFailure extends TripFailure {
  const NotFoundFailure([String? message])
      : super(message ?? 'Viaje no encontrado.');
}

class UnknownFailure extends TripFailure {
  const UnknownFailure([String? message])
      : super(message ?? 'Error desconocido. Intenta más tarde.');
}


