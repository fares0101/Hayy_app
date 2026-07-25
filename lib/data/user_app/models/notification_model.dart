import 'package:flutter/foundation.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String type;
  final String? targetId;
  final String? placeId;
  final String? postId;
  final String? eventId;
  final String? offerId;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    required this.type,
    this.targetId,
    this.placeId,
    this.postId,
    this.eventId,
    this.offerId,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    bool? isRead,
    String? type,
    String? targetId,
    String? placeId,
    String? postId,
    String? eventId,
    String? offerId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
      placeId: placeId ?? this.placeId,
      postId: postId ?? this.postId,
      eventId: eventId ?? this.eventId,
      offerId: offerId ?? this.offerId,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final normalizedJson = _normalizeJsonKeys(json);

    final title = _readString(
          normalizedJson,
          keys: const ['title', 'notificationTitle', 'subject'],
        ) ??
        'Notification';
    final body = _readString(
          normalizedJson,
          keys: const ['body', 'message', 'description', 'content'],
        ) ??
        '';

    final explicitEventId = _readString(normalizedJson, keys: const ['eventId', 'eventID', 'event_id']);
    final explicitOfferId = _readString(normalizedJson, keys: const ['offerId', 'offerID', 'offer_id']);
    final explicitPostId = _readString(normalizedJson, keys: const ['postId', 'postID', 'post_id']);
    final explicitBookingId = _readString(normalizedJson, keys: const ['bookingId', 'bookingID', 'booking_id']);
    final explicitPlaceId = _readString(
          normalizedJson,
          keys: const [
            'placeId',
            'placeID',
            'place_id',
            'businessId',
            'businessID',
            'business_id',
            'restaurantId',
            'restaurantID',
          ],
        ) ??
        _extractNestedPlaceId(normalizedJson);

    final rawTypeValue = normalizedJson['type'] ??
        normalizedJson['notificationType'] ??
        normalizedJson['category'] ??
        normalizedJson['targetType'];
    final typeCode = _parseTypeCode(rawTypeValue);
    final rawType = rawTypeValue?.toString().toLowerCase() ?? '';

    final refType = _readString(
          normalizedJson,
          keys: const ['referenceType', 'referencetype', 'targetType', 'entityType'],
        )?.toLowerCase() ??
        '';
    final refId = _readString(
      normalizedJson,
      keys: const ['referenceId', 'referenceid', 'targetId', 'targetid', 'entityId'],
    );

    String resolvedType = 'general';
    String? targetId = refId;

    if (refType.contains('post')) {
      resolvedType = 'post';
    } else if (refType.contains('event')) {
      resolvedType = 'event';
    } else if (refType.contains('offer')) {
      resolvedType = 'offer';
    } else if (refType.contains('place') ||
        refType.contains('business') ||
        refType.contains('restaurant')) {
      resolvedType = 'place';
    } else if (refType.contains('booking') || refType.contains('ticket')) {
      resolvedType = 'booking';
    } else if (explicitPostId != null && explicitPostId.isNotEmpty) {
      resolvedType = 'post';
      targetId = explicitPostId;
    } else if (explicitEventId != null && explicitEventId.isNotEmpty) {
      resolvedType = 'event';
      targetId = explicitEventId;
    } else if (explicitOfferId != null && explicitOfferId.isNotEmpty) {
      resolvedType = 'offer';
      targetId = explicitOfferId;
    } else if (explicitBookingId != null && explicitBookingId.isNotEmpty) {
      resolvedType = 'booking';
      targetId = explicitBookingId;
    } else if (typeCode != null) {
      resolvedType = _typeFromCode(typeCode);
      targetId = targetId ?? _extractTargetIdForType(normalizedJson, resolvedType);
    } else if (explicitPlaceId != null && explicitPlaceId.isNotEmpty) {
      resolvedType = 'place';
      targetId = explicitPlaceId;
    } else {
      resolvedType = _normalizeNotificationType(rawType);
      targetId = targetId ?? _extractTargetIdForType(normalizedJson, resolvedType);
    }

    final normalizedPostId = explicitPostId ?? (resolvedType == 'post' ? targetId : null);
    final normalizedEventId = explicitEventId ?? (resolvedType == 'event' ? targetId : null);
    final normalizedOfferId = explicitOfferId ?? (resolvedType == 'offer' ? targetId : null);

    final model = NotificationModel(
      id: _readString(
            normalizedJson,
            keys: const ['id', 'notificationId', 'notificationID'],
          ) ??
          '',
      title: title,
      body: body,
      createdAt: _extractDateTime(
            normalizedJson,
            keys: const ['createdAt', 'creationTime', 'time', 'date'],
          ) ??
          DateTime.now(),
      isRead: _extractBool(
            normalizedJson,
            keys: const ['isRead', 'read'],
          ) ??
          false,
      type: resolvedType,
      targetId: targetId,
      placeId: explicitPlaceId,
      postId: normalizedPostId,
      eventId: normalizedEventId,
      offerId: normalizedOfferId,
    );

    if (kDebugMode) {
      debugPrint(
        '[NotificationModel] parsed title="$title" type=$resolvedType '
        'postId=$normalizedPostId eventId=$normalizedEventId offerId=$normalizedOfferId '
        'placeId=$explicitPlaceId targetId=$targetId rawType=$rawType typeCode=$typeCode '
        'keys=${normalizedJson.keys.toList()}',
      );
    }

    return model;
  }

  String debugSummary() {
    return 'type=$type postId=$postId eventId=$eventId offerId=$offerId '
        'placeId=$placeId targetId=$targetId';
  }

  static int? _parseTypeCode(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String _typeFromCode(int code) {
    switch (code) {
      case 1:
        return 'event';
      case 2:
        return 'offer';
      case 3:
        return 'post';
      case 4:
        return 'place';
      case 5:
        return 'booking';
      default:
        return 'general';
    }
  }

  static Map<String, dynamic> _normalizeJsonKeys(Map<String, dynamic> json) {
    final normalized = <String, dynamic>{};
    json.forEach((key, value) {
      normalized[_normalizeKey(key)] = _normalizeValue(value);
    });
    return normalized;
  }

  static dynamic _normalizeValue(dynamic value) {
    if (value is Map) {
      return _normalizeJsonKeys(Map<String, dynamic>.from(value));
    }
    if (value is List) {
      return value.map(_normalizeValue).toList();
    }
    return value;
  }

  static String _normalizeKey(String key) {
    if (key.isEmpty) return key;
    final lower = key.toLowerCase();
    if (lower == 'post_id') return 'postId';
    if (lower == 'event_id') return 'eventId';
    if (lower == 'offer_id') return 'offerId';
    if (lower == 'place_id') return 'placeId';
    if (lower == 'booking_id') return 'bookingId';
    if (lower == 'target_id') return 'targetId';
    if (lower == 'reference_id') return 'referenceId';
    if (lower == 'entity_id') return 'entityId';
    if (lower == 'notificationtype') return 'notificationType';
    if (lower == 'relatedid') return 'relatedId';
    return key[0].toLowerCase() + key.substring(1);
  }

  static String? _readString(
    Map<String, dynamic> json, {
    required List<String> keys,
  }) {
    return _extractString(json, keys: keys);
  }

  static String _normalizeNotificationType(String rawType) {
    if (rawType.contains('post')) return 'post';
    if (rawType.contains('event')) return 'event';
    if (rawType.contains('offer')) return 'offer';
    if (rawType.contains('booking') || rawType.contains('ticket')) {
      return 'booking';
    }
    if (rawType.contains('place') || rawType.contains('business')) {
      return 'place';
    }
    return rawType.isNotEmpty ? rawType : 'general';
  }

  static String? _extractTargetIdForType(
    Map<String, dynamic> json,
    String resolvedType,
  ) {
    switch (resolvedType) {
      case 'offer':
        return _extractString(
          json,
          keys: const [
            'offerId',
            'offerID',
            'offer_id',
            'targetId',
            'targetID',
            'target_id',
            'referenceId',
            'referenceID',
            'reference_id',
            'relatedId',
            'relatedID',
            'related_id',
            'entityId',
            'entityID',
            'entity_id',
          ],
        );
      case 'event':
        return _extractString(
          json,
          keys: const [
            'eventId',
            'eventID',
            'event_id',
            'targetId',
            'targetID',
            'target_id',
            'referenceId',
            'referenceID',
            'reference_id',
            'relatedId',
            'relatedID',
            'related_id',
            'entityId',
            'entityID',
            'entity_id',
          ],
        );
      case 'post':
        return _extractString(
          json,
          keys: const [
            'postId',
            'postID',
            'post_id',
            'targetId',
            'targetID',
            'target_id',
            'referenceId',
            'referenceID',
            'reference_id',
            'relatedId',
            'relatedID',
            'related_id',
            'entityId',
            'entityID',
            'entity_id',
          ],
        );
      case 'booking':
        return _extractString(
          json,
          keys: const [
            'bookingId',
            'bookingID',
            'booking_id',
            'targetId',
            'targetID',
            'target_id',
            'referenceId',
            'referenceID',
            'reference_id',
          ],
        );
      case 'place':
        return _extractString(
          json,
          keys: const [
            'placeId',
            'placeID',
            'place_id',
            'businessId',
            'businessID',
            'business_id',
            'targetId',
            'targetID',
            'target_id',
            'referenceId',
            'referenceID',
            'reference_id',
          ],
        );
      default:
        return _extractString(
          json,
          keys: const [
            'targetId',
            'targetID',
            'target_id',
            'referenceId',
            'referenceID',
            'reference_id',
            'relatedId',
            'relatedID',
            'related_id',
            'entityId',
            'entityID',
            'entity_id',
            'sourceId',
            'sourceID',
            'source_id',
            'placeId',
            'placeID',
            'place_id',
            'postId',
            'postID',
            'post_id',
            'eventId',
            'eventID',
            'event_id',
            'offerId',
            'offerID',
            'offer_id',
          ],
        );
    }
  }

  static String? _extractNestedPlaceId(Map<String, dynamic> json) {
    for (final parentKey in ['place', 'business', 'author', 'user', 'data', 'payload', 'extra', 'details', 'result', 'value']) {
      final parent = json[parentKey];
      if (parent is Map) {
        final map = Map<String, dynamic>.from(parent);
        for (final idKey in ['placeId', 'placeID', 'place_id', 'businessId', 'businessID', 'business_id', 'id']) {
          final val = map[idKey];
          if (val != null) {
            final text = val.toString().trim();
            if (text.isNotEmpty && text != 'null') {
              return text;
            }
          }
        }
      }
    }
    return null;
  }

  static String? _extractString(
    Map<String, dynamic> json, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty && text != 'null') {
          return text;
        }
      }
    }

    // Check nested objects (data, payload, extra, details, result, value)
    for (final nestedKey in ['data', 'payload', 'extra', 'details', 'result', 'value']) {
      final nested = json[nestedKey];
      if (nested is Map) {
        final nestedMap = Map<String, dynamic>.from(nested);
        for (final key in keys) {
          final value = nestedMap[key];
          if (value != null) {
            final text = value.toString().trim();
            if (text.isNotEmpty && text != 'null') {
              return text;
            }
          }
        }
      }
    }

    return null;
  }

  static bool? _extractBool(
    Map<String, dynamic> json, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) {
        return value;
      }
      if (value is int) {
        return value == 1;
      }
      if (value is String) {
        final normalized = value.toLowerCase();
        if (normalized == 'true' || normalized == '1') {
          return true;
        }
        if (normalized == 'false' || normalized == '0') {
          return false;
        }
      }
    }
    return null;
  }

  static DateTime? _extractDateTime(
    Map<String, dynamic> json, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.isNotEmpty) {
        // Parse UTC timezone properly
        final text = value.trim();
        final hasTimezone = text.endsWith('Z') ||
            RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(text);
        DateTime? parsed;
        if (hasTimezone) {
          parsed = DateTime.tryParse(text);
        } else {
          String normalized = text;
          if (normalized.contains(' ')) {
            normalized = normalized.replaceAll(' ', 'T');
          }
          if (normalized.contains(':')) {
            normalized = '${normalized}Z';
          }
          parsed = DateTime.tryParse(normalized) ?? DateTime.tryParse(text);
        }
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }
}

class NotificationsPageResult {
  final List<NotificationModel> items;
  final int? totalCount;

  const NotificationsPageResult({
    required this.items,
    required this.totalCount,
  });
}
