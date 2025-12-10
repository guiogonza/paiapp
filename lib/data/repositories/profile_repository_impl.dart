import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/domain/entities/profile_entity.dart';
import 'package:pai_app/domain/failures/profile_failure.dart';
import 'package:pai_app/domain/repositories/profile_repository.dart';
import 'package:pai_app/data/models/profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'profiles';

  @override
  Future<Either<ProfileFailure, ProfileEntity>> getCurrentUserProfile() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return const Left(NotFoundFailure('No hay usuario autenticado'));
      }

      return await getProfileByUserId(currentUser.id);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  @override
  Future<Either<ProfileFailure, ProfileEntity>> getProfileByUserId(
      String userId) async {
    try {
      // En profiles, el id es la clave primaria que coincide con auth.uid()
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('id', userId)
          .single();

      final profile = ProfileModel.fromJson(response);
      return Right(profile.toEntity());
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        // No rows returned
        return const Left(NotFoundFailure('Perfil no encontrado'));
      }
      return Left(DatabaseFailure(_mapPostgrestError(e)));
    } on SocketException catch (_) {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(_mapGenericError(e)));
    }
  }

  String _mapPostgrestError(PostgrestException e) {
    if (e.message.contains('JWT')) {
      return 'Error de autenticación. Por favor, inicia sesión nuevamente.';
    }
    if (e.message.contains('permission denied') ||
        e.message.contains('row-level security')) {
      return 'No tienes permisos para acceder a este perfil.';
    }
    return e.message.isNotEmpty ? e.message : 'Error en la base de datos';
  }

  String _mapGenericError(dynamic e) {
    return e.toString().isNotEmpty ? e.toString() : 'Error desconocido';
  }
}

