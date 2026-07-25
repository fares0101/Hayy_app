import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../entities/place_entity.dart';
import '../repositories/place_repository.dart';

// Get Places UseCase
class GetPlacesUseCase {
  final PlaceRepository repository;

  GetPlacesUseCase(this.repository);

  Future<Either<Failure, List<PlaceEntity>>> call() {
    return repository.getPlaces();
  }
}
