import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../constants/api_constants.dart';

class NotificationSettingsService {
  final SharedPreferences _prefs;
  final ApiClient _apiClient;

  NotificationSettingsService(this._prefs, this._apiClient);

  // Push Notifications
  Future<bool> requestPushNotificationPermission() async {
    final status = await Permission.notification.request();
    await _prefs.setBool('push_notifications', status.isGranted);
    return status.isGranted;
  }

  Future<bool> getPushNotificationsStatus() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<void> openNotificationSettings() async {
    await openAppSettings();
  }

  // Email Notifications
  Future<void> setEmailNotifications(bool enabled) async {
    await _prefs.setBool('email_notifications', enabled);
  }

  bool getEmailNotificationsStatus() {
    return _prefs.getBool('email_notifications') ?? true;
  }

  // Promotions
  Future<void> setPromotions(bool enabled) async {
    await _prefs.setBool('promotions', enabled);
  }

  bool getPromotionsStatus() {
    return _prefs.getBool('promotions') ?? true;
  }

  // Get all settings
  Map<String, bool> getAllSettings() {
    return {
      'push_notifications': _prefs.getBool('push_notifications') ?? false,
      'email_notifications': _prefs.getBool('email_notifications') ?? true,
      'promotions': _prefs.getBool('promotions') ?? true,
    };
  }

  // Fetch settings from server and cache locally
  Future<void> fetchSettingsFromBackend() async {
    try {
      final response = await _apiClient.get(ApiConstants.userSettings);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final push = _findBool(data, ['pushNotifications', 'pushNotificationsEnabled', 'pushEnabled', 'push'], false);
        final email = _findBool(data, ['emailNotifications', 'emailNotificationsEnabled', 'emailEnabled', 'email'], true);
        final promotions = _findBool(data, ['promotions', 'promotionsEnabled', 'marketing'], true);
        
        await _prefs.setBool('push_notifications', push);
        await _prefs.setBool('email_notifications', email);
        await _prefs.setBool('promotions', promotions);
      }
    } catch (e) {
      print('fetchSettingsFromBackend error: $e');
    }
  }

  // Save settings to server
  Future<void> updateSettingsOnBackend({
    required bool pushEnabled,
    required bool emailEnabled,
    required bool promotionsEnabled,
  }) async {
    final payload = {
      // Send multiple common naming variants so the backend parses correctly
      'pushNotifications': pushEnabled,
      'pushNotificationsEnabled': pushEnabled,
      'pushEnabled': pushEnabled,
      'push': pushEnabled,
      
      'emailNotifications': emailEnabled,
      'emailNotificationsEnabled': emailEnabled,
      'emailEnabled': emailEnabled,
      'email': emailEnabled,
      
      'promotions': promotionsEnabled,
      'promotionsEnabled': promotionsEnabled,
      'marketing': promotionsEnabled,
    };
    
    await _apiClient.put(ApiConstants.userSettings, data: payload);
  }

  bool _findBool(Map<String, dynamic> map, List<String> keys, bool defaultValue) {
    for (final key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        final val = map[key];
        if (val is bool) return val;
        if (val is int) return val == 1;
        if (val is String) {
          final s = val.toLowerCase().trim();
          return s == 'true' || s == '1' || s == 'yes' || s == 'on';
        }
      }
    }
    return defaultValue;
  }
}
