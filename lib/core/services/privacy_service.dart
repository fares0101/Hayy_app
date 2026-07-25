import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class PrivacyService {
  final SharedPreferences _prefs;

  PrivacyService(this._prefs);

  // Location Access
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    await _prefs.setBool('location_access', status.isGranted);
    return status.isGranted;
  }

  Future<bool> getLocationPermissionStatus() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  Future<void> openLocationSettings() async {
    await openAppSettings();
  }

  // Private Profile
  Future<void> setPrivateProfile(bool isPrivate) async {
    await _prefs.setBool('private_profile', isPrivate);
    // TODO: Send to backend API
    // await _apiService.updatePrivacySettings(isPrivate: isPrivate);
  }

  bool getPrivateProfileStatus() {
    return _prefs.getBool('private_profile') ?? false;
  }

  // Connected Devices
  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? '';
    }
    return '';
  }

  Future<void> saveCurrentDevice() async {
    final deviceId = await getDeviceId();
    final devices = getConnectedDevices();
    if (!devices.contains(deviceId)) {
      devices.add(deviceId);
      await _prefs.setStringList('connected_devices', devices);
    }
  }

  List<String> getConnectedDevices() {
    return _prefs.getStringList('connected_devices') ?? [];
  }

  Future<void> setAllowMultipleDevices(bool allow) async {
    await _prefs.setBool('allow_multiple_devices', allow);
    if (!allow) {
      final currentDevice = await getDeviceId();
      await _prefs.setStringList('connected_devices', [currentDevice]);
    }
    // TODO: Send to backend to manage sessions
    // await _apiService.updateDeviceSettings(allowMultiple: allow);
  }

  bool getAllowMultipleDevices() {
    return _prefs.getBool('allow_multiple_devices') ?? true;
  }
}
