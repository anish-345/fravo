import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralized service for Google Mobile Ads (AdMob) Rewarded Video Ads.
class AdMobService {
  AdMobService._privateConstructor();
  static final AdMobService instance = AdMobService._privateConstructor();

  bool _initialized = false;
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;

  bool get isInitialized => _initialized;
  bool get isAdLoaded => _rewardedAd != null;

  /// AdMob Rewarded Video Unit IDs
  static String get rewardedAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-2743584570741087/4079078869'; // Android Rewarded Ad Unit ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // iOS Test Rewarded ID
    }
    return '';
  }

  /// Initialize Mobile Ads SDK.
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
          if (kDebugMode) {
            print('[AdMobService] RewardedAd loaded successfully.');
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

  /// Shows the Rewarded Video Ad and triggers [onRewardEarned] when user watches.
  /// If no ad is loaded or network fails, invokes [onAdFailed] so caller can fallback.
  void showRewardedAd({
    required VoidCallback onRewardEarned,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
  }) {
    if (_rewardedAd == null) {
      if (kDebugMode) {
        print('[AdMobService] No RewardedAd ready, triggering fallback.');
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
          print('[AdMobService] User earned reward: ${reward.amount} ${reward.type}');
        }
        onRewardEarned();
      },
    );
  }
}
