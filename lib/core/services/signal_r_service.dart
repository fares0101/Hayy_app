import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../storage/user_session_manager.dart';
import '../constants/api_constants.dart';
import '../../data/user_app/models/notification_model.dart';

class SignalRService {
  final UserSessionManager _sessionManager;
  HubConnection? _hubConnection;
  
  // Streams for notifications, unread count, and new business posts
  final _notificationController = StreamController<NotificationModel>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();
  final _postController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<NotificationModel> get notificationStream => _notificationController.stream;
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  Stream<Map<String, dynamic>> get postStream => _postController.stream;

  bool _isConnecting = false;

  SignalRService(this._sessionManager);

  /// Initializes and starts the SignalR connection if a valid user token exists.
  Future<void> connect() async {
    if (_isConnecting) return;
    
    final token = _sessionManager.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('SignalR: Cannot connect, no auth token found.');
      return;
    }

    _isConnecting = true;

    try {
      const hubUrl = '${ApiConstants.baseUrl}/notificationHub';
      debugPrint('SignalR: Connecting to $hubUrl');

      final options = HttpConnectionOptions(
        accessTokenFactory: () async => token,
        // Configure transport to prefer WebSockets
        transport: HttpTransportType.WebSockets,
      );

      _hubConnection = HubConnectionBuilder()
          .withUrl(hubUrl, options: options)
          .withAutomaticReconnect()
          .build();

      // Listen for connection states
      _hubConnection?.onclose(({error}) {
        debugPrint('SignalR: Connection closed. Error: $error');
      });

      _hubConnection?.onreconnecting(({error}) {
        debugPrint('SignalR: Reconnecting... Error: $error');
      });

      _hubConnection?.onreconnected(({connectionId}) {
        debugPrint('SignalR: Reconnected successfully! Connection ID: $connectionId');
      });

      // Register server events
      _registerHubEvents();

      // Start the connection
      await _hubConnection?.start();
      debugPrint('SignalR: Connected successfully! Status: ${_hubConnection?.state}');
    } catch (e) {
      debugPrint('SignalR: Connection failed: $e');
    } finally {
      _isConnecting = false;
    }
  }

  /// Disconnects from the SignalR Hub.
  Future<void> disconnect() async {
    if (_hubConnection != null) {
      debugPrint('SignalR: Disconnecting...');
      await _hubConnection?.stop();
      _hubConnection = null;
    }
  }

  /// Registers hub handlers for events sent from the server.
  void _registerHubEvents() {
    // Helper to extract Map payload from arguments
    Map<String, dynamic>? extractMap(List<dynamic>? args) {
      if (args == null || args.isEmpty) return null;
      final first = args.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
      if (first is String && first.trim().startsWith('{')) {
        try {
          final decoded = jsonDecode(first);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      return null;
    }

    // 1. Event: ReceiveNotification (New notification received)
    _hubConnection?.on('ReceiveNotification', (arguments) {
      debugPrint('SignalR Event [ReceiveNotification] received arguments: $arguments');
      final map = extractMap(arguments);
      if (map == null) return;

      try {
        final notification = NotificationModel.fromJson(map);
        _notificationController.add(notification);
        // Push event to postController so HomePage updates feed immediately!
        _postController.add(map);
      } catch (e) {
        debugPrint('SignalR: Error parsing received notification: $e');
        _postController.add(map);
      }
    });

    // 2. Event: UnreadCountUpdated (Update unread notifications badge)
    _hubConnection?.on('UnreadCountUpdated', (arguments) {
      debugPrint('SignalR Event [UnreadCountUpdated] received arguments: $arguments');
      if (arguments == null || arguments.isEmpty) return;

      try {
        final rawCount = arguments.first;
        if (rawCount is int) {
          _unreadCountController.add(rawCount);
        } else if (rawCount is String) {
          final count = int.tryParse(rawCount);
          if (count != null) {
            _unreadCountController.add(count);
          }
        }
      } catch (e) {
        debugPrint('SignalR: Error parsing unread count: $e');
      }
    });

    // 3. Fallback/Standard generic notification message handler if backend uses different name
    _hubConnection?.on('ReceiveMessage', (arguments) {
      debugPrint('SignalR Event [ReceiveMessage] received: $arguments');
      final map = extractMap(arguments);
      if (map != null) {
        _postController.add(map);
      }
    });

    // 4. Event: ReceivePost / NewPost / PostCreated etc.
    final postEvents = [
      'ReceivePost',
      'NewPost',
      'PostCreated',
      'OnPostCreated',
      'ReceiveBusinessPost',
      'ReceiveNewPost',
      'PostAdded',
      'OnNewPost',
      'CreatePost',
      'PublishPost',
      'PostPublished',
      'OnPostPublished',
      'NewBusinessPost',
      'BusinessPostCreated',
    ];

    for (final eventName in postEvents) {
      _hubConnection?.on(eventName, (arguments) {
        debugPrint('SignalR Event [$eventName] received arguments: $arguments');
        final map = extractMap(arguments);
        if (map != null) {
          _postController.add(map);
        }
      });
    }
  }

  /// Manually invoke a hub method if client-to-server calls are ever needed.
  Future<void> sendNotificationReadAck(String notificationId) async {
    if (_hubConnection?.state == HubConnectionState.Connected) {
      try {
        await _hubConnection?.invoke('MarkAsRead', args: [notificationId]);
        debugPrint('SignalR: Sent MarkAsRead ack for $notificationId');
      } catch (e) {
        debugPrint('SignalR: Failed to send read ack: $e');
      }
    }
  }

  void dispose() {
    disconnect();
    _notificationController.close();
    _unreadCountController.close();
    _postController.close();
  }
}
