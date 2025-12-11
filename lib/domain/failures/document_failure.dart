abstract class DocumentFailure {
  final String message;

  const DocumentFailure(this.message);
}

class DatabaseFailure extends DocumentFailure {
  const DatabaseFailure(super.message);
}

class NetworkFailure extends DocumentFailure {
  const NetworkFailure() : super('Error de conexión. Verifica tu internet.');
}

class NotFoundFailure extends DocumentFailure {
  const NotFoundFailure() : super('Documento no encontrado');
}

class ValidationFailure extends DocumentFailure {
  const ValidationFailure(super.message);
}

class StorageFailure extends DocumentFailure {
  const StorageFailure(super.message);
}

class UnknownFailure extends DocumentFailure {
  const UnknownFailure(super.message);
}

