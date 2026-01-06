import 'package:dartz/dartz.dart';
import 'package:pai_app/domain/entities/trip_entity.dart';
import 'package:pai_app/domain/failures/trip_failure.dart';

abstract class TripRepository {
  Future<Either<TripFailure, List<TripEntity>>> getTrips();
  Future<Either<TripFailure, TripEntity>> getTripById(String id);
  Future<Either<TripFailure, TripEntity>> createTrip(TripEntity trip);
  Future<Either<TripFailure, TripEntity>> updateTrip(TripEntity trip);
  Future<Either<TripFailure, void>> deleteTrip(String id);
}


