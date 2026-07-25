import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../entities/place_entity.dart';
import '../repositories/place_repository.dart';

class HomeUseCase {
  final PlaceRepository repository;

  HomeUseCase(this.repository);

  Future<Either<Failure, List<PlaceEntity>>> getRecommendedPlaces() {
    return repository.getPlaces();
  }
}