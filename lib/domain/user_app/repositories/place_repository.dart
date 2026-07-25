import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../entities/place_entity.dart';

// Place Repository
abstract class PlaceRepository {
  Future<Either<Failure, List<PlaceEntity>>> getPlaces();
  Future<Either<Failure, PlaceEntity>> getPlaceDetails(String id);
  Future<Either<Failure, List<PlaceEntity>>> searchPlaces(String query);
}
