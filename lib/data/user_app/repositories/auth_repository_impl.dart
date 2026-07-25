import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/user_app/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, Map<String, dynamic>>> login(String email, String password) async {
    try {
      final result = await remoteDataSource.login(email, password);
      return Right(result);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError || 
          e.type == DioExceptionType.connectionTimeout || 
          e.message?.contains('SocketException') == true ||
          (e.type == DioExceptionType.unknown && e.error.toString().contains('SocketException'))) {
        return const Left(ServerFailure('لا يوجد اتصال بالإنترنت. يرجى التحقق من الشبكة والمحاولة مرة أخرى.'));
      }
      if (e.response?.statusCode == 401) {
        return const Left(ServerFailure('Invalid credentials'));
      }
      return Left(ServerFailure(e.response?.data['message'] ?? 'Server error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> register(
      String name, String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> verifyOtp(String otp) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> forgotPassword(String email) async {
    try {
      await remoteDataSource.forgotPassword(email);
      return const Right(null);
    } on DioException catch (e) {
      String errorMessage = 'Server error';
      if (e.response?.data != null) {
        if (e.response!.data is Map) {
          errorMessage = e.response!.data['message'] ?? 'Server error';
        } else if (e.response!.data is String) {
          errorMessage = e.response!.data;
        }
      }
      return Left(ServerFailure(errorMessage));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    throw UnimplementedError();
  }
}
