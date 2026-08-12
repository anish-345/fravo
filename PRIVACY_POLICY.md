# Privacy Policy for Fravo

**Last updated: August 8, 2026**

## 1. Introduction

Fravo ("we", "our", or "us") is a productivity app that converts your daily steps into screen time for selected apps. This Privacy Policy explains what data Fravo accesses, how it is used, and what controls you have over it.

By using Fravo, you agree to the practices described in this policy.

---

## 2. Information We Collect

Fravo is designed to work entirely **on your device**. We do not operate servers, create user accounts, or transmit your personal data to any external service.

### 2.1 Step Count and Physical Activity Data

- **What we access:** Your daily step count, sourced from two places:
  - The device's hardware pedometer (motion sensor)
  - Android Health Connect (step history for the current day)
- **Why:** To calculate how many minutes of screen time you have earned.
- **How it is stored:** Step counts are saved locally on your device using the Hive database library. Data is never uploaded or shared.

### 2.2 App Usage Statistics

- **What we access:** Screen-time usage data for the apps you choose to block (e.g., Instagram, TikTok, YouTube). This requires the "Usage Access" (PACKAGE_USAGE_STATS) permission.
- **Why:** To measure how much of your earned screen time you have consumed and enforce the time limit when it runs out.
- **How it is stored:** Usage data is processed in memory and stored locally on your device. It is never uploaded or shared.

### 2.3 Installed App Information

- **What we access:** The list of installed apps on your device, retrieved via Android's PackageManager and targeted package visibility queries, to let you select which apps to block.
- **Why:** To populate the app selector with apps installed on your device.
- **How it is stored:** This information is used only at the time of selection and is not stored beyond the package names you explicitly choose to block.

### 2.4 Device Information

- **What we access:** Basic device information (via `device_info_plus`) to detect battery optimization settings.
- **Why:** To adapt the step-sync interval and avoid excessive background battery drain.
- **How it is stored:** Not stored. Used at runtime only.

### 2.5 App Blocking Engine

- **Accessibility Service:** Fravo uses an Android Accessibility Service (`AppBlockerAccessibilityService`) that monitors window-state changes to detect when a blocked or time-limited app comes to the foreground. When detected, it displays the block-screen overlay and can terminate the app process.
- **Foreground Service:** A special-use foreground service (`AppBlockerForegroundService`) polls Android's UsageStatsManager every 1.5 seconds (only while the screen is on) to track which app is currently in use and enforce time limits in real time.
- **Process termination:** When a blocked app is opened or its time limit is exhausted, Fravo calls `ActivityManager.killBackgroundProcesses()` to terminate the app and redirect the user to the home screen.
- **How it is stored:** Blocked app lists, time-limit records, and the block-activity log are persisted locally in SQLite. No blocking data is transmitted off-device.

> **Note:** The Accessibility Service must be manually enabled by the user in *Settings → Accessibility → Fravo App Blocker Engine*. No accessibility data — including window content, text, or screen state — is collected, transmitted, or stored. The service only receives window-state-change events to detect app switches.

---

## 3. Permissions Used

| Android Permission | Purpose |
|---|---|
| `ACTIVITY_RECOGNITION` | Access hardware pedometer step count |
| `health.READ_STEPS` | Read step data from Android Health Connect |
| `PACKAGE_USAGE_STATS` | Read screen time for blocked apps |
| `SYSTEM_ALERT_WINDOW` | Display the block screen overlay when a time limit is reached |
| `FOREGROUND_SERVICE` | Keep the blocker running reliably in the background |
| `FOREGROUND_SERVICE_SPECIAL_USE` | Run a special-use foreground service for real-time app usage monitoring (Android 11+) |
| `POST_NOTIFICATIONS` | Show the "Fravo Active" status notification |
| `RECEIVE_BOOT_COMPLETED` | Restart the blocker service after device reboot |
| `KILL_BACKGROUND_PROCESSES` | Terminate blocked apps that are force-opened while the time limit is active |

All permissions are used solely for the features described above. No permission is used to collect, sell, or share your data.

---

## 4. Data Storage and Retention

- **Flutter layer (Hive):** Step counts, earned screen time, used screen time, blocked app list, and reward settings are stored locally using the Hive database library.
- **Native blocking engine (SQLite):** Blocked app lists, daily time-limit records, used seconds, and the block-activity log are stored locally in a SQLite database (`zo_app_blocker.db`). This database is also used by the native Accessibility Service, so it persists and functions even when the Flutter app is not running.
- Data resets automatically at **midnight local time** each day.
- You can delete all stored data by uninstalling the app.
- Fravo does not use cloud storage, remote databases, or any external data service.

---

## 5. Third-Party Services

Fravo does **not** integrate with any third-party analytics, advertising, or data-collection services.

The following open-source packages are used internally; none of them collect or transmit user data:

| Package | Purpose |
|---|---|
| `zo_app_blocker` | Android app blocking via native overlay |
| `health` | Reading steps from Android Health Connect |
| `pedometer` | Accessing the hardware step sensor |
| `permission_handler` | Requesting Android runtime permissions |
| `hive` / `hive_flutter` | Local on-device storage |
| `device_info_plus` | Battery optimization detection |
| `fl_chart`, `shimmer`, `glassmorphism`, `flutter_animate` | UI components only |

---

## 6. Children's Privacy

Fravo does not knowingly collect any personal information from children under the age of 13 (or the applicable age of digital consent in your jurisdiction). Because all data stays on the device and no account registration is required, there is no mechanism by which we would receive such information.

---

## 7. Data Security

Since all data is stored locally on your device, its security depends on the security of your device (screen lock, encryption, etc.). We do not transmit data over a network and therefore there is no server-side data at risk.

---

## 8. Your Rights and Choices

- **Access:** All data Fravo holds is visible within the app itself (step counts, screen time, settings).
- **Deletion:** Uninstalling Fravo removes all locally stored data.
- **Permissions:** You can revoke any permission at any time in your device's **Settings → Apps → Fravo → Permissions**. Revoking a permission will disable the related feature.
- **Health Connect:** You can revoke Fravo's access to Health Connect at any time through the Android Health Connect app.

---

## 9. Changes to This Policy

We may update this Privacy Policy from time to time. Any changes will be reflected in the "Last updated" date at the top of this document. Continued use of the app after an update constitutes acceptance of the revised policy.

---

## 10. Contact Us

If you have any questions or concerns about this Privacy Policy, please contact us at:

**Email:** fravo@avionti.in  
**App:** Fravo  
**Package:** avionti.fravo

---

*This privacy policy applies to the Android version of Fravo.*
