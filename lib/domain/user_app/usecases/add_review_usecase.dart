import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';

class AddReviewUseCase {
  Future<Either<Failure, void>> call(String placeId, int rating, String comment) async {
    // TODO: Implement submit review
    throw UnimplementedError();
  }
}