import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';

abstract class AuthRepository {
  Future<Either<Failure, Map<String, dynamic>>> login(String email, String password);
  Future<Either<Failure, void>> register(
    String name,
    String email,
    String password,
  );
  Future<Either<Failure, void>> verifyOtp(String otp);
  Future<Either<Failure, void>> forgotPassword(String email);
  Future<Either<Failure, void>> logout();
}
