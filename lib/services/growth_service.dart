import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:device_info_plus/device_info_plus.dart';

import 'analytics_service.dart';
import 'onesignal_service.dart';
import 'revenuecat_service.dart';

/// Service managing organic user growth, viral referral engine, and Google Play Store reviews.
class GrowthService {
  GrowthService._privateConstructor();
  static final GrowthService instance = GrowthService._privateConstructor();

  static const String _boxName = 'time_bank';
  static const String _referralCodeKey = 'user_referral_code';
  static const String _hasRedeemedReferralKey = 'has_redeemed_referral';
  static const String _referralCountKey = 'referral_count';
  static const String _hasRatedAppKey = 'has_rated_app_on_playstore';

  /// Official Google Play Store URLs
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=avionti.fravo';
  static const String playStoreMarketUrl =
      'market://details?id=avionti.fravo';

  /// Get or generate unique referral code for this user (e.g. FRAVO-4K89).
  String get referralCode {
    try {
      final box = Hive.box(_boxName);
      String? code = box.get(_referralCodeKey) as String?;
      if (code == null || code.isEmpty) {
        code = _generateReferralCode();
        box.put(_referralCodeKey, code);
      }
      return code;
    } catch (_) {
      return 'FRAVO-WALK';
    }
  }

  /// Full dynamic referral URL with Google Play Install Referrer parameters.
  String get referralLink =>
      '$playStoreUrl&referrer=utm_source%3Dapp_referral%26utm_content%3D$referralCode';

