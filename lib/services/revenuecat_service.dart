import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'analytics_service.dart';
import 'onesignal_service.dart';

/// Service managing RevenueCat subscriptions and premium entitlement.
class RevenueCatService {
  RevenueCatService._privateConstructor();
  static final RevenueCatService instance = RevenueCatService._privateConstructor();

  /// RevenueCat Public API Key (Google Play)
  static const String defaultApiKey = 'goog_aioHPpILjdjdqSJNZSERkYiGkqp';
  static const String entitlementId = 'premium';
  static const String _hiveKey = 'is_premium_cached';
  static const String _referralTrialExpiryKey = 'referral_premium_trial_expiry_ms';

  final ValueNotifier<bool> isPremiumNotifier = ValueNotifier<bool>(false);
  bool _initialized = false;
  bool _isPurchasedActive = false;

  bool get isInitialized => _initialized;

  /// Whether user has an active purchased subscription via RevenueCat.
  bool get isPurchasedPremium => _isPurchasedActive;

  /// Whether user currently has an active 7-day referral trial.
  bool get isReferralTrialActive {
    try {
      final box = Hive.box('time_bank');
      final expiryMs = box.get(_referralTrialExpiryKey) as int?;
      if (expiryMs == null) return false;
      return DateTime.now().millisecondsSinceEpoch < expiryMs;
    } catch (_) {
      return false;
    }
  }

  /// Days remaining in the 7-day referral trial.
  int get referralTrialRemainingDays {
    try {
      final box = Hive.box('time_bank');
      final expiryMs = box.get(_referralTrialExpiryKey) as int?;
      if (expiryMs == null) return 0;
      final diff = DateTime.fromMillisecondsSinceEpoch(expiryMs).difference(DateTime.now());
      if (diff.isNegative) return 0;
      return diff.inDays + 1;
    } catch (_) {
      return 0;
    }
  }

  /// Combined status: true if user has a purchased subscription OR an active 7-day trial.
  /// If the 7-day trial expires and no subscription is purchased, automatically resets to false (Free).
  bool get isPremium => _isPurchasedActive || isReferralTrialActive;

  /// Activates a 7-day Free Fravo Premium Trial (e.g. upon redeeming an invite code).
  Future<void> activate7DayReferralTrial() async {
    try {
      final box = Hive.box('time_bank');
      final expiryMs = DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;
      await box.put(_referralTrialExpiryKey, expiryMs);
      _recalculateAndNotify();
    } catch (e) {
      if (kDebugMode) {
        print('[RevenueCatService] Activate trial error: $e');
      }
    }
  }

  /// Initialize RevenueCat SDK with customer update listeners and Hive cache.
  Future<void> init({String? apiKey}) async {
    // Read cached state from Hive first for instantaneous UI rendering
    try {
      final box = Hive.box('time_bank');
      final cachedPremium = box.get(_hiveKey, defaultValue: false) as bool;
      isPremiumNotifier.value = cachedPremium || isReferralTrialActive;
    } catch (_) {}

    final keyToUse = (apiKey != null && apiKey.isNotEmpty) ? apiKey : defaultApiKey;

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      PurchasesConfiguration configuration = PurchasesConfiguration(keyToUse);
      await Purchases.configure(configuration);

      // Add customer info update listener
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updateEntitlementStatus(customerInfo);
      });

      // Initial check
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      _updateEntitlementStatus(customerInfo);

      _initialized = true;
      if (kDebugMode) {
        print('[RevenueCatService] Initialized successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[RevenueCatService] Initialized in offline fallback mode: $e');
      }
      _recalculateAndNotify();
    }
  }

  void _updateEntitlementStatus(CustomerInfo info) {
    final entitlement = info.entitlements.all[entitlementId] ??
        info.entitlements.all['Fravo Pro'] ??
        info.entitlements.all['fravo_pro'] ??
        info.entitlements.active.values.firstOrNull;
    _isPurchasedActive = entitlement != null && entitlement.isActive;

    _recalculateAndNotify();

    // Cross-connect RevenueCat Customer User ID to Analytics & OneSignal
    final userId = info.originalAppUserId;
    if (userId.isNotEmpty) {
      AnalyticsService.instance.setUserId(userId);
      OneSignalService.instance.loginUser(userId);
    }
  }

  void _recalculateAndNotify() {
    final effectivePremium = isPremium;
    isPremiumNotifier.value = effectivePremium;

    // Cache in Hive
    try {
      final box = Hive.box('time_bank');
      box.put(_hiveKey, effectivePremium);
    } catch (_) {}

    AnalyticsService.instance.setUserProperties(isPremium: effectivePremium);
    OneSignalService.instance.setPremiumStatus(effectivePremium);
    OneSignalService.instance.setUserTag('subscription_active', _isPurchasedActive ? 'true' : 'false');
    OneSignalService.instance.setUserTag('referral_trial_active', isReferralTrialActive ? 'true' : 'false');
  }

  /// Fetch active offerings from RevenueCat console.
  Future<Offerings?> getOfferings() async {
    if (!_initialized) return null;
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      if (kDebugMode) {
        print('[RevenueCatService] Error fetching offerings: $e');
      }
      return null;
    }
  }

  /// Purchase a package (Monthly, Yearly, Lifetime, etc.).
  Future<bool> purchasePackage(Package package) async {
    try {
      CustomerInfo customerInfo = await Purchases.purchasePackage(package);
      _updateEntitlementStatus(customerInfo);
      final bool isSuccess = isPremium;

      if (isSuccess) {
        await AnalyticsService.instance.logPurchaseSuccess(
          packageId: package.identifier,
          price: package.storeProduct.price,
          currency: package.storeProduct.currencyCode,
        );
      }
      return isSuccess;
    } catch (e) {
      if (kDebugMode) {
        print('[RevenueCatService] Purchase error/cancelled: $e');
      }
      return false;
    }
  }

  /// Restore past purchases.
  Future<bool> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      _updateEntitlementStatus(customerInfo);
      return isPremium;
    } catch (e) {
      if (kDebugMode) {
        print('[RevenueCatService] Restore purchases error: $e');
      }
      return false;
    }
  }

  /// Development/Test helper to manually toggle premium status in offline mode.
  Future<void> toggleDebugPremium(bool enable) async {
    isPremiumNotifier.value = enable;
    try {
      final box = Hive.box('time_bank');
      box.put(_hiveKey, enable);
    } catch (_) {}
    await AnalyticsService.instance.setUserProperties(isPremium: enable);
  }
}
