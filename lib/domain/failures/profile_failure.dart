abstract class ProfileFailure {
  final String message;
  const ProfileFailure(this.message);
}

class NetworkFailure extends ProfileFailure {
  const NetworkFailure([String? message])
      : super(message ?? 'Error de conexión. Verifica tu internet.');
}

class DatabaseFailure extends ProfileFailure {
  const DatabaseFailure([String? message])
      : super(message ?? 'Error en la base de datos.');
}

class NotFoundFailure extends ProfileFailure {
  const NotFoundFailure([String? message])
      : super(message ?? 'Perfil no encontrado.');
}

class UnknownFailure extends ProfileFailure {
  const UnknownFailure([String? message])
      : super(message ?? 'Error desconocido.');
}


