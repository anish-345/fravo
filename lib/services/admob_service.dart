import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive/hive.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Centralized service for Google Mobile Ads (AdMob) Rewarded Ads.
/// Note: Interstitial and Rewarded Interstitial formats are completely removed
/// in compliance with Google AdMob "Rewards implementation – User choice" policy.
class AdMobService {
  AdMobService._privateConstructor();
  static final AdMobService instance = AdMobService._privateConstructor();

  bool _initialized = false;
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;

  bool get isInitialized => _initialized;
  bool get isAdLoaded => _rewardedAd != null;

  /// AdMob Rewarded Video Unit ID (Android Only)
  static String get rewardedAdUnitId {
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Android Test Unit
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'ca-app-pub-2743584570741087/4079078869'; // Android Rewarded Ad Unit ID
    }
    return '';
  }

  /// Initializes the Mobile Ads SDK with UMP consent gate (required by AdMob policy).
  ///
  /// This method:
  /// 1. Requests the latest consent information from Google's UMP SDK.
  /// 2. Presents the consent form to the user if required (EEA/UK under GDPR).
  /// 3. Only initializes the AdMob SDK once consent is determined.
  Future<void> initWithConsent() async {
    if (kIsWeb) return;

    final consentCompleter = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          ConsentForm.loadConsentForm(
            (ConsentForm consentForm) async {
              final status =
                  await ConsentInformation.instance.getConsentStatus();
              if (status == ConsentStatus.required) {
                consentForm.show((FormError? showError) {
                  if (showError != null && kDebugMode) {
                    debugPrint(
                      '[AdMobService] UMP form show error: ${showError.message}',
                    );
                  }
                  consentCompleter.complete();
                });
              } else {
                consentCompleter.complete();
              }
            },
            (FormError loadError) {
              if (kDebugMode) {
                print(
                  '[AdMobService] UMP form load error: ${loadError.message}',
                );
              }
              consentCompleter.complete();
            },
          );
        } else {
          consentCompleter.complete();
        }
      },
      (FormError error) {
        if (kDebugMode) {
          debugPrint(
            '[AdMobService] UMP consent info update failed (non-fatal): ${error.message}',
          );
        }
        consentCompleter.complete();
      },
    );

    await consentCompleter.future;
    await init();
  }

  /// Initialize Mobile Ads SDK and pre-load rewarded ads.
  Future<void> init() async {
    if (kIsWeb) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      if (kDebugMode) {
        print('[AdMobService] Google Mobile Ads initialized successfully.');
      }
      loadRewardedAd();
    } catch (e) {
      if (kDebugMode) {
        print('[AdMobService] Initialized with fallback: $e');
      }
    }
  }

  /// Pre-load a Rewarded Video Ad.
  void loadRewardedAd() {
    if (kIsWeb || _isAdLoading || _rewardedAd != null) return;
    _isAdLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _isAdLoading = false;

          // Catvertising: Record AdMob impression revenue into RevenueCat
          ad.onPaidEvent = (Ad paidAd, double valueMicros, PrecisionType precision, String currencyCode) {
            if (kDebugMode) {
              print(
                '[AdMobService] Catvertising onPaidEvent: $valueMicros micros, $currencyCode, precision: $precision',
              );
            }
            try {
              Purchases.adTracker.trackAdRevenue(
                AdRevenueData(
                  mediatorName: AdMediatorName('admob'),
                  adFormat: AdFormat.rewarded,
                  adUnitId: paidAd.adUnitId,
                  impressionId: paidAd.responseInfo?.responseId ??
                      'admob_${DateTime.now().millisecondsSinceEpoch}',
                  revenueMicros: valueMicros.round(),
                  currency: currencyCode,
                  precision: _mapPrecision(precision),
                ),
              );
              if (kDebugMode) {
                print('[AdMobService] Catvertising: Successfully tracked ad revenue to RevenueCat!');
              }
            } catch (e) {
              if (kDebugMode) {
                print('[AdMobService] Error tracking ad revenue to RevenueCat: $e');
              }
            }
          };

          if (kDebugMode) {
            print('[AdMobService] RewardedAd loaded successfully with Catvertising onPaidEvent.');
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
          _isAdLoading = false;
          if (kDebugMode) {
            print('[AdMobService] RewardedAd failed to load: $error');
          }
        },
      ),
    );
  }

  /// Maps Google Mobile Ads [PrecisionType] to RevenueCat [AdRevenuePrecision].
  static AdRevenuePrecision _mapPrecision(PrecisionType precision) {
    switch (precision) {
      case PrecisionType.precise:
        return AdRevenuePrecision.exact;
      case PrecisionType.estimated:
      case PrecisionType.publisherProvided:
        return AdRevenuePrecision.estimated;
      case PrecisionType.unknown:
        return AdRevenuePrecision.unknown;
    }
  }

  /// Shows the Rewarded Video Ad and triggers [onRewardEarned] strictly when user watches.
  void showRewardedAd({
    required VoidCallback onRewardEarned,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
  }) {
    if (_rewardedAd == null) {
      if (kDebugMode) {
        print('[AdMobService] No RewardedAd ready.');
      }
      loadRewardedAd();
      onAdFailed?.call();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Preload next ad
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdFailed?.call();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        if (kDebugMode) {
          print(
            '[AdMobService] User earned reward from RewardedAd: ${reward.amount} ${reward.type}',
          );
        }
        onRewardEarned();
      },
    );
  }

  static const String _lastAppListChangeAdKey =
      'last_app_list_change_ad_timestamp';

  /// Marks the current timestamp as having watched the app list modification ad.
  void markAppListChangeAdWatched() {
    try {
      final box = Hive.box('time_bank');
      box.put(_lastAppListChangeAdKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Shows a Rewarded Ad when the user saves their blocked apps list.
  /// Strictly triggers [onRewardEarned] only when the user finishes watching.
  void showAppListChangeRewardedAd({
    required VoidCallback onRewardEarned,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
  }) {
    if (_rewardedAd != null) {
      showRewardedAd(
        onRewardEarned: () {
          markAppListChangeAdWatched();
          onRewardEarned();
        },
        onAdDismissed: onAdDismissed,
        onAdFailed: onAdFailed,
      );
    } else {
      loadRewardedAd();
      onAdFailed?.call();
    }
  }

  /// Shows a Rewarded Ad when the user saves their reward rate (step-to-time ratio).
  /// Strictly triggers [onRewardEarned] only when the user finishes watching.
  void showRewardRateChangeRewardedAd({
    required VoidCallback onRewardEarned,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
  }) {
    if (_rewardedAd != null) {
      showRewardedAd(
        onRewardEarned: onRewardEarned,
        onAdDismissed: onAdDismissed,
        onAdFailed: onAdFailed,
      );
    } else {
      loadRewardedAd();
      onAdFailed?.call();
    }
  }

  /// Unified entrypoint for claiming an Emergency Pass by watching a rewarded ad.
  /// Requires watching a Rewarded Ad to earn the pass.
  /// If no ad is loaded, triggers [onAdUnavailable] (strictly no pass granted).
  void showEmergencyPassAd({
    bool isPremium = false,
    required VoidCallback onRewardEarned,
    VoidCallback? onAdUnavailable,
    VoidCallback? onAdDismissed,
  }) {
    if (_rewardedAd != null) {
      showRewardedAd(
        onRewardEarned: onRewardEarned,
        onAdDismissed: onAdDismissed,
        onAdFailed: onAdUnavailable,
      );
    } else {
      loadRewardedAd();
      onAdUnavailable?.call();
    }
  }
}
