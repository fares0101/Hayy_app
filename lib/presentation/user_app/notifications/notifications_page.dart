import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../../app_router.dart';
import '../../../core/widgets/themed_top_header.dart';
import '../../../data/user_app/models/notification_model.dart';
import '../../../data/user_app/datasources/places_remote_data_source.dart';
import '../../../data/user_app/datasources/business_posts_remote_data_source.dart';
import '../../../injection_container.dart';
import '../booking/screens/select_date_time_screen.dart';
import '../discovery/discovery_list_page.dart';
import 'notifications_bloc.dart';
import 'notifications_state.dart';
import 'notifications_widgets.dart';

class NotificationsPage extends StatefulWidget {
  final ScrollController scrollController;

  const NotificationsPage({super.key, required this.scrollController});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    try {
      final position = widget.scrollController.position;
      if (position.pixels >= position.maxScrollExtent - 180) {
        context.read<NotificationsBloc>().add(LoadMoreNotificationsEvent());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NotificationsBloc, NotificationsState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage &&
          current.errorMessage != null,
      listener: (context, state) {
        final message = state.errorMessage;
        if (message != null && message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      },
      child: Builder(
        builder: (context) {
          final screenHeight = MediaQuery.of(context).size.height;
          final screenWidth = MediaQuery.of(context).size.width;

          return Column(
            children: [
              const ThemedTopHeader(title: 'Notifications'),
              Expanded(
                child: BlocBuilder<NotificationsBloc, NotificationsState>(
                  builder: (context, state) {
                    if (state.isInitialLoading && state.notifications.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state.notifications.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: () async {
                          context
                              .read<NotificationsBloc>()
                              .add(RefreshNotificationsEvent());
                          HapticFeedback.mediumImpact();
                        },
                        child: ListView(
                          controller: widget.scrollController,
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          children: [
                            _buildTopActionsBar(
                              context: context,
                              state: state,
                              screenHeight: screenHeight,
                            ),
                            SizedBox(height: screenHeight * 0.15),
                            const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_active_outlined,
                                    size: 100,
                                    color: Color(0xFFFE5D17),
                                  ),
                                  SizedBox(height: 24),
                                  Text(
                                    'No Notifications',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2E2E2E),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No notifications enabled',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF8A8A8A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final unreadItems =
                        state.notifications.where((n) => !n.isRead).toList();
                    final readItems =
                        state.notifications.where((n) => n.isRead).toList();

                    return RefreshIndicator(
                      onRefresh: () async {
                        context
                            .read<NotificationsBloc>()
                            .add(RefreshNotificationsEvent());
                        HapticFeedback.mediumImpact();
                      },
                      child: ListView(
                        controller: widget.scrollController,
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        children: [
                          _buildTopActionsBar(
                            context: context,
                            state: state,
                            screenHeight: screenHeight,
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          if (unreadItems.isNotEmpty) ...[
                            _buildSectionTitle(
                              title: 'New',
                              screenHeight: screenHeight,
                            ),
                            SizedBox(height: screenHeight * 0.015),
                            ...List.generate(
                              unreadItems.length,
                              (index) => _buildNotificationItem(
                                context: context,
                                notification: unreadItems[index],
                                screenHeight: screenHeight,
                                animationOrder: index,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.02),
                          ],
                          if (readItems.isNotEmpty) ...[
                            _buildSectionTitle(
                              title: 'Earlier',
                              screenHeight: screenHeight,
                            ),
                            SizedBox(height: screenHeight * 0.015),
                            ...List.generate(
                              readItems.length,
                              (index) => _buildNotificationItem(
                                context: context,
                                notification: readItems[index],
                                screenHeight: screenHeight,
                                animationOrder: unreadItems.length + index,
                              ),
                            ),
                          ],
                          if (state.isLoadingMore)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopActionsBar({
    required BuildContext context,
    required NotificationsState state,
    required double screenHeight,
  }) {
    return Row(
      children: [
        if (state.unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFE5D17).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              '${state.unreadCount} unread',
              style: TextStyle(
                color: const Color(0xFFFE5D17),
                fontSize: screenHeight * 0.014,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const Spacer(),
        PopupMenuButton<_NotificationAction>(
          icon: const Icon(Icons.more_vert, color: Colors.black87),
          onSelected: (action) => _onNotificationAction(
            context: context,
            action: action,
            state: state,
          ),
          itemBuilder: (_) => [
            PopupMenuItem<_NotificationAction>(
              value: _NotificationAction.readAll,
              enabled:
                  state.notifications.isNotEmpty && !state.isMarkingAllAsRead,
              child: Row(
                children: [
                  const Icon(Icons.done_all, size: 18),
                  const SizedBox(width: 8),
                  state.isMarkingAllAsRead
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Read all'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _onNotificationAction({
    required BuildContext context,
    required _NotificationAction action,
    required NotificationsState state,
  }) {
    if (action == _NotificationAction.readAll &&
        state.notifications.isNotEmpty &&
        !state.isMarkingAllAsRead) {
      context.read<NotificationsBloc>().add(MarkAllAsReadEvent());
    }
  }

  Widget _buildSectionTitle({
    required String title,
    required double screenHeight,
  }) {
    return Text(
      title,
      style: TextStyle(
        fontSize: screenHeight * 0.02,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildNotificationItem({
    required BuildContext context,
    required NotificationModel notification,
    required double screenHeight,
    required int animationOrder,
  }) {
    final style = _resolveNotificationStyle(notification);
    return NotificationItem(
      icon: style.icon,
      iconColor: style.color,
      cardColor: notification.isRead ? style.readBackground : style.background,
      borderColor: notification.isRead ? style.readBorder : style.border,
      shadowColor: notification.isRead
          ? Colors.black.withValues(alpha: 0.025)
          : style.shadow,
      unreadDotColor: style.color,
      animationOrder: animationOrder,
      title: notification.title,
      body: notification.body,
      time: _formatRelativeTime(notification.createdAt),
      isRead: notification.isRead,
      onTap: () => _onNotificationTapped(context, notification),
      screenHeight: screenHeight,
    );
  }

  void _onNotificationTapped(
      BuildContext context, NotificationModel notification) async {
    if (kDebugMode) {
      debugPrint(
          '[NotificationTap] ${notification.debugSummary()} title="${notification.title}"');
    }

    if (!notification.isRead && notification.id.isNotEmpty) {
      context.read<NotificationsBloc>().add(MarkAsReadEvent(notification.id));
    }

    final postId = notification.postId;
    if (postId != null && postId.isNotEmpty) {
      if (kDebugMode) debugPrint('[NotificationTap] route=POST postId=$postId');
      try {
        final dataSource = sl<BusinessPostsRemoteDataSource>();
        final postMap = await dataSource.getPostById(postId);
        if (kDebugMode) {
          debugPrint(
              '[NotificationTap] getPostById keys=${postMap.keys.toList()}');
        }
        if (!context.mounted) return;
        Navigator.pushNamed(
          context,
          AppRoutes.postDetails,
          arguments: postMap.isNotEmpty ? postMap : postId,
        );
        return;
      } catch (e) {
        if (kDebugMode) debugPrint('[NotificationTap] post flow failed: $e');
      }
      if (context.mounted) {
        Navigator.pushNamed(
          context,
          AppRoutes.postDetails,
          arguments: postId,
        );
        return;
      }
    }

    final eventId = notification.eventId;
    if (eventId != null && eventId.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('[NotificationTap] route=EVENT eventId=$eventId');
      }
      try {
        final dataSource = sl<PlacesRemoteDataSource>();
        final eventMap = await dataSource.getEventById(eventId);
        if (kDebugMode) {
          debugPrint(
              '[NotificationTap] getEventById empty=${eventMap.isEmpty} keys=${eventMap.keys.toList()}');
        }
        if (!context.mounted) return;

        if (eventMap.isNotEmpty) {
          final item = DiscoveryDataMapper.fromEvent(eventMap);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SelectDateTimeScreen(
                eventId: eventId,
                eventTitle: item.title,
                item: item,
              ),
            ),
          );
          return;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[NotificationTap] event flow failed: $e');
      }
    }

    final offerId = notification.offerId;
    if (offerId != null && offerId.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('[NotificationTap] route=OFFER offerId=$offerId');
      }
      Navigator.pushNamed(
        context,
        AppRoutes.offerDetails,
        arguments: offerId,
      );
      return;
    }

    final targetId = notification.placeId ?? notification.targetId;
    if (targetId == null || targetId.isEmpty) {
      if (kDebugMode) {
        debugPrint(
            '[NotificationTap] NO ROUTE - missing ids for "${notification.title}"');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open this notification')),
        );
      }
      return;
    }
    if (kDebugMode) {
      debugPrint('[NotificationTap] route=PLACE placeId=$targetId');
    }
    Navigator.pushNamed(
      context,
      AppRoutes.placeDetails,
      arguments: targetId,
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final localDate = dateTime.toLocal();
    var difference = now.difference(localDate);

    if (difference.isNegative) {
      difference = Duration.zero;
    }

    if (difference.inSeconds < 30) {
      return 'Just now';
    }
    if (difference.inMinutes < 1) {
      final secs = difference.inSeconds;
      return '$secs ${secs == 1 ? "sec" : "secs"} ago';
    }
    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? "min" : "mins"} ago';
    }
    if (difference.inHours < 24) {
      final hrs = difference.inHours;
      return '$hrs ${hrs == 1 ? "hour" : "hours"} ago';
    }
    if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? "day" : "days"} ago';
    }
    if (difference.inDays < 30) {
      final weeks = difference.inDays ~/ 7;
      return '$weeks ${weeks == 1 ? "week" : "weeks"} ago';
    }
    if (difference.inDays < 365) {
      final months = difference.inDays ~/ 30;
      return '$months ${months == 1 ? "month" : "months"} ago';
    }

    final years = difference.inDays ~/ 365;
    return '$years ${years == 1 ? "year" : "years"} ago';
  }

  _NotificationStyle _resolveNotificationStyle(NotificationModel notification) {
    final type = notification.type.toLowerCase();
    final text =
        '${notification.title} ${notification.body} $type'.toLowerCase();

    if (notification.eventId?.isNotEmpty == true ||
        type.contains('event') ||
        type.contains('booking') ||
        type.contains('ticket')) {
      return _NotificationStyle.fromAccent(
        icon: Icons.event_available_rounded,
        color: const Color(0xFF6B3FA0),
      );
    }

    if (notification.offerId?.isNotEmpty == true || type.contains('offer')) {
      return _NotificationStyle.fromAccent(
        icon: Icons.local_offer_rounded,
        color: const Color(0xFF2E8B57),
      );
    }

    if (text.contains('cafe') ||
        text.contains('cafes') ||
        text.contains('coffee') ||
        text.contains('كافيه') ||
        text.contains('كوفي')) {
      return _NotificationStyle.fromAccent(
        icon: Icons.coffee_rounded,
        color: const Color(0xFF7B4F2E),
      );
    }

    if (notification.placeId?.isNotEmpty == true ||
        type.contains('place') ||
        type.contains('business') ||
        type.contains('post') ||
        type.contains('restaurant') ||
        text.contains('restaurant') ||
        text.contains('مطعم')) {
      return _NotificationStyle.fromAccent(
        icon: Icons.restaurant_rounded,
        color: const Color(0xFFFF641A),
      );
    }

    if (type.contains('review') || type.contains('like')) {
      return _NotificationStyle.fromAccent(
        icon: Icons.star_rounded,
        color: const Color(0xFFFFB800),
      );
    }

    return _NotificationStyle.fromAccent(
      icon: Icons.notifications_rounded,
      color: const Color(0xFFFE6A1C),
    );
  }
}

enum _NotificationAction { readAll }

class _NotificationStyle {
  final IconData icon;
  final Color color;
  final Color background;
  final Color readBackground;
  final Color border;
  final Color readBorder;
  final Color shadow;

  const _NotificationStyle({
    required this.icon,
    required this.color,
    required this.background,
    required this.readBackground,
    required this.border,
    required this.readBorder,
    required this.shadow,
  });

  factory _NotificationStyle.fromAccent({
    required IconData icon,
    required Color color,
  }) {
    return _NotificationStyle(
      icon: icon,
      color: color,
      background: color.withValues(alpha: 0.095),
      readBackground: color.withValues(alpha: 0.045),
      border: color.withValues(alpha: 0.18),
      readBorder: color.withValues(alpha: 0.10),
      shadow: color.withValues(alpha: 0.06),
    );
  }
}
