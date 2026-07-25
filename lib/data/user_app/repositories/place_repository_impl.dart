import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/user_app/entities/place_entity.dart';
import '../../../domain/user_app/repositories/place_repository.dart';

class PlaceRepositoryImpl implements PlaceRepository {
  @override
  Future<Either<Failure, List<PlaceEntity>>> getPlaces() async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, PlaceEntity>> getPlaceDetails(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, List<PlaceEntity>>> searchPlaces(String query) async {
    throw UnimplementedError();
  }
}