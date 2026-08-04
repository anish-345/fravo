import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'zo_app_blocker_platform_interface.dart';

class MethodChannelZoAppBlocker extends ZoAppBlockerPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('zo_app_blocker');

  @override
  Future<String> checkUsageStatsPermission() async {
    final result = await methodChannel.invokeMethod<String>('checkUsageStatsPermission');
    return result ?? 'denied';
  }

  @override
  Future<void> requestUsageStatsPermission() async {
    await methodChannel.invokeMethod<void>('requestUsageStatsPermission');
  }

  @override
  Future<String> checkOverlayPermission() async {
    final result = await methodChannel.invokeMethod<String>('checkOverlayPermission');
    return result ?? 'denied';
  }

  @override
  Future<void> requestOverlayPermission() async {
    await methodChannel.invokeMethod<void>('requestOverlayPermission');
  }

  @override
  Future<String> checkNotificationPermission() async {
    final result = await methodChannel.invokeMethod<String>('checkNotificationPermission');
    return result ?? 'denied';
  }

  @override
  Future<void> requestNotificationPermission() async {
    await methodChannel.invokeMethod<void>('requestNotificationPermission');
  }

  @override
  Future<List<Map<String, dynamic>>> getApps() async {
    final List<dynamic>? result = await methodChannel.invokeMethod('getApps');
    if (result == null) return [];
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<List<int>?> getAppIcon(String packageName) async {
    try {
      final result = await methodChannel.invokeMethod('getAppIcon', {
        'packageName': packageName,
      });
      if (result == null) return null;
      return (result as List<dynamic>).cast<int>();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getBlockedApps() async {
    final List<dynamic>? result = await methodChannel.invokeMethod(
      'getBlockedApps',
    );
    if (result == null) return [];
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> blockApps(List<String> identifiers) async {
    await methodChannel.invokeMethod<void>('blockApps', {
      'identifiers': identifiers,
    });
  }

  @override
  Future<void> unblockApps(List<String> identifiers) async {
    await methodChannel.invokeMethod<void>('unblockApps', {
      'identifiers': identifiers,
    });
  }

  @override
  Future<void> blockAll() async {
    await methodChannel.invokeMethod('blockAll');
  }

  @override
  Future<void> unblockAll() async {
    await methodChannel.invokeMethod('unblockAll');
  }

  @override
  Future<void> setNotificationConfig(Map<String, String> config) async {
    await methodChannel.invokeMethod('setNotificationConfig', config);
  }

  @override
  Future<void> saveBlockScreenCallbackHandle(int rawHandle) async {
    await methodChannel.invokeMethod('saveBlockScreenCallbackHandle', {
      'rawHandle': rawHandle,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getBlockActivityLog() async {
    final List<dynamic>? result = await methodChannel.invokeMethod(
      'getBlockActivityLog',
    );
    if (result == null) return [];
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> clearBlockActivityLog() async {
    await methodChannel.invokeMethod('clearBlockActivityLog');
  }

  // ---------------------------------------------------------------------------
  // Time Limit API
  // ---------------------------------------------------------------------------

  @override
  Future<void> setAppTimeLimit({
    required String packageName,
    required int dailyLimitMinutes,
  }) async {
    await methodChannel.invokeMethod<void>('setAppTimeLimit', {
      'packageName': packageName,
      'dailyLimitMinutes': dailyLimitMinutes,
    });
  }

  @override
  Future<void> removeAppTimeLimit(String packageName) async {
    await methodChannel.invokeMethod<void>('removeAppTimeLimit', {
      'packageName': packageName,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getAppTimeLimits() async {
    final List<dynamic>? result = await methodChannel.invokeMethod(
      'getAppTimeLimits',
    );
    if (result == null) return [];
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> resetAppUsage(String packageName) async {
    await methodChannel.invokeMethod<void>('resetAppUsage', {
      'packageName': packageName,
    });
  }
}
