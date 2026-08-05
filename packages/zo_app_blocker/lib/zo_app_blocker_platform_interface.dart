import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'zo_app_blocker_method_channel.dart';

abstract class ZoAppBlockerPlatform extends PlatformInterface {
  ZoAppBlockerPlatform() : super(token: _token);

  static final Object _token = Object();

  static ZoAppBlockerPlatform _instance = MethodChannelZoAppBlocker();

  static ZoAppBlockerPlatform get instance => _instance;

  static set instance(ZoAppBlockerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String> checkUsageStatsPermission() {
    throw UnimplementedError('checkUsageStatsPermission() has not been implemented.');
  }

  Future<void> requestUsageStatsPermission() {
    throw UnimplementedError('requestUsageStatsPermission() has not been implemented.');
  }

  Future<String> checkAccessibilityPermission() {
    throw UnimplementedError('checkAccessibilityPermission() has not been implemented.');
  }

  Future<void> requestAccessibilityPermission() {
    throw UnimplementedError('requestAccessibilityPermission() has not been implemented.');
  }

  Future<String> checkOverlayPermission() {
    throw UnimplementedError('checkOverlayPermission() has not been implemented.');
  }

  Future<void> requestOverlayPermission() {
    throw UnimplementedError('requestOverlayPermission() has not been implemented.');
  }

  Future<String> checkNotificationPermission() {
    throw UnimplementedError('checkNotificationPermission() has not been implemented.');
  }

  Future<void> requestNotificationPermission() {
    throw UnimplementedError('requestNotificationPermission() has not been implemented.');
  }

  Future<List<Map<String, dynamic>>> getApps() {
    throw UnimplementedError('getApps() has not been implemented.');
  }

  Future<List<int>?> getAppIcon(String packageName) {
    throw UnimplementedError('getAppIcon() has not been implemented.');
  }

  Future<List<Map<String, dynamic>>> getBlockedApps() {
    throw UnimplementedError('getBlockedApps() has not been implemented.');
  }

  Future<void> blockApps(List<String> identifiers) {
    throw UnimplementedError('blockApps() has not been implemented.');
  }

  Future<void> unblockApps(List<String> identifiers) {
    throw UnimplementedError('unblockApps() has not been implemented.');
  }

  Future<void> blockAll() {
    throw UnimplementedError('blockAll() has not been implemented.');
  }

  Future<void> unblockAll() {
    throw UnimplementedError('unblockAll() has not been implemented.');
  }

  Future<void> setNotificationConfig(Map<String, String> config) {
    throw UnimplementedError(
      'setNotificationConfig() has not been implemented.',
    );
  }

  /// Saves the callback handle for the block screen Dart entrypoint.
  ///
  /// The [rawHandle] is obtained via `PluginUtilities.getCallbackHandle()`
  /// and is persisted on the native side so the background service can boot
  /// a FlutterEngine with the correct entrypoint when a blocked app is detected.
  Future<void> saveBlockScreenCallbackHandle(int rawHandle) {
    throw UnimplementedError(
      'saveBlockScreenCallbackHandle() has not been implemented.',
    );
  }

  Future<List<Map<String, dynamic>>> getBlockActivityLog() {
    throw UnimplementedError('getBlockActivityLog() has not been implemented.');
  }

  Future<void> clearBlockActivityLog() {
    throw UnimplementedError('clearBlockActivityLog() has not been implemented.');
  }

  // ---------------------------------------------------------------------------
  // Time Limit API
  // ---------------------------------------------------------------------------

  Future<void> setAppTimeLimit({
    required String packageName,
    required int dailyLimitMinutes,
  }) {
    throw UnimplementedError('setAppTimeLimit() has not been implemented.');
  }

  Future<void> removeAppTimeLimit(String packageName) {
    throw UnimplementedError('removeAppTimeLimit() has not been implemented.');
  }

  Future<List<Map<String, dynamic>>> getAppTimeLimits() {
    throw UnimplementedError('getAppTimeLimits() has not been implemented.');
  }

  Future<void> resetAppUsage(String packageName) {
    throw UnimplementedError('resetAppUsage() has not been implemented.');
  }
}
