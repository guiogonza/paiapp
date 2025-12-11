import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/expense_entity.dart';
import 'package:pai_app/domain/failures/expense_failure.dart';

abstract class ExpenseRepository {
  Future<Either<ExpenseFailure, List<ExpenseEntity>>> getExpenses();
  Future<Either<ExpenseFailure, List<ExpenseEntity>>> getExpensesByRoute(String routeId);
  /// Obtiene todos los gastos asociados a un trip_id
  Future<Either<ExpenseFailure, List<ExpenseEntity>>> getExpensesByTripId(String tripId);
  /// Obtiene los gastos de un conductor específico para un trip_id
  Future<Either<ExpenseFailure, List<ExpenseEntity>>> getExpensesByTripIdAndDriver(String tripId, String driverId);
  Future<Either<ExpenseFailure, ExpenseEntity>> getExpenseById(String id);
  Future<Either<ExpenseFailure, ExpenseEntity>> createExpense(ExpenseEntity expense);
  Future<Either<ExpenseFailure, ExpenseEntity>> updateExpense(ExpenseEntity expense);
  Future<Either<ExpenseFailure, void>> deleteExpense(String id);
  Future<Either<ExpenseFailure, String>> uploadReceiptImage(String filePath);
  Future<Either<ExpenseFailure, String>> uploadReceiptImageFromBytes(List<int> fileBytes, String fileName);
  Future<Either<ExpenseFailure, void>> deleteReceiptImage(String imageUrl);
}

