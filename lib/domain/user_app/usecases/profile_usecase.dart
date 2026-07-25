import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

class ProfileUseCase {
  final AuthRepository repository;

  ProfileUseCase(this.repository);

  Future<Either<Failure, void>> logout() {
    return repository.logout();
  }
}