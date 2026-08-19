# Services Setup Guide (Firebase CLI, RevenueCat, OneSignal)

This document provides step-by-step instructions for configuring **Firebase Analytics**, **RevenueCat Subscriptions**, and **OneSignal Push Notifications** in your Fravo app.

---

## 1. Firebase Analytics & Firebase CLI Setup

Fravo is configured with `DefaultFirebaseOptions.currentPlatform` in `lib/firebase_options.dart`.

### Steps to Link Your Live Firebase Console Project:

1. **Log in to Firebase CLI**:
   ```bash
   firebase login
   ```

2. **Run FlutterFire Configure**:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   *or run the automated PowerShell script inside `scripts/configure_firebase.ps1`*:
   ```powershell
   .\scripts\configure_firebase.ps1
   ```

3. Select your Firebase project from the interactive menu. The command will automatically generate/update `lib/firebase_options.dart` and download `google-services.json` (Android) / `GoogleService-Info.plist` (iOS).

### Analytics Logged:
- `paywall_viewed`: Logged when user opens the paywall.
- `purchase_success`: Logged when a user subscribes.
- `step_goal_reached`: Logged when step goals are reached.
- `app_blocked`: Logged when an app blocking event triggers.
- `user_type`: Persistent property set to `premium` or `free`.

---

## 2. RevenueCat (In-App Subscriptions & Paywall)

RevenueCat manages real-time subscription entitlement and paywalls in `lib/services/revenuecat_service.dart`.

### How to Configure Production Keys:

1. Create a project on [RevenueCat Console](https://app.revenuecat.com/).
2. Create an Entitlement named **`premium`**.
3. Create Offerings (e.g. Monthly, Annual, Lifetime).
4. Replace the API key in `lib/services/revenuecat_service.dart`:
   ```dart
   static const String defaultApiKey = 'goog_YOUR_REVENUECAT_PUBLIC_KEY';
   ```
   *or pass it dynamically during app initialization*:
   ```dart
   await AppServices.instance.initialize(
     revenueCatKey: 'goog_YOUR_KEY',
   );
   ```

---

## 3. OneSignal (Push Notifications & User Segmentation)

OneSignal handles push notification delivery and tag segmentation in `lib/services/onesignal_service.dart`.

### How to Configure Production Keys:

1. Create an app on [OneSignal Dashboard](https://dashboard.onesignal.com/).
2. Replace the App ID in `lib/services/onesignal_service.dart`:
   ```dart
   static const String defaultAppId = 'YOUR_ONESIGNAL_APP_ID';
   ```
   *or pass it dynamically during app initialization*:
   ```dart
### Screen Triggers for In-App Messages:
Fravo automatically sets `current_screen` trigger whenever users navigate to:
- `dashboard`
- `settings`
- `stats`
- `paywall`

In OneSignal Dashboard under **Triggers**, set:
> **Show message ONLY when `current_screen` = `dashboard`** (or `settings` / `stats` / `paywall`).

### Deep Linking Support:
When sending Push Notifications or In-App Messages from OneSignal, set **Launch URL** or additional data `deep_link`:
- `fravo://paywall` or `paywall` -> Automatically opens Fravo's Premium Paywall.
- `fravo://settings` or `settings` -> Automatically opens Settings.
- `fravo://stats` or `stats` -> Automatically opens Health Stats.

---

## 4. Google Mobile Ads (AdMob Rewarded Video Ads)

AdMob manages Rewarded Ads for free tier users to claim daily Emergency Passes in `lib/services/admob_service.dart`.

### How to Configure Production Keys:

1. Create an app on [Google AdMob Console](https://admob.google.com/).
2. Create a **Rewarded Video Ad Unit**.
3. Replace the AdMob Application ID in `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data
       android:name="com.google.android.gms.ads.APPLICATION_ID"
       android:value="ca-app-pub-YOUR_ADMOB_APP_ID~XXXXXXXXXX"/>
   ```
4. Replace the Rewarded Ad Unit ID in `lib/services/admob_service.dart`:
   ```dart
   static String get rewardedAdUnitId {
     if (Platform.isAndroid) return 'ca-app-pub-YOUR_ADMOB_REWARDED_UNIT_ID';
     if (Platform.isIOS) return 'ca-app-pub-YOUR_ADMOB_REWARDED_UNIT_ID';
     return '';
   }
   ```
   *Currently configured with official Google Test IDs so development works out-of-the-box!*
