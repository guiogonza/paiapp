import 'dart:io';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/expense_entity.dart';
import 'package:pai_app/domain/failures/expense_failure.dart';
import 'package:pai_app/domain/repositories/expense_repository.dart';
import 'package:pai_app/data/models/expense_model.dart';
import 'package:pai_app/data/services/local_api_client.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final LocalApiClient _localApi = LocalApiClient();
  static const String _tableName = 'expenses';

  @override
  Future<Either<ExpenseFailure, List<ExpenseEntity>>> getExpenses() async {
    try {
      final response = await _localApi.getExpenses();

      final expenses = response
          .map((json) => ExpenseModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(expenses);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('Sesión expirada') || errorMsg.contains('401')) {
        return Left(
          ValidationFailure(
            'No tienes permisos. Asegúrate de estar autenticado correctamente.',
          ),
        );
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, List<ExpenseEntity>>> getExpensesByRoute(
    String routeId,
  ) async {
    return getExpensesByTripId(routeId);
  }

  @override
  Future<Either<ExpenseFailure, List<ExpenseEntity>>> getExpensesByTripId(
    String tripId,
  ) async {
    try {
      final response = await _localApi.get(
        '/rest/v1/expenses',
        queryParams: {'trip_id': 'eq.$tripId'},
      );

      final expenses = response
          .map((json) => ExpenseModel.fromJson(json as Map<String, dynamic>))
          .map((model) => model.toEntity())
          .toList();

      return Right(expenses);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, List<ExpenseEntity>>>
  getExpensesByTripIdAndDriver(String tripId, String driverId) async {
    try {
      final response = await _localApi.get(
        '/rest/v1/expenses',
        queryParams: {'trip_id': 'eq.$tripId', 'driver_id': 'eq.$driverId'},
      );

      final expenses = response
          .map((json) => ExpenseModel.fromJson(json as Map<String, dynamic>))
          .map((model) => model.toEntity())
          .toList();

      return Right(expenses);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, ExpenseEntity>> getExpenseById(
    String id,
  ) async {
    try {
      final response = await _localApi.getOne('/rest/v1/expenses', id);

      if (response == null) {
        return const Left(NotFoundFailure());
      }

      final expense = ExpenseModel.fromJson(response);
      return Right(expense.toEntity());
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('404')) {
        return const Left(NotFoundFailure());
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, ExpenseEntity>> createExpense(
    ExpenseEntity expense,
  ) async {
    try {
      final model = ExpenseModel.fromEntity(expense);
      final json = model.toJson();
      json.remove('id'); // No incluir id en la creación

      final response = await _localApi.createExpense(json);

      final createdExpense = ExpenseModel.fromJson(response);
      return Right(createdExpense.toEntity());
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('Sesión expirada') || errorMsg.contains('401')) {
        return Left(
          ValidationFailure(
            'No tienes permisos. Asegúrate de estar autenticado correctamente.',
          ),
        );
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, ExpenseEntity>> updateExpense(
    ExpenseEntity expense,
  ) async {
    try {
      if (expense.id == null) {
        return const Left(ValidationFailure('El ID del gasto es requerido'));
      }

      final model = ExpenseModel.fromEntity(expense);
      final json = model.toJson();
      json.remove('id');

      final response = await _localApi.updateExpense(expense.id!, json);

      final updatedExpense = ExpenseModel.fromJson(response);
      return Right(updatedExpense.toEntity());
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('404')) {
        return const Left(NotFoundFailure());
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, void>> deleteExpense(String id) async {
    try {
      await _localApi.deleteExpense(id);
      return const Right(null);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('404')) {
        return const Left(NotFoundFailure());
      }
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, String>> uploadReceiptImage(
    String filePath,
  ) async {
    try {
      final file = File(filePath);
      final fileBytes = await file.readAsBytes();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last.split('\\').last}';

      return await uploadReceiptImageFromBytes(fileBytes, fileName);
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(StorageFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, String>> uploadReceiptImageFromBytes(
    List<int> fileBytes,
    String fileName,
  ) async {
    try {
      // TODO: Implementar subida de archivos al servidor local
      // Por ahora retornamos una URL placeholder
      print('⚠️ Subida de imágenes pendiente de implementar en servidor local');
      return Right('http://82.208.21.130:3000/uploads/$fileName');
    } catch (e) {
      return Left(StorageFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, void>> deleteReceiptImage(
    String imageUrl,
  ) async {
    try {
      // TODO: Implementar eliminación de archivos en servidor local
      print(
        '⚠️ Eliminación de imágenes pendiente de implementar en servidor local',
      );
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(_mapGenericError(e)));
    }
  }

  /// Mapea errores genéricos a mensajes amigables
  String _mapGenericError(dynamic e) {
    final errorString = e.toString().toLowerCase();
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket')) {
      return 'Error de conexión';
    }
    if (errorString.contains('timeout')) {
      return 'La operación tardó demasiado. Intenta nuevamente';
    }
    return 'Ocurrió un error inesperado: ${e.toString()}';
  }
}
