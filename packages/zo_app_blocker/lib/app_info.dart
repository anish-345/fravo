import 'dart:typed_data';

/// A model representing an application installed on the device or a category
/// of applications.
class AppInfo {
  /// The human-readable name of the application (e.g., 'Facebook').
  final String appName;

  /// The unique identifier of the application.
  /// On Android, this is the package name (e.g., 'com.facebook.katana').
  /// On iOS, this might be a unique opaque token.
  final String packageName;

  /// An optional byte array containing the application's icon.
  final Uint8List? icon;

  /// Creates a new [AppInfo] instance.
  AppInfo({
    required this.appName,
    required this.packageName,
    this.icon,
  });

  /// Creates an [AppInfo] from a map.
  factory AppInfo.fromMap(Map<dynamic, dynamic> map) {
    return AppInfo(
      appName: map['appName'] as String,
      packageName: map['packageName'] as String,
      icon: map['icon'] as Uint8List?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appName': appName,
      'packageName': packageName,
      'icon': icon,
    };
  }
}
