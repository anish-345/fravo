# zo_app_blocker

[![Pub Version](https://img.shields.io/pub/v/zo_app_blocker?color=blue)](https://pub.dev/packages/zo_app_blocker)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](https://opensource.org/licenses/MIT)

<img width="400" height="690" alt="WhatsAppVideo2026-06-04at1 03 41PM-ezgif com-optimize" src="https://github.com/user-attachments/assets/5fef55b0-f10e-406a-a1e1-4158827e7181" />


A Flutter plugin to block specific applications on Android.

Under the hood, it leverages Android's `UsageStatsManager` and `ForegroundService`. This ensures that the app blocking mechanism remains persistent and active, even if the user swipes your Flutter app away from their recent apps list.

> **Note:** This package currently supports **Android only**.

---

## Features

* **Targeted Blocking:** Specify exactly which installed applications should be blocked from launching.
* **Persistent Execution:** Utilizes a Foreground Service to ensure the background blocking process is not killed by the system.
* **App Discovery:** Easily fetch a list of all installed applications on the device.

## Get Started

Add `zo_app_blocker` to your `pubspec.yaml`:

```yaml
dependencies:
  zo_app_blocker: ^latest_version
```

Or install it via the command line:

```bash
flutter pub add zo_app_blocker
```

## Setup & Permissions (Android)

To get this plugin working, several Android permissions need to be handled.

### 1. AndroidManifest.xml

Ensure you add the following permissions to your app's `android/app/src/main/AndroidManifest.xml` file, directly inside the `<manifest>` tag:

```xml
    <!-- Allows querying installed packages -->
    <uses-permission
        android:name="android.permission.QUERY_ALL_PACKAGES"
        tools:ignore="QueryAllPackagesPermission" />

    <!-- Required for the background monitoring service -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
    
    <!-- Required to show notifications on Android 13+ -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

```

### 2. Notification Permission (Android 13+)

If you're targeting Android 13 (API level 33) or higher, you must ask the user for permission to show notifications before you can start the background service. You can use the plugin's built-in methods:

```dart
import 'package:zo_app_blocker/zo_app_blocker.dart';

Future<void> handleNotificationPermission() async {
  final status = await ZoAppBlocker.instance.checkNotificationPermission();
  if (status != 'granted') {
    await ZoAppBlocker.instance.requestNotificationPermission();
  }
}
```

### 3. Usage Stats and Overlay Permissions

For the plugin to actually detect when a blocked app is opened and draw the custom block screen over it, the user has to grant "Usage Access" and "Display over other apps". You can check the status and prompt them to open settings like this:

```dart
import 'package:zo_app_blocker/zo_app_blocker.dart';

// ...

final usageStatus = await ZoAppBlocker.instance.checkUsageStatsPermission();
if (usageStatus == 'denied') {
  await ZoAppBlocker.instance.requestUsageStatsPermission(); // Takes them to Usage Access settings
}

final overlayStatus = await ZoAppBlocker.instance.checkOverlayPermission();
if (overlayStatus == 'denied') {
  await ZoAppBlocker.instance.requestOverlayPermission(); // Takes them to Display over other apps settings
}
```

## Usage

### 1. Custom Block Screen (Headless Flutter Overlay)

You can build a fully custom block screen using Flutter widgets. Since the background service runs in a separate headless Flutter isolate, you must register a **top-level or static function** annotated with `@pragma('vm:entry-point')` at app startup.

#### 1. Define the custom entrypoint function:

```dart
import 'package:flutter/material.dart';
import 'package:zo_app_blocker/zo_app_blocker.dart';

@pragma('vm:entry-point')
void onBlockScreenRequested() {
  ZoBlockScreenRunner.run(
    builder: (context) {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (context.appIcon != null)
                Image.memory(context.appIcon!, width: 100, height: 100),
              const SizedBox(height: 24),
              Text(
                '${context.appName ?? 'App'} is Blocked!',
                style: const TextStyle(color: Colors.white, fontSize: 24),
              ),
              const SizedBox(height: 48),
              // Dismiss button
              ElevatedButton(
                onPressed: context.onDismiss,
                child: const Text('Exit'),
              ),
              const SizedBox(height: 16),
              // Unlock button for the current session
              OutlinedButton(
                onPressed: () async {
                  final granted = await context.onRequestTemporarySessionUnlock?.call() ?? false;
                  if (granted) {
                    // Temporarily unlocked for this session!
                  }
                },
                child: const Text('Unlock for this session (50 coins)'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
```

#### 2. Initialize the plugin at startup (e.g., in `main()`):

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  ZoAppBlocker.instance.initialize(
    blockScreenCallback: onBlockScreenRequested,
  );
  
  runApp(const MyApp());
}
```

### 2. Configure Background Notification

You can customize the background service notification to let the user know their apps are being monitored.

```dart
import 'package:zo_app_blocker/zo_app_blocker.dart';

// ...

await ZoAppBlocker.instance.setNotificationConfig(
  notificationBannerTitle: 'Focus Mode Active', 
  notificationBannerDescription: 'Monitoring your apps in the background.',
  // notificationIcon: 'ic_launcher', // Optional custom icon name in drawable/mipmap
);
```

### 3. Get a list of installed apps

If you need to show the user a list of apps they can block, you can fetch all installed apps:

```dart
import 'package:zo_app_blocker/zo_app_blocker.dart';

// ...

final installedApps = await ZoAppBlocker.instance.getApps();
// Returns a list containing maps, e.g.:
// [{"packageName": "com.facebook.katana", "appName": "Facebook"}, ...]
```

### 4. Start blocking

Just pass a list of package names to the plugin. Once you call this, the Foreground Service starts up automatically.

```dart
import 'package:zo_app_blocker/zo_app_blocker.dart';

// ...

await ZoAppBlocker.instance.blockApps([
  'com.instagram.android',
  'com.facebook.katana',
]);
```

### 5. Unblock apps

You can remove specific apps from the blocklist, or just unblock everything (which also stops the background service).

```dart
import 'package:zo_app_blocker/zo_app_blocker.dart';

// ...

// Unblock specific ones
await ZoAppBlocker.instance.unblockApps(['com.facebook.katana']);

// Unblock everything and stop the service
await ZoAppBlocker.instance.unblockAll();
```

### 6. Get App Icon

Retrieve the PNG-encoded icon bytes for a specific package:

```dart
import 'dart:typed_data';
import 'package:zo_app_blocker/zo_app_blocker.dart';

Uint8List? iconBytes = await ZoAppBlocker.instance.getAppIcon('com.instagram.android');
if (iconBytes != null) {
  // Render via Image.memory(iconBytes)
}
```

### 7. Block Activity Log

Monitor block events in your application by retrieving the activity log:

```dart
// Get the list of recorded block events
List<Map<String, dynamic>> log = await ZoAppBlocker.instance.getBlockActivityLog();
// Returns [{"packageName": "com.instagram.android", "timestamp": 1716612345678}]

// Clear the activity log
await ZoAppBlocker.instance.clearBlockActivityLog();
```

### 8. Set Daily Time Limit

You can set a daily usage time limit for a specific application. Once the user has spent the specified number of minutes in the app, it will be automatically blocked for the rest of the day.

```dart
import 'package:zo_app_blocker/zo_app_blocker.dart';

// Set a limit of 50 minutes per day for an app
await ZoAppBlocker.instance.setAppTimeLimit(
  packageName: 'com.instagram.android',
  dailyLimitMinutes: 50,
);

// Get all configured limits and their current usage
final limits = await ZoAppBlocker.instance.getAppTimeLimits();
for (final limit in limits) {
  print('${limit.packageName}: ${limit.remainingMinutes} min left');
}

// Reset today's usage counter for an app to zero
await ZoAppBlocker.instance.resetAppUsage('com.instagram.android');

// Remove the daily time limit for an app
await ZoAppBlocker.instance.removeAppTimeLimit('com.instagram.android');
```

---

Feel free to post a feature requests or report a bug [issues](https://github.com/Oauth-Celestial/zo_app_blocker/issues).

## My Other packages

* [zo_animated_border](https://pub.dev/packages/zo_animated_border): A package that provides a modern way to create gradient borders with animation in Flutter

* [zo_micro_interactions](https://pub.dev/packages/zo_micro_interactions): A curated set of high-quality Flutter micro-interactions designed for modern, polished apps.
* [zo_screenshot](https://pub.dev/packages/zo_screenshot): The zo_screenshot plugin helps restrict screenshots and screen recording in Flutter apps, enhancing security and privacy by preventing unauthorized screen captures.
* [zo_collection_animation](https://pub.dev/packages/zo_collection_animation): A lightweight Flutter package to create smooth collect animations for coins carts
* [connectivity_watcher](https://pub.dev/packages/connectivity_watcher): A Flutter package to monitor internet connectivity with subsecond response times, even on mobile networks.
* [ultimate_extension](https://pub.dev/packages/ultimate_extension): Enhances Dart collections and objects with utilities for advanced data manipulation and simpler coding.
* [theme_manager_plus](https://pub.dev/packages/theme_manager_plus): Allows customization of your app's theme with your own theme class, eliminating the need for traditional
* [date_util_plus](https://pub.dev/packages/date_util_plus): A powerful Dart API designed to augment and simplify date and time handling in your Dart projects.
* [pick_color](https://pub.dev/packages/pick_color): A Flutter package that allows you to extract colors and hex codes from images with a simple touch.
