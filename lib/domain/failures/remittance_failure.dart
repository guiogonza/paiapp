import 'package:dartz/dartz.dart';

abstract class RemittanceFailure {
  final String message;
  const RemittanceFailure(this.message);
}

class DatabaseFailure extends RemittanceFailure {
  const DatabaseFailure(super.message);
}

class NetworkFailure extends RemittanceFailure {
  const NetworkFailure() : super('Error de conexión');
}

class NotFoundFailure extends RemittanceFailure {
  const NotFoundFailure(super.message);
}

class ValidationFailure extends RemittanceFailure {
  const ValidationFailure(super.message);
}

class UnknownFailure extends RemittanceFailure {
  const UnknownFailure(super.message);
}

class StorageFailure extends RemittanceFailure {
  const StorageFailure(super.message);
}

