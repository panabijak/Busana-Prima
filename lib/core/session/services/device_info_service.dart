import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

/// Service for retrieving device information and generating unique device IDs
class DeviceInfoService {
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  final Uuid _uuid = const Uuid();

  /// Get a unique device identifier
  /// Uses platform-specific identifiers when available, falls back to UUID
  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        // Use ANDROID_ID which persists across app reinstalls
        final androidId = androidInfo.id;
        if (androidId.isNotEmpty && androidId != '9774d56d682e549c') {
          return 'android_$androidId';
        }
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        // Use identifierForVendor which persists across app reinstalls
        final vendorId = iosInfo.identifierForVendor;
        if (vendorId != null && vendorId.isNotEmpty) {
          return 'ios_$vendorId';
        }
      }
    } catch (e) {
      // Fall through to UUID generation
    }

    // Fallback: Generate and store a UUID
    return await _getOrCreateUuid();
  }

  /// Get or create a persistent UUID for this device
  Future<String> _getOrCreateUuid() async {
    // In a real implementation, you would store this in secure storage
    // For simplicity, we'll generate a deterministic UUID based on device info
    final deviceInfo = await getDeviceInfo();
    final uniqueString =
        '${deviceInfo['platform']}_${deviceInfo['deviceModel']}_${deviceInfo['deviceId']}';
    return 'uuid_${_uuid.v5(Uuid.NAMESPACE_URL, uniqueString)}';
  }

  /// Get comprehensive device information
  Future<Map<String, dynamic>> getDeviceInfo() async {
    final deviceId = await getDeviceId();
    final packageInfo = await PackageInfo.fromPlatform();

    Map<String, dynamic> baseInfo = {
      'deviceId': deviceId,
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
      'appVersion': packageInfo.version,
      'appBuildNumber': packageInfo.buildNumber,
      'appName': packageInfo.appName,
      'packageName': packageInfo.packageName,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        baseInfo.addAll({
          'deviceModel': androidInfo.model,
          'deviceBrand': androidInfo.brand,
          'deviceManufacturer': androidInfo.manufacturer,
          'deviceProduct': androidInfo.product,
          'deviceBoard': androidInfo.board,
          'deviceHardware': androidInfo.hardware,
          'androidVersion': androidInfo.version.release,
          'androidSdkInt': androidInfo.version.sdkInt,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
        });
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        baseInfo.addAll({
          'deviceModel': iosInfo.model,
          'deviceName': iosInfo.name,
          'deviceSystemName': iosInfo.systemName,
          'deviceSystemVersion': iosInfo.systemVersion,
          'deviceUtsname': iosInfo.utsname.machine,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
        });
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfoPlugin.windowsInfo;
        baseInfo.addAll({
          'deviceModel': windowsInfo.computerName,
          'deviceProductName': windowsInfo.productName,
          'deviceDisplayVersion': windowsInfo.displayVersion,
          'deviceBuildNumber': windowsInfo.buildNumber,
        });
      }
    } catch (e) {
      // Continue with basic info if detailed info fails
    }

    return baseInfo;
  }

  /// Get a user-friendly device name
  Future<String> getDeviceName() async {
    final deviceInfo = await getDeviceInfo();

    if (Platform.isAndroid) {
      final brand = deviceInfo['deviceBrand'] ?? '';
      final model = deviceInfo['deviceModel'] ?? '';
      return '$brand $model'.trim();
    } else if (Platform.isIOS) {
      final name = deviceInfo['deviceName'] ?? '';
      final model = deviceInfo['deviceModel'] ?? '';
      return name.isNotEmpty ? name : model;
    } else if (Platform.isWindows) {
      return deviceInfo['deviceModel'] ?? 'Windows Device';
    }

    return 'Unknown Device';
  }

  /// Check if this is the same device as before (for session restoration)
  Future<bool> isSameDevice(String storedDeviceId) async {
    final currentDeviceId = await getDeviceId();
    return currentDeviceId == storedDeviceId;
  }
}
