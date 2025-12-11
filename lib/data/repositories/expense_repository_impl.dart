import 'dart:io';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/domain/entities/expense_entity.dart';
import 'package:pai_app/domain/failures/expense_failure.dart';
import 'package:pai_app/domain/repositories/expense_repository.dart';
import 'package:pai_app/data/models/expense_model.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'expenses';
  // IMPORTANTE: El bucket de storage se llama 'signatures' (mismo que remittances)
  static const String _storageBucket = 'signatures';

  @override
  Future<Either<ExpenseFailure, List<ExpenseEntity>>> getExpenses() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .order('date', ascending: false);

      final expenses = (response as List)
          .map((json) => ExpenseModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(expenses);
    } on PostgrestException catch (e) {
      if (e.message.contains('row-level security') || 
          e.message.contains('policy') ||
          e.code == 'PGRST301') {
        return Left(ValidationFailure(
          'No tienes permisos. Asegúrate de estar autenticado correctamente.'
        ));
      }
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, List<ExpenseEntity>>> getExpensesByRoute(
      String routeId) async {
    // NOTA: Este método mantiene routeId por compatibilidad, pero internamente usa trip_id
    // La tabla expenses usa trip_id, no route_id
    return getExpensesByTripId(routeId);
  }

  @override
  Future<Either<ExpenseFailure, List<ExpenseEntity>>> getExpensesByTripId(
      String tripId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('trip_id', tripId)
          .order('date', ascending: false);

      final expenses = (response as List)
          .map((json) => ExpenseModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(expenses);
    } on PostgrestException catch (e) {
      if (e.message.contains('row-level security') || 
          e.message.contains('policy') ||
          e.code == 'PGRST301') {
        return Left(ValidationFailure(
          'No tienes permisos. Asegúrate de estar autenticado correctamente.'
        ));
      }
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, List<ExpenseEntity>>> getExpensesByTripIdAndDriver(
      String tripId, String driverId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('trip_id', tripId)
          .eq('driver_id', driverId)
          .order('date', ascending: false);

      final expenses = (response as List)
          .map((json) => ExpenseModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();

      return Right(expenses);
    } on PostgrestException catch (e) {
      if (e.message.contains('row-level security') || 
          e.message.contains('policy') ||
          e.code == 'PGRST301') {
        return Left(ValidationFailure(
          'No tienes permisos. Asegúrate de estar autenticado correctamente.'
        ));
      }
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, ExpenseEntity>> getExpenseById(String id) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return const Left(NotFoundFailure());
      }

      final expense = ExpenseModel.fromJson(response);
      return Right(expense.toEntity());
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure());
      }
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, ExpenseEntity>> createExpense(
      ExpenseEntity expense) async {
    try {
      final model = ExpenseModel.fromEntity(expense);
      final json = model.toJson();
      json.remove('id'); // No incluir id en la creación
      
      // Asegurar que driver_id sea el auth.uid() del usuario actual
      // Si no viene en la entidad, obtenerlo del usuario autenticado
      if (json['driver_id'] == null) {
        final currentUserId = _supabase.auth.currentUser?.id;
        if (currentUserId != null) {
          json['driver_id'] = currentUserId;
        }
      }

      final response = await _supabase
          .from(_tableName)
          .insert(json)
          .select()
          .single();

      final createdExpense = ExpenseModel.fromJson(response);
      return Right(createdExpense.toEntity());
    } on PostgrestException catch (e) {
      if (e.message.contains('row-level security') || 
          e.message.contains('policy') ||
          e.code == 'PGRST301') {
        return Left(ValidationFailure(
          'No tienes permisos. Asegúrate de estar autenticado correctamente.'
        ));
      }
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, ExpenseEntity>> updateExpense(
      ExpenseEntity expense) async {
    try {
      if (expense.id == null) {
        return const Left(ValidationFailure('El ID del gasto es requerido'));
      }

      final model = ExpenseModel.fromEntity(expense);
      final json = model.toJson();
      json.remove('id'); // No actualizar el id

      final response = await _supabase
          .from(_tableName)
          .update(json)
          .eq('id', expense.id!)
          .select()
          .single();

      final updatedExpense = ExpenseModel.fromJson(response);
      return Right(updatedExpense.toEntity());
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure());
      }
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, void>> deleteExpense(String id) async {
    try {
      // Primero obtener el gasto para eliminar la imagen si existe
      final expenseResult = await getExpenseById(id);
      await expenseResult.fold(
        (failure) => null,
        (expense) async {
          if (expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty) {
            await deleteReceiptImage(expense.receiptUrl!);
          }
        },
      );

      await _supabase.from(_tableName).delete().eq('id', id);

      return const Right(null);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure());
      }
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, String>> uploadReceiptImage(
      String filePath) async {
    try {
      final file = File(filePath);
      
      // Leer los bytes del archivo (funciona tanto en móvil como en web)
      final fileBytes = await file.readAsBytes();
      
      // Generar nombre único para el archivo
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last.split('\\').last}';

      return await uploadReceiptImageFromBytes(fileBytes, fileName);
    } on StorageException catch (e) {
      return Left(StorageFailure(_mapStorageError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(StorageFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, String>> uploadReceiptImageFromBytes(
      List<int> fileBytes, String fileName) async {
    try {
      // Convertir List<int> a Uint8List
      final uint8List = Uint8List.fromList(fileBytes);
      
      // Subir usando uploadBinary que acepta Uint8List
      await _supabase.storage
          .from(_storageBucket)
          .uploadBinary(
            fileName, 
            uint8List, 
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );

      final imageUrl = _supabase.storage
          .from(_storageBucket)
          .getPublicUrl(fileName);

      return Right(imageUrl);
    } on StorageException catch (e) {
      return Left(StorageFailure(_mapStorageError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(StorageFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ExpenseFailure, void>> deleteReceiptImage(
      String imageUrl) async {
    try {
      // Extraer el nombre del archivo de la URL
      final fileName = imageUrl.split('/').last.split('?').first;

      await _supabase.storage
          .from(_storageBucket)
          .remove([fileName]);

      return const Right(null);
    } on StorageException catch (e) {
      // Si el archivo no existe, no es un error crítico
      if (e.statusCode == '404' || e.message.contains('not found')) {
        return const Right(null);
      }
      return Left(StorageFailure(_mapStorageError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(StorageFailure(_mapGenericError(e)));
    }
  }

  /// Mapea errores de Postgrest a mensajes amigables
  String _mapPostgrestError(PostgrestException e) {
    if (e.code == '23505') {
      return 'Ya existe un gasto con estos datos';
    }
    if (e.code == '23503') {
      return 'Error de integridad de datos. Verifica que la ruta exista';
    }
    if (e.code == 'PGRST301') {
      return 'No tienes permisos para realizar esta acción';
    }
    return e.message.isNotEmpty ? e.message : 'Error en la base de datos';
  }

  /// Mapea errores de Storage a mensajes amigables
  String _mapStorageError(StorageException e) {
    if (e.statusCode == '413') {
      return 'La imagen es demasiado grande';
    }
    if (e.statusCode == '415') {
      return 'Formato de imagen no soportado';
    }
    return e.message.isNotEmpty ? e.message : 'Error al subir la imagen';
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
    return 'Ocurrió un error inesperado';
  }
}

