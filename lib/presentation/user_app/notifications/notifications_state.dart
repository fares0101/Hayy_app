import '../../../data/user_app/models/notification_model.dart';

class NotificationsState {
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool isMarkingAllAsRead;
  final List<NotificationModel> notifications;
  final int unreadCount;
  final int pageNumber;
  final int pageSize;
  final bool hasMore;
  final String? errorMessage;

  const NotificationsState({
    required this.isInitialLoading,
    required this.isLoadingMore,
    required this.isMarkingAllAsRead,
    required this.notifications,
    required this.unreadCount,
    required this.pageNumber,
    required this.pageSize,
    required this.hasMore,
    required this.errorMessage,
  });

  factory NotificationsState.initial() {
    return const NotificationsState(
      isInitialLoading: false,
      isLoadingMore: false,
      isMarkingAllAsRead: false,
      notifications: <NotificationModel>[],
      unreadCount: 0,
      pageNumber: 1,
      pageSize: 10,
      hasMore: true,
      errorMessage: null,
    );
  }

  NotificationsState copyWith({
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? isMarkingAllAsRead,
    List<NotificationModel>? notifications,
    int? unreadCount,
    int? pageNumber,
    int? pageSize,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationsState(
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isMarkingAllAsRead: isMarkingAllAsRead ?? this.isMarkingAllAsRead,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      pageNumber: pageNumber ?? this.pageNumber,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
