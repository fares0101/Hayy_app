import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';

class PermissionsUseCase {
  Future<Either<Failure, bool>> requestLocationPermission() async {
    // TODO: Implement location permission request
    throw UnimplementedError();
  }

  Future<Either<Failure, bool>> requestNotificationPermission() async {
    // TODO: Implement notification permission request
    throw UnimplementedError();
  }
}