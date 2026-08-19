import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/analytics_service.dart';
import '../services/onesignal_service.dart';
import '../services/revenuecat_service.dart';
import '../widgets/premium_glass_system.dart';

/// High-end Puffy Glass Paywall Screen for Fravo Premium Subscriptions.
class PaywallScreen extends StatefulWidget {
  final String source;
  const PaywallScreen({super.key, this.source = 'app'});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final RevenueCatService _revenueCat = RevenueCatService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;

  late final DateTime _openedAt;
  bool _hasPurchased = false;

  Offerings? _offerings;
  Package? _selectedPackage;
  bool _isPurchasing = false;
  String? _errorMessage;

  int _selectedTierIndex = 0; // 0: Yearly, 1: Monthly, 2: Lifetime

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    OneSignalService.instance.setScreenTrigger('paywall');
    _analytics.logPaywallViewed(source: widget.source);
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final offerings = await _revenueCat.getOfferings();
    if (mounted) {
      setState(() {
        _offerings = offerings;
        if (offerings?.current != null && offerings!.current!.availablePackages.isNotEmpty) {
          _selectedPackage = offerings.current!.annual ?? offerings.current!.availablePackages.first;
        }
      });
    }
  }

  String get _currentPlanName {
    switch (_selectedTierIndex) {
      case 0:
        return 'annual';
      case 1:
        return 'monthly';
      case 2:
        return 'lifetime';
      default:
        return 'annual';
    }
  }

  String get _annualPriceText {
    final pkg = _offerings?.current?.annual;
    if (pkg != null) {
      return '${pkg.storeProduct.priceString} / year';
    }
    return '\$19.99 / year';
  }

  String get _monthlyPriceText {
    final pkg = _offerings?.current?.monthly;
    if (pkg != null) {
      return '${pkg.storeProduct.priceString} / month';
    }
    return '\$3.99 / month';
  }

  String get _lifetimePriceText {
    final pkg = _offerings?.current?.lifetime;
    if (pkg != null) {
      return '${pkg.storeProduct.priceString} one-time';
    }
    return '\$49.99 one-time';
  }

  String get _annualSubText {
    final pkg = _offerings?.current?.annual;
    if (pkg != null) {
      final monthlyEquivalent = (pkg.storeProduct.price / 12).toStringAsFixed(2);
      final currency = pkg.storeProduct.currencyCode;
      return 'Just $currency $monthlyEquivalent / mo • 7-day free trial';
    }
    return 'Just \$1.66 / month • Build a lifelong walking habit';
  }

  void _handlePlanSelected(int index, String planName, double price) {
    setState(() {
      _selectedTierIndex = index;
      if (_offerings?.current != null) {
        if (index == 0) _selectedPackage = _offerings!.current!.annual;
        if (index == 1) _selectedPackage = _offerings!.current!.monthly;
        if (index == 2) _selectedPackage = _offerings!.current!.lifetime;
      }
    });
    _analytics.logPaywallPlanSelected(
      planType: planName,
      price: price,
      currency: _selectedPackage?.storeProduct.currencyCode ?? 'USD',
    );
  }

  Future<void> _handlePurchase() async {
    _analytics.logPaywallCtaClicked(
      planType: _currentPlanName,
      source: widget.source,
    );

    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    bool success = false;
    if (_selectedPackage != null) {
      success = await _revenueCat.purchasePackage(_selectedPackage!);
    } else {
      if (kDebugMode) {
        // In debug test mode, allow toggling debug premium
        await _revenueCat.toggleDebugPremium(true);
        success = true;
      } else {
        setState(() {
          _errorMessage = 'Connecting to Google Play... Please check your internet connection and try again.';
          _isPurchasing = false;
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _isPurchasing = false;
    });

    if (success) {
      _hasPurchased = true;
      await OneSignalService.instance.recordPaywallPurchased();
      _showSuccessDialog();
    } else {
      final pkgId = _selectedPackage?.identifier ?? 'annual';
      await _analytics.logPaywallPurchaseFailed(
        packageId: pkgId,
        error: 'Purchase cancelled or declined by store',
      );
      setState(() {
        _errorMessage = 'Purchase could not be completed. Please try again or restore.';
      });
    }
  }

  void _handleExit() {
    if (!_hasPurchased && !_revenueCat.isPremium) {
      final timeSpent = DateTime.now().difference(_openedAt).inSeconds;
      final box = Hive.box('time_bank');
      final prevAbandons = (box.get('paywall_abandon_count', defaultValue: 0) as int);
      final newAbandons = prevAbandons + 1;
      box.put('paywall_abandon_count', newAbandons);

      _analytics.logPaywallAbandoned(
        source: widget.source,
        timeSpentSeconds: timeSpent,
        selectedPlan: _currentPlanName,
        hadError: _errorMessage != null,
        totalAbandons: newAbandons,
      );

      OneSignalService.instance.recordPaywallAbandoned(
        source: widget.source,
        planType: _currentPlanName,
        timeSpentSeconds: timeSpent,
        totalAbandons: newAbandons,
      );
    }
    Navigator.pop(context);
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    final success = await _revenueCat.restorePurchases();
    if (!mounted) return;

    setState(() {
      _isPurchasing = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Purchases restored successfully! Premium active.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No active subscriptions found for this account.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: PuffyGlassContainer(
          borderRadius: 32,
          padding: const EdgeInsets.all(28),
          tintColor: const Color(0xFFECFDF5),
          tintAlpha: 0.95,
          gradient: const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'Pledge Locked In! 🏆',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF065F46),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You\'ve made the daily commitment to walk first and defeat doomscrolling. Your body is now the password to your favorite apps!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF047857), height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pop(context); // Exit paywall
                  },
                  child: const Text(
                    'Let\'s Walk! 🚶‍♂️',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEEF2F6),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -80,
                right: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  ),
                ),
              ),
              Positioned(
                bottom: -60,
                left: -60,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  ),
                ),
              ),

              // Main Content
              ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Top Action Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 28, color: Color(0xFF64748B)),
                        onPressed: _handleExit,
                      ),
                      TextButton(
                        onPressed: _handleRestore,
                        child: const Text(
                          'Restore Pledge',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Hero Commitment Badge & Icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_walk_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Commitment Subtitle Tag
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: _revenueCat.isPremium ? const Color(0xFF10B981) : const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _revenueCat.isPremium ? '🏆 FRAVO PRO IS ACTIVE' : '✨ THE DAILY FOCUS COMMITMENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _revenueCat.isPremium ? Colors.white : const Color(0xFF047857),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'I Commit to Walk First',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Make a personal pledge to your health and focus. Lock endless doomscrolling and earn every minute of screen time with your daily steps.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Commitment Pillars Highlights List
                  _buildFeatureRow(
                    icon: Icons.lock_clock_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Unbreakable Focus Pledge',
                    subtitle: 'Lock unlimited distraction apps so only real walking unlocks them.',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureRow(
                    icon: Icons.bolt_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'Tailored Step-to-Minute Ratio',
                    subtitle: 'Reward your walking pace (5 to 60 mins per 1,000 steps).',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureRow(
                    icon: Icons.flash_on_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Zero Ad Interruptions',
                    subtitle: '3 instant emergency passes every day without watching ads.',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureRow(
                    icon: Icons.show_chart_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Daily Streak & Habit Tracker',
                    subtitle: 'Visual history of steps walked and screen time reclaimed.',
                  ),

                  const SizedBox(height: 28),

                  // Commitment Tier Selector
                  const Text(
                    'Choose Your Commitment Length',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tier 0: Annual (365-Day Walker Pledge - Best Commitment)
                  _buildTierCard(
                    index: 0,
                    badgeText: '🔥 365-DAY COMMITMENT • 7 DAYS FREE',
                    badgeColor: const Color(0xFF10B981),
                    title: '365-Day Walker Pledge',
                    priceText: _annualPriceText,
                    subText: _annualSubText,
                    isSelected: _selectedTierIndex == 0,
                    onTap: () => _handlePlanSelected(
                      0,
                      'annual',
                      _offerings?.current?.annual?.storeProduct.price ?? 19.99,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Tier 1: Monthly (30-Day Focus Sprint)
                  _buildTierCard(
                    index: 1,
                    badgeText: '⚡ 30-DAY HABIT SPRINT',
                    badgeColor: const Color(0xFF3B82F6),
                    title: '30-Day Focus Sprint',
                    priceText: _monthlyPriceText,
                    subText: 'Build month-by-month walking momentum • Cancel anytime',
                    isSelected: _selectedTierIndex == 1,
                    onTap: () => _handlePlanSelected(
                      1,
                      'monthly',
                      _offerings?.current?.monthly?.storeProduct.price ?? 3.99,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Tier 2: Lifetime (Lifetime Dedication)
                  _buildTierCard(
                    index: 2,
                    badgeText: '👑 PERMANENT LIFESTYLE PLEDGE',
                    badgeColor: const Color(0xFF8B5CF6),
                    title: 'Lifetime Focus Dedication',
                    priceText: _lifetimePriceText,
                    subText: 'One-time commitment • Never pay again',
                    isSelected: _selectedTierIndex == 2,
                    onTap: () => _handlePlanSelected(
                      2,
                      'lifetime',
                      _offerings?.current?.lifetime?.storeProduct.price ?? 49.99,
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Commitment CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _revenueCat.isPremium ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: (_revenueCat.isPremium ? const Color(0xFF3B82F6) : const Color(0xFF10B981)).withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _isPurchasing ? null : (_revenueCat.isPremium ? () => Navigator.pop(context) : _handlePurchase),
                      child: _isPurchasing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _revenueCat.isPremium
                                  ? 'Fravo Pro Active (Manage in Google Play)'
                                  : _selectedTierIndex == 0
                                      ? 'I Commit to Walk Daily (7 Days Free)'
                                      : 'Lock In My Daily Commitment 👟',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Legal auto-renewal disclosure
                  const Text(
                    '7-day free trial on the 365-Day Pledge. Payment will be charged to your Google Play account at confirmation of purchase or at the end of the trial period. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in Google Play > Payments & Subscriptions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), height: 1.35),
                  ),

                  const SizedBox(height: 16),

                  // Policy Links & Restore Purchases Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _isPurchasing ? null : _handleRestore,
                        child: const Text(
                          'Restore Purchases',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ),
                      const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                      TextButton(
                        onPressed: () => _showTermsDialog(),
                        child: const Text(
                          'Terms of Service',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ),
                      const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                      TextButton(
                        onPressed: () => _showPrivacyDialog(),
                        child: const Text(
                          'Privacy Policy',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const SingleChildScrollView(
          child: Text(
            'By subscribing to Fravo Pro, you gain access to unlimited app blocking, custom step-to-time conversion rates, and 3 ad-free daily emergency passes.\n\n'
            'Subscriptions renew automatically unless cancelled in Google Play Store settings. You can manage and cancel your subscription anytime via Google Play > Payments & Subscriptions.\n\n'
            'Refunds are processed according to Google Play standard refund policies.',
            style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF475569)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const SingleChildScrollView(
          child: Text(
            'Fravo is privacy-focused. Step counting and app usage monitoring are processed strictly on your device to calculate your screen time budget.\n\n'
            'We do not collect or sell personal identifiable information. Purchases are securely handled by Google Play Billing and RevenueCat.',
            style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF475569)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return PuffyGlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      tintColor: Colors.white,
      tintAlpha: 0.85,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required int index,
    required String? badgeText,
    required Color? badgeColor,
    required String title,
    required String priceText,
    required String subText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: PuffyGlassContainer(
          borderRadius: 22,
          padding: const EdgeInsets.all(18),
          tintColor: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          tintAlpha: isSelected ? 0.95 : 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (badgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor ?? const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Icon(
                    isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                priceText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
