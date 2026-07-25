import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../entities/place_entity.dart';
import '../repositories/place_repository.dart';

class SearchUseCase {
  final PlaceRepository repository;

  SearchUseCase(this.repository);

  Future<Either<Failure, List<PlaceEntity>>> call(String query) {
    return repository.searchPlaces(query);
  }
}