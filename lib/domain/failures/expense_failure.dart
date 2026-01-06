/// Clase para manejar errores tipados del dominio de gastos
abstract class ExpenseFailure {
  final String message;
  const ExpenseFailure(this.message);
}

class NetworkFailure extends ExpenseFailure {
  const NetworkFailure([String? message])
      : super(message ?? 'Error de conexión. Verifica tu internet.');
}

class DatabaseFailure extends ExpenseFailure {
  const DatabaseFailure([String? message])
      : super(message ?? 'Error en la base de datos. Intenta más tarde.');
}

class ValidationFailure extends ExpenseFailure {
  const ValidationFailure(String message) : super(message);
}

class NotFoundFailure extends ExpenseFailure {
  const NotFoundFailure([String? message])
      : super(message ?? 'Gasto no encontrado.');
}

class StorageFailure extends ExpenseFailure {
  const StorageFailure([String? message])
      : super(message ?? 'Error al subir la imagen. Intenta nuevamente.');
}

class UnknownFailure extends ExpenseFailure {
  const UnknownFailure([String? message])
      : super(message ?? 'Error desconocido. Intenta más tarde.');
}


