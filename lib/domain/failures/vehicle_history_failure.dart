abstract class VehicleHistoryFailure {
  final String message;
  const VehicleHistoryFailure(this.message);
}

class NetworkFailure extends VehicleHistoryFailure {
  const NetworkFailure([String? message])
      : super(message ?? 'Error de conexión. Verifica tu internet.');
}

class DatabaseFailure extends VehicleHistoryFailure {
  const DatabaseFailure(super.message);
}

class NotFoundFailure extends VehicleHistoryFailure {
  const NotFoundFailure(super.message);
}

class UnknownFailure extends VehicleHistoryFailure {
  const UnknownFailure(super.message);
}