  /// Total friends referred by this user.
  int get referralCount {
    try {
      final box = Hive.box(_boxName);
      return (box.get(_referralCountKey) as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Whether the user has already entered a friend's referral code.
  bool get hasRedeemedReferral {
    try {
      final box = Hive.box(_boxName);
      return (box.get(_hasRedeemedReferralKey) as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Check hardware device fingerprint to ensure 1 claim per physical device
  Future<String> _getDeviceHardwareId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      }
      return 'generic_device';
    } catch (_) {
      return 'generic_device';
    }
  }

  /// Check if this physical device has already redeemed a referral trial
  Future<bool> hasDeviceClaimedReferral() async {
    try {
      final box = Hive.box(_boxName);
      final devId = await _getDeviceHardwareId();
      final deviceClaimed =
          (box.get('device_claimed_$devId', defaultValue: false) as bool);
      return deviceClaimed || hasRedeemedReferral;
    } catch (_) {
      return hasRedeemedReferral;
    }
  }

  /// Whether the user has already rated Fravo on Google Play.
  bool get hasRatedApp {
    try {
      final box = Hive.box(_boxName);
      return (box.get(_hasRatedAppKey) as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Generates a clean, readable 5-character referral code.
  String _generateReferralCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final buffer = StringBuffer('FRAVO-');
    for (int i = 0; i < 4; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  /// Shares the viral invite message with Google Play link.
  Future<void> shareReferralInvite({String? customNote}) async {
    final code = referralCode;
    final shareText =
        '🔥 I use Fravo to lock distracting apps and earn screen time by walking!\n\n'
        '🚶‍♂️ 1,000 steps = screen time earned\n'
        '🛑 Lock Instagram, YouTube & social media\n\n'
        'Download Fravo on Google Play:\n$playStoreUrl\n\n'
        '🎁 Use my invite code: $code to get 7 DAYS FREE FRAVO PREMIUM!';

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: 'Claim 7 Days Free Premium on Fravo!',
        ),
      );

      // Track analytics
      await AnalyticsService.instance.logEvent('referral_shared', parameters: {
        'referral_code': code,
      });
      await OneSignalService.instance.setUserTag('has_shared_referral', 'true');
    } catch (e) {
      if (kDebugMode) {
        print('[GrowthService] Share referral error: $e');
      }
    }
  }

  /// Shares a visual achievement milestone with Google Play download link.
  Future<void> shareMilestoneProgress({
    required int stepsWalked,
    required int earnedMinutes,
    required XFile? imageFile,
  }) async {
    final code = referralCode;
    final text =
        '🏆 I walked ${stepsWalked.toString()} steps and earned $earnedMinutes mins of screen time today on Fravo!\n\n'
        'Try Fravo to beat doomscrolling & walk to earn your screen time:\n$playStoreUrl\n'
        'Use my code "$code" for 7 Days Free Premium!';

    try {
      if (imageFile != null) {
        await SharePlus.instance.share(
          ShareParams(
            files: [imageFile],
            text: text,
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(text: text),
        );
      }

      await AnalyticsService.instance.logEvent('milestone_shared', parameters: {
        'steps': stepsWalked,
        'earned_min': earnedMinutes,
      });
    } catch (e) {
      if (kDebugMode) {
        print('[GrowthService] Share milestone error: $e');
      }
    }
  }

  /// Redeem a friend's referral code to unlock 7 Days of Free Fravo Premium!
  /// Validated with:
  /// 1. Anti-self referral (cannot redeem own code)
  /// 2. Hardware device fingerprint check (1 claim per physical device)
  /// 3. Atomic local lock (prevents button spamming)
  Future<bool> redeemReferralCode(String inputCode) async {
    final cleaned = inputCode.trim().toUpperCase();
    if (cleaned.isEmpty) return false;
    if (cleaned == referralCode) return false; // Anti-self referral

    if (await hasDeviceClaimedReferral()) {
      return false; // Hardware device already claimed referral trial
    }

    try {
      final box = Hive.box(_boxName);
      final devId = await _getDeviceHardwareId();
      await box.put(_hasRedeemedReferralKey, true);
      await box.put('device_claimed_$devId', true);

      // Activate 7-Day Free Premium Trial via RevenueCatService
      await RevenueCatService.instance.activate7DayReferralTrial();

      // Track analytics
      await AnalyticsService.instance.logEvent('referral_redeemed', parameters: {
        'referred_by_code': cleaned,
        'reward': '7_days_premium',
        'device_id_hash': devId.hashCode.toString(),
      });
      await OneSignalService.instance.setUserTag('referred_by', cleaned);
      await OneSignalService.instance.setUserTag('referral_reward', '7_days_premium');

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[GrowthService] Redeem code error: $e');
      }
      return false;
    }
  }

  /// Opens Google Play Store directly to rate/review the app.
  Future<void> openPlayStoreReview() async {
    try {
      final marketUri = Uri.parse(playStoreMarketUrl);
      final webUri = Uri.parse(playStoreUrl);

      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }

      final box = Hive.box(_boxName);
      await box.put(_hasRatedAppKey, true);

      await AnalyticsService.instance.logEvent('playstore_review_clicked');
      await OneSignalService.instance.setUserTag('has_rated_app', 'true');
    } catch (e) {
      if (kDebugMode) {
        print('[GrowthService] Open Play Store review error: $e');
      }
    }
  }

  /// Shows the viral Growth Referral Modal sheet.
  void showReferralSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReferralModalSheet(service: this),
    );
  }

  /// Shows a high-delight 5-star Rating dialog.
  void showRatingPromptDialog(BuildContext context) {
    if (hasRatedApp) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Text('⭐ ', style: TextStyle(fontSize: 24)),
            Expanded(
              child: Text(
                'Enjoying Fravo?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your 5-star review on Google Play helps inspire more people to beat doomscrolling and get active!',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF4B5563), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              openPlayStoreReview();
            },
            icon: const Icon(Icons.star_rounded, size: 18),
            label: const Text('Rate on Google Play', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Puffy Glass Referral Sheet UI for sharing codes and redeeming bonus minutes.
class _ReferralModalSheet extends StatefulWidget {
  final GrowthService service;
  const _ReferralModalSheet({required this.service});

  @override
  State<_ReferralModalSheet> createState() => _ReferralModalSheetState();
}

class _ReferralModalSheetState extends State<_ReferralModalSheet> {
  final TextEditingController _codeController = TextEditingController();
  bool _isRedeeming = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleRedeem() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isRedeeming = true;
      _statusMessage = null;
    });

    final success = await widget.service.redeemReferralCode(code);

    if (!mounted) return;
    setState(() {
      _isRedeeming = false;
      _isSuccess = success;
      _statusMessage = success
          ? '🎉 7 Days Free Premium Trial Activated! All Pro features unlocked.'
          : '⚠️ Invalid code or already redeemed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final myCode = widget.service.referralCode;
    final hasRedeemed = widget.service.hasRedeemedReferral;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFF10B981),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Give 7 Days, Get 7 Days Pro',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Share your invite code for 7 days free Premium',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // My Referral Code Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFF0FDF4)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Column(
              children: [
                const Text(
                  'YOUR INVITE CODE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFF0369A1),
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  myCode,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.service.shareReferralInvite();
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text(
                      'Share Invite & Play Store Link 🚀',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Redeem friend's code section
          if (!hasRedeemed) ...[
            const Text(
              'Have a friend\'s code?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'e.g. FRAVO-4K89',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isRedeeming ? null : _handleRedeem,
                  child: _isRedeeming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Claim 7 Days Pro'),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Referral bonus redeemed! Share your code with friends to earn more.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_statusMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _statusMessage!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: _isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
