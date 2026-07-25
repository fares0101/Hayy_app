import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';

class NotificationsUseCase {
  Future<Either<Failure, List<dynamic>>> getNotifications() async {
    // TODO: Implement get notifications
    throw UnimplementedError();
  }

  Future<Either<Failure, void>> markAsRead(String notificationId) async {
    // TODO: Implement mark as read
    throw UnimplementedError();
  }
}