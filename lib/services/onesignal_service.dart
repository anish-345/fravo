import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'growth_service.dart';

/// Service managing OneSignal push notifications and user segment tagging.
class OneSignalService {
  OneSignalService._privateConstructor();
  static final OneSignalService instance = OneSignalService._privateConstructor();

  /// OneSignal App ID
  static const String defaultAppId = 'c2f353c7-1bfe-45b1-83e3-c3b6d2b6fcc2';

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize OneSignal SDK.
  Future<void> init({String? appId}) async {
    final appIdToUse = (appId != null && appId.isNotEmpty) ? appId : defaultAppId;

    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      // Initialize SDK
      OneSignal.initialize(appIdToUse);

      // Handle notification click listener with Deep Link routing
      OneSignal.Notifications.addClickListener((event) {
        if (kDebugMode) {
          print('[OneSignalService] Notification Clicked: ${event.notification.title}');
        }
        final launchUrl = event.notification.launchUrl;
        final additionalData = event.notification.additionalData;
        if (additionalData != null && additionalData['action'] == 'referral_increment') {
          GrowthService.instance.incrementReferralCount();
        }
        _handleDeepLink(launchUrl: launchUrl, additionalData: additionalData);
      });

      // Handle In-App Message click listener with Deep Link routing
      OneSignal.InAppMessages.addClickListener((event) {
        if (kDebugMode) {
          print('[OneSignalService] In-App Clicked: ${event.result.url}');
        }
        _handleDeepLink(launchUrl: event.result.url);
      });

      // Handle foreground notification received — ensure notification shows even when app is open
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        if (kDebugMode) {
          print('[OneSignalService] Foreground Notification Received: ${event.notification.title}');
        }
        final additionalData = event.notification.additionalData;
        if (additionalData != null && additionalData['action'] == 'referral_increment') {
          GrowthService.instance.incrementReferralCount();
        }
        event.notification.display();
      });

      // Notification permissions are requested progressively during onboarding or in settings
      // rather than popping up a system dialog before the app UI even renders.

      _initialized = true;
      if (kDebugMode) {
        print('[OneSignalService] Initialized successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[OneSignalService] Initialized in fallback mode: $e');
      }
    }
  }

  /// Sets screen trigger tag so In-App Messages can target specific screens.
  void setScreenTrigger(String screenName) {
    try {
      OneSignal.InAppMessages.addTrigger('current_screen', screenName);
      if (kDebugMode) {
        print('[OneSignalService] Set screen trigger: current_screen=$screenName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[OneSignalService] Error setting screen trigger: $e');
      }
    }
  }

  /// Sets permission health trigger for In-App Messaging alerts.
  void setPermissionsTrigger({required bool healthy, required String missingKey}) {
    try {
      OneSignal.InAppMessages.addTrigger('permissions_healthy', healthy ? 'true' : 'false');
      OneSignal.InAppMessages.addTrigger('missing_permission', missingKey);
      if (kDebugMode) {
        print('[OneSignalService] Set permissions trigger: healthy=$healthy, missing=$missingKey');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[OneSignalService] Error setting permission trigger: $e');
      }
    }
  }

  /// Sets step milestone trigger for In-App celebration popups.
  void setStepMilestoneTrigger(int steps) {
    try {
      final milestone = (steps ~/ 1000) * 1000;
      OneSignal.InAppMessages.addTrigger('step_milestone', milestone.toString());
    } catch (_) {}
  }

  /// Sets streak milestone trigger for In-App referral prompts.
  void setStreakMilestoneTrigger(int streak) {
    try {
      OneSignal.InAppMessages.addTrigger('streak_milestone', streak.toString());
    } catch (_) {}
  }

  /// Sets screen time depleted trigger.
  void setTimeDepletedTrigger(bool isDepleted) {
    try {
      OneSignal.InAppMessages.addTrigger('time_depleted', isDepleted ? 'true' : 'false');
    } catch (_) {}
  }

  /// Parse deep links and navigate directly to target screens.
  /// Supported values: `paywall`, `settings`, `stats` or `fravo://paywall`, `fravo://settings`, `fravo://stats`
  void _handleDeepLink({String? launchUrl, Map<String, dynamic>? additionalData}) {
    String? target;

    if (launchUrl != null && launchUrl.isNotEmpty) {
      target = launchUrl.replaceAll('fravo://', '').trim();
    } else if (additionalData != null) {
      target = (additionalData['deep_link'] ?? additionalData['screen'] ?? additionalData['target'])?.toString();
    }

    if (target == null || target.isEmpty) return;

    onDeepLinkTriggered?.call(target.toLowerCase());
  }

  /// Callback registered by main app router to navigate on deep links.
  void Function(String screen)? onDeepLinkTriggered;

  /// Request push notification permissions explicitly from user.
  Future<bool> requestNotificationPermission() async {
    try {
      return await OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      if (kDebugMode) {
        print('[OneSignalService] Request permission error: $e');
      }
      return false;
    }
  }

  /// Log in external User ID across OneSignal.
  Future<void> loginUser(String externalUserId) async {
    if (!_initialized || externalUserId.isEmpty) return;
    try {
      OneSignal.login(externalUserId);
      if (kDebugMode) {
        print('[OneSignalService] Logged in user: $externalUserId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[OneSignalService] Login user error: $e');
      }
    }
  }

  /// Set multiple user tags in a single batch request.
  Future<void> setUserTags(Map<String, String> tags) async {
    if (!_initialized) return;
    try {
      OneSignal.User.addTags(tags);
      if (kDebugMode) {
        print('[OneSignalService] Batch tags synced: $tags');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[OneSignalService] Error setting batch tags: $e');
      }
    }
  }

  /// Set user tag for segmentation (e.g. `is_premium`, `step_goal`).
  Future<void> setUserTag(String key, String value) async {
    if (!_initialized) return;
    try {
      OneSignal.User.addTags({key: value});
      if (kDebugMode) {
        print('[OneSignalService] Tag synced: $key=$value');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[OneSignalService] Error setting tag $key=$value: $e');
      }
    }
  }

  /// Set subscription tag for premium status.
  Future<void> setPremiumStatus(bool isPremium) async {
    await setUserTag('is_premium', isPremium ? 'true' : 'false');
  }

  /// Set user daily step goal tag.
  Future<void> setStepGoalTag(int stepGoal) async {
    await setUserTag('step_goal', stepGoal.toString());
  }

  /// Sync packed user profile to stay within OneSignal Free Tier tag limits.
  Future<void> syncPackedProfile({
    required bool isPremium,
    required String goal,
    required int blockedAppsCount,
    required int stepGoal,
  }) async {
    final cleanGoal = goal.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final packed = '${isPremium ? "vip" : "free"}|apps:$blockedAppsCount|goal:$cleanGoal|step:$stepGoal';
    await setUserTag('user_profile', packed);
    await setUserTag('is_premium', isPremium ? 'true' : 'false');
  }

  /// Sync packed behavioral state to stay within OneSignal Free Tier tag limits.
  Future<void> syncPackedBehavior({
    required String stage,
    required String churnRisk,
    required int paywallAbandons,
    required String paywallIntent,
    required bool permissionsHealthy,
  }) async {
    final packed = 'stage:$stage|churn:$churnRisk|pw_ab:$paywallAbandons|pw_intent:$paywallIntent|perm:${permissionsHealthy ? "ok" : "missing"}';
    await setUserTag('behavior_state', packed);
  }

  /// Sync onboarding profile answers to OneSignal for segmented notification sending.
  Future<void> syncOnboardingUserProfile({
    required String goal,
    required List<String> blockedApps,
    required String primaryAppName,
    required int rewardRate,
  }) async {
    await setUserTag('user_goal', goal);
    await setUserTag('blocked_apps_count', blockedApps.length.toString());
    await setUserTag('primary_distraction', primaryAppName);
    await setUserTag('reward_rate_min', rewardRate.toString());
    await setUserTag('onboarding_completed', 'true');
    await setUserTag('journey_stage', 'active_user');

    await syncPackedProfile(
      isPremium: false,
      goal: goal,
      blockedAppsCount: blockedApps.length,
      stepGoal: 10000,
    );
  }

  /// Update user's current funnel / onboarding journey stage.
  Future<void> setJourneyStage(String stage) async {
    await setUserTag('journey_stage', stage);
  }

  /// Record a paywall abandonment event for behavioral retargeting.
  Future<void> recordPaywallAbandoned({
    required String source,
    required String planType,
    required int timeSpentSeconds,
    required int totalAbandons,
  }) async {
    await setUserTag('paywall_abandon_count', totalAbandons.toString());
    await setUserTag('last_paywall_abandon_source', source);
    await setUserTag('last_paywall_tier_viewed', planType);
    
    // Intent calculation: >15s or plan clicked is high intent
    final String intent = timeSpentSeconds >= 15 ? 'high' : (timeSpentSeconds >= 5 ? 'medium' : 'low');
    await setUserTag('paywall_intent_level', intent);

    await syncPackedBehavior(
      stage: 'active',
      churnRisk: 'low',
      paywallAbandons: totalAbandons,
      paywallIntent: intent,
      permissionsHealthy: true,
    );
  }

  /// Reset paywall abandon counters on successful purchase.
  Future<void> recordPaywallPurchased() async {
    await setUserTag('paywall_abandon_count', '0');
    await setUserTag('is_premium', 'true');
    await setUserTag('journey_stage', 'paying_vip');
    await syncPackedProfile(
      isPremium: true,
      goal: 'vip',
      blockedAppsCount: 99,
      stepGoal: 10000,
    );
  }

  /// Tag missing permissions so OneSignal can send setup reminders.
  Future<void> setMissingPermissions(List<String> missingPermissions) async {
    if (missingPermissions.isEmpty) {
      await setUserTag('permissions_healthy', 'true');
      await setUserTag('missing_permissions', 'none');
    } else {
      await setUserTag('permissions_healthy', 'false');
      await setUserTag('missing_permissions', missingPermissions.join(','));
    }
  }

  /// Tag churn risk based on days inactive and broken streaks.
  Future<void> setActivityRisk({
    required int daysInactive,
    required int streak,
  }) async {
    await setUserTag('current_streak', streak.toString());
    await setUserTag('days_inactive', daysInactive.toString());
    
    String risk = 'low';
    if (daysInactive >= 5) {
      risk = 'critical';
    } else if (daysInactive >= 2) {
      risk = 'high';
    } else if (daysInactive == 1) {
      risk = 'medium';
    }
    await setUserTag('churn_risk', risk);
  }
}
