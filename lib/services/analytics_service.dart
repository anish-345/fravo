import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized service for logging analytics events via Firebase Analytics.
class AnalyticsService {
  AnalyticsService._privateConstructor();
  static final AnalyticsService instance = AnalyticsService._privateConstructor();

  FirebaseAnalytics? _analytics;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Initializes Firebase Analytics safely.
  Future<void> init() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      await _analytics?.setAnalyticsCollectionEnabled(true);
      _initialized = true;
      if (kDebugMode) {
        print('[AnalyticsService] Firebase Analytics initialized successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AnalyticsService] Initialized in fallback mode (Firebase not fully configured): $e');
      }
    }
  }

  /// Log a custom event.
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    if (!_initialized || _analytics == null) {
      if (kDebugMode) {
        print('[AnalyticsService Event] $name : $parameters');
      }
      return;
    }
    try {
      await _analytics!.logEvent(name: name, parameters: parameters);
    } catch (e) {
      if (kDebugMode) {
        print('[AnalyticsService] Error logging event $name: $e');
      }
    }
  }

  /// Log screen views for navigation tracking.
  Future<void> logScreenView(String screenName) async {
    await logEvent('screen_view', parameters: {'screen_name': screenName});
  }

  /// Log when user views the Premium Paywall.
  Future<void> logPaywallViewed({String source = 'settings'}) async {
    await logEvent('paywall_viewed', parameters: {'source': source});
  }

  /// Log successful premium subscription purchase.
  Future<void> logPurchaseSuccess({
    required String packageId,
    required double price,
    String currency = 'USD',
  }) async {
    await logEvent('purchase_success', parameters: {
      'package_id': packageId,
      'price': price,
      'currency': currency,
    });
  }

  /// Log step goal completion.
  Future<void> logStepGoalReached(int steps) async {
    await logEvent('step_goal_reached', parameters: {'step_count': steps});
  }

  /// Log app blocking triggered.
  Future<void> logAppBlocked(String packageName) async {
    await logEvent('app_blocked', parameters: {'package_name': packageName});
  }

  /// Log onboarding completion event with survey data.
  Future<void> logOnboardingCompleted({
    required String goal,
    required List<String> blockedApps,
    required int rewardRate,
  }) async {
    await logEvent('onboarding_completed', parameters: {
      'user_goal': goal,
      'blocked_apps_count': blockedApps.length,
      'primary_app': blockedApps.isNotEmpty ? blockedApps.first : 'none',
      'reward_rate_min_per_1k': rewardRate,
    });
    await setUserProfileProperties(
      goal: goal,
      blockedAppsCount: blockedApps.length,
      primaryApp: blockedApps.isNotEmpty ? blockedApps.first : 'none',
    );
  }

  /// Log onboarding step view.
  Future<void> logOnboardingStepViewed(int stepIndex, String stepName) async {
    await logEvent('onboarding_step_viewed', parameters: {
      'step_index': stepIndex,
      'step_name': stepName,
    });
  }

  /// Log onboarding step completed.
  Future<void> logOnboardingStepCompleted(int stepIndex, String stepName) async {
    await logEvent('onboarding_step_completed', parameters: {
      'step_index': stepIndex,
      'step_name': stepName,
    });
  }

  /// Log onboarding drop-off / abandonment.
  Future<void> logOnboardingAbandoned({
    required int lastStepIndex,
    required String reason,
  }) async {
    await logEvent('onboarding_abandoned', parameters: {
      'last_step_index': lastStepIndex,
      'abandon_reason': reason,
    });
  }

  /// Log when user selects a specific subscription plan in the paywall.
  Future<void> logPaywallPlanSelected({
    required String planType,
    required double price,
    String currency = 'USD',
  }) async {
    await logEvent('paywall_plan_selected', parameters: {
      'plan_type': planType,
      'price': price,
      'currency': currency,
    });
  }

  /// Log when user clicks the main CTA on the paywall.
  Future<void> logPaywallCtaClicked({
    required String planType,
    required String source,
  }) async {
    await logEvent('paywall_cta_clicked', parameters: {
      'plan_type': planType,
      'source': source,
    });
  }

  /// Log paywall abandoned / closed without completing a purchase.
  Future<void> logPaywallAbandoned({
    required String source,
    required int timeSpentSeconds,
    required String selectedPlan,
    required bool hadError,
    required int totalAbandons,
  }) async {
    await logEvent('paywall_abandoned', parameters: {
      'source': source,
      'time_spent_seconds': timeSpentSeconds,
      'selected_plan': selectedPlan,
      'had_error': hadError ? 'true' : 'false',
      'total_abandons': totalAbandons,
    });
  }

  /// Log purchase cancelled by user during billing flow.
  Future<void> logPaywallPurchaseCancelled({required String packageId}) async {
    await logEvent('paywall_purchase_cancelled', parameters: {
      'package_id': packageId,
    });
  }

  /// Log purchase failure / payment decline.
  Future<void> logPaywallPurchaseFailed({
    required String packageId,
    required String error,
  }) async {
    await logEvent('paywall_purchase_failed', parameters: {
      'package_id': packageId,
      'error_message': error,
    });
  }

  /// Log permission requested.
  Future<void> logPermissionRequested(String permissionName) async {
    await logEvent('permission_requested', parameters: {
      'permission_name': permissionName,
    });
  }

  /// Log permission granted.
  Future<void> logPermissionGranted(String permissionName) async {
    await logEvent('permission_granted', parameters: {
      'permission_name': permissionName,
    });
  }

  /// Log permission denied / skipped.
  Future<void> logPermissionDenied(String permissionName) async {
    await logEvent('permission_denied', parameters: {
      'permission_name': permissionName,
    });
  }

  /// Log permission revoked in settings.
  Future<void> logPermissionRevoked(String permissionName) async {
    await logEvent('permission_revoked', parameters: {
      'permission_name': permissionName,
    });
  }

  /// Log when user runs out of emergency passes today (churn trigger).
  Future<void> logEmergencyPassExhausted() async {
    await logEvent('emergency_pass_exhausted');
  }

  /// Set unified User ID in Firebase Analytics.
  Future<void> setUserId(String userId) async {
    if (!_initialized || _analytics == null || userId.isEmpty) return;
    try {
      await _analytics!.setUserId(id: userId);
    } catch (e) {
      if (kDebugMode) {
        print('[AnalyticsService] Error setting user ID: $e');
      }
    }
  }

  /// Set user profile properties for Firebase Analytics audience segmentation.
  Future<void> setUserProfileProperties({
    required String goal,
    required int blockedAppsCount,
    required String primaryApp,
  }) async {
    if (!_initialized || _analytics == null) return;
    try {
      await _analytics!.setUserProperty(name: 'user_goal', value: goal);
      await _analytics!.setUserProperty(name: 'blocked_apps_count', value: blockedAppsCount.toString());
      await _analytics!.setUserProperty(name: 'primary_distraction_app', value: primaryApp);
    } catch (e) {
      if (kDebugMode) {
        print('[AnalyticsService] Error setting user profile properties: $e');
      }
    }
  }

  /// Set persistent user properties.
  Future<void> setUserProperties({required bool isPremium}) async {
    if (!_initialized || _analytics == null) return;
    try {
      await _analytics!.setUserProperty(
        name: 'user_type',
        value: isPremium ? 'premium' : 'free',
      );
    } catch (e) {
      if (kDebugMode) {
        print('[AnalyticsService] Error setting user properties: $e');
      }
    }
  }
}
