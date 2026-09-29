import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:hive_flutter/hive_flutter.dart';

import '../firebase_options.dart';
import 'admob_service.dart';
import 'analytics_service.dart';
import 'blocker_service.dart';
import 'growth_service.dart';
import 'onesignal_service.dart';
import 'revenuecat_service.dart';
import 'time_bank.dart';

/// Centralized service manager responsible for initializing Firebase, RevenueCat,
/// OneSignal, and Google Mobile Ads gracefully during app launch.
class AppServices {
  AppServices._privateConstructor();
  static final AppServices instance = AppServices._privateConstructor();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Custom credentials configuration — replace or supply via environment / options
  String? firebaseProjectId;
  String? revenueCatApiKey;
  String? oneSignalAppId;

  /// Main initialization sequence.
  Future<void> initialize({
    String? revenueCatKey,
    String? oneSignalId,
  }) async {
    if (_initialized) return;

    if (revenueCatKey != null) revenueCatApiKey = revenueCatKey;
    if (oneSignalId != null) oneSignalAppId = oneSignalId;

    // 1. Initialize Firebase Core
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (kDebugMode) {
        print('[AppServices] Firebase Core initialized successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AppServices] Firebase Core init exception (operating with fallback options): $e');
      }
    }

    // 2. Initialize Analytics
    await AnalyticsService.instance.init();

    // 3. Initialize RevenueCat (Subscriptions)
    await RevenueCatService.instance.init(apiKey: revenueCatApiKey);

    // 4. Initialize OneSignal (Push Notifications)
    await OneSignalService.instance.init(appId: oneSignalAppId);

    // 5. Initialize AdMob (Google Mobile Ads) — with UMP consent gate.
    // Per Google policy, user consent must be collected before initializing ads
    // for users in EEA/UK (GDPR). The UMP SDK handles this automatically.
    await AdMobService.instance.initWithConsent();

    // 6. Sync full user profile & initial survey answers across Analytics & OneSignal
    await syncFullUserProfile();

    _initialized = true;
    if (kDebugMode) {
      print('[AppServices] All App Services initialized cleanly.');
    }
  }

  /// Sync complete user profile based on initial questions, settings, and subscription state
  /// across Firebase Analytics and OneSignal.
  Future<void> syncFullUserProfile() async {
    try {
      final timeBank = TimeBankService.instance;
      final isPremium = RevenueCatService.instance.isPremium;

      final goal = timeBank.selectedGoal;
      final stepGoal = timeBank.customStepGoal;
      final rewardRate = timeBank.minutesPer1kSteps;
      final blockedApps = timeBank.blockedPackageNames;
      final primaryApp = timeBank.displayNameFor(timeBank.currentAppBlockingTarget);

      // 1. Sync to Firebase Analytics User Properties
      await AnalyticsService.instance.setUserProfileProperties(
        goal: goal,
        blockedAppsCount: blockedApps.length,
        primaryApp: primaryApp,
      );
      await AnalyticsService.instance.setUserProperties(isPremium: isPremium);

      // Capture current timestamp once to prevent drift across calculations
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      // Calculate days since installation
      final box = Hive.box('time_bank');
      final firstLaunchMs = (box.get('first_launch_timestamp') as int?) ?? nowMs;
      if (!box.containsKey('first_launch_timestamp')) {
        await box.put('first_launch_timestamp', firstLaunchMs);
      }
      final daysInstalled = (now.difference(DateTime.fromMillisecondsSinceEpoch(firstLaunchMs)).inDays).clamp(0, 9999);

      // 2. Batch Sync to OneSignal User Tags for Segmentation
      final permissions = await BlockerService.instance.checkPermissionsStatus();
      final missing = <String>[];
      permissions.forEach((key, isGranted) {
        if (!isGranted) missing.add(key);
      });

      final streak = timeBank.currentStreakDays;
      final lastActiveMs = (box.get('last_active_timestamp') as int?) ?? nowMs;
      final daysInactive = (now.difference(DateTime.fromMillisecondsSinceEpoch(lastActiveMs)).inDays).clamp(0, 999);
      await box.put('last_active_timestamp', nowMs);

      String risk = 'low';
      if (daysInactive >= 5) {
        risk = 'critical';
      } else if (daysInactive >= 2) {
        risk = 'high';
      } else if (daysInactive == 1) {
        risk = 'medium';
      }

      final paywallAbandonCount = (box.get('paywall_abandon_count', defaultValue: 0) as int).toString();
      final hasHighAbandonIntent = int.tryParse(paywallAbandonCount) != null && int.parse(paywallAbandonCount) > 0;

      await OneSignalService.instance.setUserTags({
        'my_referral_code': GrowthService.instance.referralCode,
        'is_premium': isPremium ? 'true' : 'false',
        'subscription_active': RevenueCatService.instance.isPurchasedPremium ? 'true' : 'false',
        'user_goal': goal,
        'blocked_apps_count': blockedApps.length.toString(),
        'primary_distraction': primaryApp,
        'reward_rate_min': rewardRate.toString(),
        'step_goal': stepGoal.toString(),
        'days_since_installed': daysInstalled.toString(),
        'permissions_healthy': missing.isEmpty ? 'true' : 'false',
        'missing_permissions': missing.isEmpty ? 'none' : missing.join(','),
        'current_streak': streak.toString(),
        'days_inactive': daysInactive.toString(),
        'churn_risk': risk,
        'paywall_abandon_count': paywallAbandonCount,
        'user_profile': '${isPremium ? "vip" : "free"}|apps:${blockedApps.length}|goal:${goal.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}|step:$stepGoal',
        'behavior_state': 'stage:active|churn:$risk|pw_ab:$paywallAbandonCount|pw_intent:${hasHighAbandonIntent ? "high" : "low"}|perm:${missing.isEmpty ? "ok" : "missing"}',
      });

      if (kDebugMode) {
        print('[AppServices] User profile, permissions & churn risk batch-synced to OneSignal.');
      }

      // 3. Sync live referral count from backend
      await GrowthService.instance.syncReferralStatsWithServer();
    } catch (e) {
      if (kDebugMode) {
        print('[AppServices] Sync user profile error: $e');
      }
    }
  }
}
