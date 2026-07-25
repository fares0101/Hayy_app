import 'package:flutter/foundation.dart';
import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/notification_model.dart';

class NotificationsRemoteDataSource {
  final ApiClient apiClient;

  NotificationsRemoteDataSource(this.apiClient);

  Future<NotificationsPageResult> getNotifications({
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    final response = await apiClient.get(
      ApiConstants.notifications,
      queryParameters: {
        'pageNumber': pageNumber,
        'pageSize': pageSize,
      },
    );

    final responseMap = _toMap(response.data);
    final container = _extractContainer(responseMap);
    final rawItems = _extractItems(container);
    if (kDebugMode) {
      debugPrint('[NotificationsAPI] raw items count=${rawItems.length}');
      for (var i = 0; i < rawItems.length && i < 5; i++) {
        final item = rawItems[i];
        if (item is Map) {
          debugPrint('[NotificationsAPI] item[$i]=${jsonEncode(item)}');
        }
      }
    }
    final items = rawItems
        .whereType<Map>()
        .map((item) => NotificationModel.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();
    final totalCount = _extractInt(
      container,
      keys: const ['totalCount', 'count', 'total'],
    );

    return NotificationsPageResult(items: items, totalCount: totalCount);
  }

  Future<int> getUnreadCount() async {
    final response = await apiClient.get(ApiConstants.notificationsUnreadCount);

    final data = response.data;
    if (data is int) {
      return data;
    }
    if (data is String) {
      return int.tryParse(data) ?? 0;
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final container = _extractContainer(map);
      final count = _extractInt(
        container,
        keys: const ['unreadCount', 'count', 'totalUnread', 'value'],
      );
      if (count != null) {
        return count;
      }
      final nestedData = container['data'];
      if (nestedData is int) {
        return nestedData;
      }
      if (nestedData is String) {
        return int.tryParse(nestedData) ?? 0;
      }
    }

    return 0;
  }

  Future<void> markAsRead(String notificationId) async {
    await apiClient.patch(
      ApiConstants.notificationMarkAsRead.replaceAll('{id}', notificationId),
    );
  }

  Future<void> markAllAsRead() async {
    await apiClient.patch(ApiConstants.notificationsMarkAllAsRead);
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{'items': data is List ? data : <dynamic>[]};
  }

  Map<String, dynamic> _extractContainer(Map<String, dynamic> map) {
    final keys = ['data', 'result'];
    for (final key in keys) {
      final nested = map[key];
      if (nested is Map) {
        return Map<String, dynamic>.from(nested);
      }
    }
    return map;
  }

  List<dynamic> _extractItems(Map<String, dynamic> container) {
    final keys = ['items', 'notifications', 'results', 'data', 'result', 'value'];
    for (final key in keys) {
      final value = container[key];
      if (value is List) {
        return value;
      }
    }
    return const <dynamic>[];
  }

  int? _extractInt(
    Map<String, dynamic> map, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) {
        return value;
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }
}
