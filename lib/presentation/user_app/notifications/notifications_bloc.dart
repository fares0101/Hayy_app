import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../../core/services/signal_r_service.dart';
import '../../../data/user_app/datasources/notifications_remote_data_source.dart';
import '../../../data/user_app/models/notification_model.dart';
import 'notifications_state.dart';

abstract class NotificationsEvent {}

class LoadNotificationsEvent extends NotificationsEvent {}

class RefreshNotificationsEvent extends NotificationsEvent {}

class LoadMoreNotificationsEvent extends NotificationsEvent {}

class MarkAsReadEvent extends NotificationsEvent {
  final String notificationId;
  MarkAsReadEvent(this.notificationId);
}

class MarkAllAsReadEvent extends NotificationsEvent {}
class PollRealtimeNotificationsEvent extends NotificationsEvent {}

class RealtimeNotificationReceivedEvent extends NotificationsEvent {
  final NotificationModel notification;
  RealtimeNotificationReceivedEvent(this.notification);
}

class RealtimeUnreadCountUpdatedEvent extends NotificationsEvent {
  final int unreadCount;
  RealtimeUnreadCountUpdatedEvent(this.unreadCount);
}

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final NotificationsRemoteDataSource notificationsRemoteDataSource;
  final SignalRService signalRService;
  
  Timer? _realtimeTimer;
  StreamSubscription? _notificationSub;
  StreamSubscription? _unreadCountSub;
  bool _isPolling = false;
  bool _notificationsAccessDenied = false;

  NotificationsBloc(this.notificationsRemoteDataSource, this.signalRService)
      : super(NotificationsState.initial()) {
    on<LoadNotificationsEvent>(_onLoadNotifications);
    on<RefreshNotificationsEvent>(_onRefreshNotifications);
    on<LoadMoreNotificationsEvent>(_onLoadMoreNotifications);
    on<MarkAsReadEvent>(_onMarkAsRead);
    on<MarkAllAsReadEvent>(_onMarkAllAsRead);
    on<PollRealtimeNotificationsEvent>(_onPollRealtimeNotifications);
    on<RealtimeNotificationReceivedEvent>(_onRealtimeNotificationReceived);
    on<RealtimeUnreadCountUpdatedEvent>(_onRealtimeUnreadCountUpdated);
    
    // Poll as fallback/backup
    _startRealtimeSync();
    
    // Subscribe to SignalR streams
    _subscribeToSignalR();
  }

  void _subscribeToSignalR() {
    _notificationSub?.cancel();
    _notificationSub = signalRService.notificationStream.listen((notification) {
      add(RealtimeNotificationReceivedEvent(notification));
    });

    _unreadCountSub?.cancel();
    _unreadCountSub = signalRService.unreadCountStream.listen((count) {
      add(RealtimeUnreadCountUpdatedEvent(count));
    });
  }

  Future<void> _onRealtimeNotificationReceived(
    RealtimeNotificationReceivedEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    // Check if duplicate
    if (state.notifications.any((n) => n.id == event.notification.id)) {
      return;
    }

    final updated = [event.notification, ...state.notifications];
    emit(state.copyWith(
      notifications: updated,
      unreadCount: state.unreadCount + 1,
    ));
  }

  Future<void> _onRealtimeUnreadCountUpdated(
    RealtimeUnreadCountUpdatedEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state.unreadCount != event.unreadCount) {
      emit(state.copyWith(unreadCount: event.unreadCount));
    }
  }

  Future<void> _onLoadNotifications(
    LoadNotificationsEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(
      state.copyWith(
        isInitialLoading: true,
        pageNumber: 1,
        hasMore: true,
        clearError: true,
      ),
    );

    try {
      final pageResult = await notificationsRemoteDataSource.getNotifications(
        pageNumber: 1,
        pageSize: state.pageSize,
      );
      final unreadCount = await notificationsRemoteDataSource.getUnreadCount();
      _notificationsAccessDenied = false;
      final hasMore = _resolveHasMore(
        pageResult: pageResult,
        currentPageItemsCount: pageResult.items.length,
        currentPage: 1,
        pageSize: state.pageSize,
      );

      emit(
        state.copyWith(
          isInitialLoading: false,
          notifications: pageResult.items,
          unreadCount: unreadCount,
          pageNumber: 1,
          hasMore: hasMore,
          clearError: true,
        ),
      );
    } catch (e) {
      if (_isAccessDeniedError(e)) {
        _notificationsAccessDenied = true;
      }
      emit(
        state.copyWith(
          isInitialLoading: false,
          hasMore: false,
          errorMessage: _extractErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onRefreshNotifications(
    RefreshNotificationsEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    add(LoadNotificationsEvent());
  }

  Future<void> _onLoadMoreNotifications(
    LoadMoreNotificationsEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    if (_notificationsAccessDenied ||
        state.isLoadingMore ||
        state.isInitialLoading ||
        !state.hasMore) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true, clearError: true));

    final nextPage = state.pageNumber + 1;
    try {
      final pageResult = await notificationsRemoteDataSource.getNotifications(
        pageNumber: nextPage,
        pageSize: state.pageSize,
      );
      final combined = List<NotificationModel>.from(state.notifications)
        ..addAll(pageResult.items);
      final hasMore = _resolveHasMore(
        pageResult: pageResult,
        currentPageItemsCount: pageResult.items.length,
        currentPage: nextPage,
        pageSize: state.pageSize,
      );

      emit(
        state.copyWith(
          isLoadingMore: false,
          notifications: combined,
          pageNumber: nextPage,
          hasMore: hasMore,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingMore: false,
          errorMessage: _extractErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onMarkAsRead(
    MarkAsReadEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    final target = state.notifications.where((n) => n.id == event.notificationId);
    if (target.isEmpty || target.first.isRead) {
      return;
    }

    final updatedNotifications = state.notifications
        .map((notification) => notification.id == event.notificationId
            ? notification.copyWith(isRead: true)
            : notification)
        .toList();

    final updatedUnread = state.unreadCount > 0 ? state.unreadCount - 1 : 0;
    emit(
      state.copyWith(
        notifications: updatedNotifications,
        unreadCount: updatedUnread,
        clearError: true,
      ),
    );

    try {
      await notificationsRemoteDataSource.markAsRead(event.notificationId);
    } catch (e) {
      final refreshedUnreadCount =
          await _safeGetUnreadCount(fallback: state.unreadCount);
      emit(
        state.copyWith(
          unreadCount: refreshedUnreadCount,
          errorMessage: _extractErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onMarkAllAsRead(
    MarkAllAsReadEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state.isMarkingAllAsRead || state.notifications.isEmpty) {
      return;
    }

    emit(state.copyWith(isMarkingAllAsRead: true, clearError: true));
    try {
      await notificationsRemoteDataSource.markAllAsRead();
      final updated = state.notifications
          .map((notification) => notification.copyWith(isRead: true))
          .toList();
      emit(
        state.copyWith(
          isMarkingAllAsRead: false,
          notifications: updated,
          unreadCount: 0,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isMarkingAllAsRead: false,
          errorMessage: _extractErrorMessage(e),
        ),
      );
    }
  }

  void _startRealtimeSync() {
    _realtimeTimer?.cancel();
    _realtimeTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => add(PollRealtimeNotificationsEvent()),
    );
  }

  Future<void> _onPollRealtimeNotifications(
    PollRealtimeNotificationsEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    if (_notificationsAccessDenied || _isPolling || isClosed) {
      return;
    }
    _isPolling = true;
    try {
      final latestUnread = await notificationsRemoteDataSource.getUnreadCount();
      if (isClosed) return;

      final hadIncrease = latestUnread > state.unreadCount;
      if (latestUnread != state.unreadCount) {
        emit(state.copyWith(unreadCount: latestUnread));
      }

      // If new notifications arrived, refresh the first page in the background.
      if (hadIncrease && !state.isInitialLoading) {
        add(LoadNotificationsEvent());
      }
    } catch (_) {
      // Silent fail for realtime polling to avoid noisy errors every interval.
    } finally {
      _isPolling = false;
    }
  }

  bool _resolveHasMore({
    required NotificationsPageResult pageResult,
    required int currentPageItemsCount,
    required int currentPage,
    required int pageSize,
  }) {
    if (pageResult.totalCount != null) {
      return currentPage * pageSize < pageResult.totalCount!;
    }
    return currentPageItemsCount >= pageSize;
  }

  String _extractErrorMessage(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        return 'Your session expired. Please sign in again.';
      }
      if (statusCode == 403) {
        return 'Notifications are not available for this account right now.';
      }

      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'] ?? data['error'] ?? data['title'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
      if (data is String && data.isNotEmpty) {
        return data;
      }
      return error.message ?? 'Request failed';
    }
    return error.toString();
  }

  bool _isAccessDeniedError(Object error) {
    return error is DioException &&
        (error.response?.statusCode == 401 || error.response?.statusCode == 403);
  }

  Future<int> _safeGetUnreadCount({required int fallback}) async {
    try {
      return await notificationsRemoteDataSource.getUnreadCount();
    } catch (_) {
      return fallback;
    }
  }

  @override
  Future<void> close() {
    _realtimeTimer?.cancel();
    _notificationSub?.cancel();
    _unreadCountSub?.cancel();
    return super.close();
  }
}
