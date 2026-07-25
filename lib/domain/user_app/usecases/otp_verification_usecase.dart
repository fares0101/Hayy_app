import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

class OtpVerificationUseCase {
  final AuthRepository repository;

  OtpVerificationUseCase(this.repository);

  Future<Either<Failure, void>> call(String otp) {
    return repository.verifyOtp(otp);
  }
}