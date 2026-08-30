import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive/hive.dart';
import 'revenuecat_service.dart';

/// Centralized service for Google Mobile Ads (AdMob) Rewarded and Rewarded Interstitial Ads.
class AdMobService {
  AdMobService._privateConstructor();
  static final AdMobService instance = AdMobService._privateConstructor();

  bool _initialized = false;
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;

  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isRewardedInterstitialAdLoading = false;

  bool get isInitialized => _initialized;
  bool get isAdLoaded => _rewardedAd != null;
  bool get isRewardedInterstitialAdLoaded => _rewardedInterstitialAd != null;

  /// AdMob Rewarded Video Unit IDs (Used for Premium user Emergency Passes)
  static String get rewardedAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-2743584570741087/4079078869'; // Android Rewarded Ad Unit ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // iOS Test Rewarded ID
    }
    return '';
  }

  /// AdMob Rewarded Interstitial Unit IDs (Used for Free user Emergency Passes)
  static String get rewardedInterstitialAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-2743584570741087/1997969728'; // Android Rewarded Interstitial Ad Unit ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/6978759866'; // iOS Test Rewarded Interstitial ID
    }
    return '';
  }

  /// Initialize Mobile Ads SDK and pre-load ads.
  Future<void> init() async {
    if (kIsWeb) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      if (kDebugMode) {
        print('[AdMobService] Google Mobile Ads initialized successfully.');
      }
      loadRewardedAd();
      loadRewardedInterstitialAd();
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

  /// Pre-load a Rewarded Interstitial Ad.
  void loadRewardedInterstitialAd() {
    if (kIsWeb || _isRewardedInterstitialAdLoading || _rewardedInterstitialAd != null) return;
    _isRewardedInterstitialAdLoading = true;

    RewardedInterstitialAd.load(
      adUnitId: rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (RewardedInterstitialAd ad) {
          _rewardedInterstitialAd = ad;
          _isRewardedInterstitialAdLoading = false;
          if (kDebugMode) {
            print('[AdMobService] RewardedInterstitialAd loaded successfully.');
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedInterstitialAd = null;
          _isRewardedInterstitialAdLoading = false;
          if (kDebugMode) {
            print('[AdMobService] RewardedInterstitialAd failed to load: $error');
          }
        },
      ),
    );
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
          print('[AdMobService] User earned reward from RewardedAd: ${reward.amount} ${reward.type}');
        }
        onRewardEarned();
      },
    );
  }

  /// Shows the Rewarded Interstitial Ad and triggers [onRewardEarned] strictly when user watches.
  void showRewardedInterstitialAd({
    required VoidCallback onRewardEarned,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
  }) {
    if (_rewardedInterstitialAd == null) {
      if (kDebugMode) {
        print('[AdMobService] No RewardedInterstitialAd ready.');
      }
      loadRewardedInterstitialAd();
      onAdFailed?.call();
      return;
    }

    _rewardedInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedInterstitialAd ad) {
        ad.dispose();
        _rewardedInterstitialAd = null;
        loadRewardedInterstitialAd(); // Preload next ad
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (RewardedInterstitialAd ad, AdError error) {
        ad.dispose();
        _rewardedInterstitialAd = null;
        loadRewardedInterstitialAd();
        onAdFailed?.call();
      },
    );

    _rewardedInterstitialAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        if (kDebugMode) {
          print('[AdMobService] User earned reward from RewardedInterstitialAd: ${reward.amount} ${reward.type}');
        }
        onRewardEarned();
      },
    );
  }

  DateTime? _lastInterstitialShownAt;
  int _tabSwitchCount = 0;
  static const int _tabSwitchesPerAd = 1;
  static const int _cooldownSeconds = 25;

  /// Shows a Rewarded Interstitial Ad for Free users upon changing screens or switching tabs.
  /// Triggered on tab/screen switches with a 25-second cooldown to guarantee impressions.
  void showTabSwitchRewardedInterstitial() {
    // Premium users never see interstitial ads
    if (RevenueCatService.instance.isPremium) return;

    _tabSwitchCount++;
    if (_tabSwitchCount < _tabSwitchesPerAd) {
      return;
    }

    final now = DateTime.now();
    if (_lastInterstitialShownAt != null &&
        now.difference(_lastInterstitialShownAt!).inSeconds < _cooldownSeconds) {
      // Within cooldown period; keep ad ready for next interval
      return;
    }

    if (_rewardedInterstitialAd != null) {
      _tabSwitchCount = 0; // Reset counter
      _lastInterstitialShownAt = now;
      showRewardedInterstitialAd(
        onRewardEarned: () {
          if (kDebugMode) {
            print('[AdMobService] User watched Tab Switch Rewarded Interstitial.');
          }
        },
      );
    } else {
      loadRewardedInterstitialAd();
    }
  }

  /// Shows an interstitial on key user interactions (e.g. saving blocked apps, viewing stats)
  void showActionInterstitial() {
    if (RevenueCatService.instance.isPremium) return;

    final now = DateTime.now();
    if (_lastInterstitialShownAt != null &&
        now.difference(_lastInterstitialShownAt!).inSeconds < _cooldownSeconds) {
      return;
    }

    if (_rewardedInterstitialAd != null) {
      _lastInterstitialShownAt = now;
      showRewardedInterstitialAd(
        onRewardEarned: () {
          if (kDebugMode) {
            print('[AdMobService] User completed action with Rewarded Interstitial.');
          }
        },
      );
    } else {
      loadRewardedInterstitialAd();
    }
  }

  static const String _lastAppListChangeAdKey = 'last_app_list_change_ad_timestamp';
  static const int _appListChangeCooldownMinutes = 10;

  /// Whether the user is required to watch a rewarded video ad to modify the app blocklist.
  /// Applies to BOTH Free and Premium users after 10+ minutes from their previous modification.
  bool shouldRequireAdForAppListChange() {
    try {
      final box = Hive.box('time_bank');
      final lastTimeMillis = box.get(_lastAppListChangeAdKey) as int?;
      if (lastTimeMillis == null) return true; // First time requires ad
      final lastTime = DateTime.fromMillisecondsSinceEpoch(lastTimeMillis);
      return DateTime.now().difference(lastTime).inMinutes >= _appListChangeCooldownMinutes;
    } catch (_) {
      return false;
    }
  }

  /// Marks the current timestamp as having watched the app list modification ad.
  void markAppListChangeAdWatched() {
    try {
      final box = Hive.box('time_bank');
      box.put(_lastAppListChangeAdKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Shows a Rewarded Ad for BOTH Free and Premium users when changing the blocked apps list,
  /// strictly triggering [onRewardEarned] only when the user finishes watching the video.
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
    } else if (_rewardedInterstitialAd != null) {
      showRewardedInterstitialAd(
        onRewardEarned: () {
          markAppListChangeAdWatched();
          onRewardEarned();
        },
        onAdDismissed: onAdDismissed,
        onAdFailed: onAdFailed,
      );
    } else {
      loadRewardedAd();
      loadRewardedInterstitialAd();
      onAdFailed?.call();
    }
  }

  /// Unified entrypoint for claiming an Emergency Pass:
  /// Both Free and Premium users watch a Rewarded Video Ad to earn the pass.
  /// If no ad is loaded, triggers [onAdUnavailable] (strictly no pass granted).
  void showEmergencyPassAd({
    required bool isPremium,
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
    } else if (_rewardedInterstitialAd != null) {
      showRewardedInterstitialAd(
        onRewardEarned: onRewardEarned,
        onAdDismissed: onAdDismissed,
        onAdFailed: onAdUnavailable,
      );
    } else {
      loadRewardedAd();
      loadRewardedInterstitialAd();
      onAdUnavailable?.call();
    }
  }
}
