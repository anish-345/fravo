import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/admob_service.dart';
import '../services/analytics_service.dart';
import '../services/onesignal_service.dart';
import '../services/revenuecat_service.dart';
import '../widgets/premium_glass_system.dart';

/// Fully compliant Google Play Paywall Screen for Fravo Pro.
/// 100% matches Google Play Console prepaid base plans:
/// - "365-Day Walker Pledge" (365 days, prepaid, does NOT auto-renew)
/// - "30-Day Focus Sprint" (30 days, prepaid, does NOT auto-renew)
/// - "Lifetime Focus Dedication" (one-time purchase, never expires)
/// - Explicitly states duration, upfront cost, and that plans expire without auto-renewal.
/// - Matches Google Play checkout cart 1:1.
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
  bool _isLoadingOfferings = true;
  String? _errorMessage;

  int _selectedTierIndex = 0; // 0: Annual (365-Day), 1: Monthly (30-Day), 2: Lifetime

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    OneSignalService.instance.setScreenTrigger('paywall');
    _analytics.logPaywallViewed(source: widget.source);
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() => _isLoadingOfferings = true);
    final offerings = await _revenueCat.getOfferings();
    if (mounted) {
      setState(() {
        _offerings = offerings;
        _isLoadingOfferings = false;
        _selectedPackage = _getPackageForIndex(_selectedTierIndex);
      });
    }
  }

  Package? _getPackageForIndex(int index) {
    if (_offerings?.current == null) return null;
    final current = _offerings!.current!;
    final pkgs = current.availablePackages;
    if (pkgs.isEmpty) return null;

    if (index == 0) {
      // Annual / 365-Day Walker Pledge
      if (current.annual != null) return current.annual;
      for (final p in pkgs) {
        if (p.packageType == PackageType.annual) return p;
        final id = p.identifier.toLowerCase();
        final prodId = p.storeProduct.identifier.toLowerCase();
        if (id.contains('annual') || id.contains('year') || id.contains('365') ||
            prodId.contains('annual') || prodId.contains('year') || prodId.contains('365')) {
          return p;
        }
      }
      return pkgs.first;
    } else if (index == 1) {
      // Monthly / 30-Day Focus Sprint
      if (current.monthly != null) return current.monthly;
      for (final p in pkgs) {
        if (p.packageType == PackageType.monthly) return p;
        final id = p.identifier.toLowerCase();
        final prodId = p.storeProduct.identifier.toLowerCase();
        if (id.contains('monthly') || id.contains('month') || id.contains('30') ||
            prodId.contains('monthly') || prodId.contains('month') || prodId.contains('30')) {
          return p;
        }
      }
    } else if (index == 2) {
      // Lifetime / Permanent Dedication
      if (current.lifetime != null) return current.lifetime;
      for (final p in pkgs) {
        if (p.packageType == PackageType.lifetime) return p;
        final id = p.identifier.toLowerCase();
        final prodId = p.storeProduct.identifier.toLowerCase();
        if (id.contains('lifetime') || id.contains('forever') || prodId.contains('lifetime')) {
          return p;
        }
      }
    }
    return null;
  }

  Package? get _annualPackage => _getPackageForIndex(0);
  Package? get _monthlyPackage => _getPackageForIndex(1);
  Package? get _lifetimePackage => _getPackageForIndex(2);

  String _cleanProductTitle(Package? pkg, String fallback) {
    if (pkg == null) return fallback;
    String title = pkg.storeProduct.title;
    final parenIndex = title.indexOf('(');
    if (parenIndex > 0) {
      title = title.substring(0, parenIndex).trim();
    }
    return title.isNotEmpty ? title : fallback;
  }

  String get _annualTitle => _cleanProductTitle(_annualPackage, '365-Day Walker Pledge');
  String get _monthlyTitle => _cleanProductTitle(_monthlyPackage, '30-Day Focus Sprint');
  String get _lifetimeTitle => _cleanProductTitle(_lifetimePackage, 'Lifetime Focus Dedication');

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

  String get _annualPriceString => _annualPackage?.storeProduct.priceString ?? (_isLoadingOfferings ? '...' : '₹600.00');
  String get _monthlyPriceString => _monthlyPackage?.storeProduct.priceString ?? (_isLoadingOfferings ? '...' : '₹60.00');
  String get _lifetimePriceString => _lifetimePackage?.storeProduct.priceString ?? (_isLoadingOfferings ? '...' : '₹2,000.00');

  String get _annualSubText {
    final pkg = _annualPackage;
    if (pkg != null) {
      final monthlyRate = (pkg.storeProduct.price / 12).toStringAsFixed(2);
      final currency = pkg.storeProduct.currencyCode;
      return 'Prepaid for 365 days • ${pkg.storeProduct.priceString} upfront ($currency $monthlyRate/mo) • Does NOT auto-renew';
    }
    return 'Prepaid for 365 days • $_annualPriceString upfront • Does NOT auto-renew';
  }

  String get _monthlySubText {
    return 'Prepaid for 30 days • $_monthlyPriceString upfront • Does NOT auto-renew';
  }

  String get _lifetimeSubText {
    return 'One-time payment of $_lifetimePriceString • Permanent access • Never expires';
  }

  void _handlePlanSelected(int index, String planName, double price) {
    setState(() {
      _selectedTierIndex = index;
      _selectedPackage = _getPackageForIndex(index);
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

    final pkg = _selectedPackage ?? _getPackageForIndex(_selectedTierIndex);

    bool success = false;
    if (pkg != null) {
      success = await _revenueCat.purchasePackage(pkg);
    } else {
      if (kDebugMode) {
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
      final pkgId = pkg?.identifier ?? _currentPlanName;
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
    if (!_hasPurchased) {
      AdMobService.instance.showScreenTransitionInterstitial();
    }
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
          content: const Text('Purchases restored successfully! Fravo Pro is active.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No active plan found for this Google Play account.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
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
                'Fravo Pro Activated! 🏆',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF065F46),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your commitment is locked in! Unlimited apps and premium features are now unlocked. Walk first, doomscroll never!',
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
                    Navigator.pop(ctx);
                    Navigator.pop(context);
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
        backgroundColor: const Color(0xFFF1F5F9),
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
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
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
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  ),
                ),
              ),

              ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  // Top Navigation Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 28, color: Color(0xFF64748B)),
                        onPressed: _handleExit,
                      ),
                      TextButton(
                        onPressed: _isPurchasing ? null : _handleRestore,
                        child: const Text(
                          'Restore Purchases',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Header Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _revenueCat.isPremium ? const Color(0xFF10B981) : const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _revenueCat.isPremium ? '🏆 FRAVO PRO ACTIVE' : '⚡ CORE APP IS FREE • PRO IS OPTIONAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _revenueCat.isPremium ? Colors.white : const Color(0xFF1D4ED8),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Upgrade to Fravo Pro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Lock endless doomscrolling and earn your screen time with every step walked.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Mandatory Google Play App Requirement Disclosure
                  _buildSubscriptionRequirementBanner(),

                  const SizedBox(height: 14),

                  // Pro Perks Checklist Box
                  _buildPerksCard(),

                  const SizedBox(height: 18),

                  // Tier Selection Headline
                  const Text(
                    'Choose Your Plan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tier 0: 365-Day Walker Pledge (Annual)
                  _buildTierCard(
                    index: 0,
                    badgeText: '🔥 BEST VALUE • SAVE 17%',
                    badgeColor: const Color(0xFF10B981),
                    title: '$_annualTitle (Annual)',
                    priceText: '$_annualPriceString / 365 days',
                    subText: _annualSubText,
                    isSelected: _selectedTierIndex == 0,
                    onTap: () => _handlePlanSelected(
                      0,
                      'annual',
                      _annualPackage?.storeProduct.price ?? 600.0,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Tier 1: 30-Day Focus Sprint (Monthly)
                  _buildTierCard(
                    index: 1,
                    badgeText: '⚡ 30-DAY HABIT SPRINT',
                    badgeColor: const Color(0xFF3B82F6),
                    title: '$_monthlyTitle (Monthly)',
                    priceText: '$_monthlyPriceString / 30 days',
                    subText: _monthlySubText,
                    isSelected: _selectedTierIndex == 1,
                    onTap: () => _handlePlanSelected(
                      1,
                      'monthly',
                      _monthlyPackage?.storeProduct.price ?? 60.0,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Tier 2: Lifetime (One-Time)
                  _buildTierCard(
                    index: 2,
                    badgeText: '👑 ONE-TIME PAYMENT • NEVER EXPIRES',
                    badgeColor: const Color(0xFF8B5CF6),
                    title: '$_lifetimeTitle (Lifetime)',
                    priceText: '$_lifetimePriceString one-time',
                    subText: _lifetimeSubText,
                    isSelected: _selectedTierIndex == 2,
                    onTap: () => _handlePlanSelected(
                      2,
                      'lifetime',
                      _lifetimePackage?.storeProduct.price ?? 2000.0,
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Comprehensive Terms & Billing Details Card
                  _buildOfferTermsCard(),

                  const SizedBox(height: 16),

                  // Purchase CTA Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _revenueCat.isPremium ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isPurchasing ? null : (_revenueCat.isPremium ? () => Navigator.pop(context) : _handlePurchase),
                      child: _isPurchasing
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _revenueCat.isPremium
                                      ? 'Fravo Pro is Active'
                                      : _selectedTierIndex == 0
                                          ? 'Get 365 Days for $_annualPriceString'
                                          : _selectedTierIndex == 1
                                              ? 'Get 30 Days for $_monthlyPriceString'
                                              : 'Unlock Lifetime for $_lifetimePriceString',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                if (!_revenueCat.isPremium) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedTierIndex == 0
                                        ? 'Prepaid for 365 days • Does NOT auto-renew • Extend anytime'
                                        : _selectedTierIndex == 1
                                            ? 'Prepaid for 30 days • Does NOT auto-renew • Extend anytime'
                                            : 'One-time payment • Never expires',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFFDCFCE7)),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Dynamic Legal Terms Text
                  Text(
                    _selectedTierIndex == 0
                        ? '365-Day Walker Pledge: Charged a single payment of $_annualPriceString today upon confirmation. This is a prepaid plan for 365 days of Fravo Pro access and does NOT automatically renew. Your plan will expire after 365 days. You can extend your plan anytime in Fravo or in Subscriptions on Google Play.'
                        : _selectedTierIndex == 1
                            ? '30-Day Focus Sprint: Charged a single payment of $_monthlyPriceString today upon confirmation. This is a prepaid plan for 30 days of Fravo Pro access and does NOT automatically renew. Your plan will expire after 30 days. You can extend your plan anytime in Fravo or in Subscriptions on Google Play.'
                            : 'Lifetime Access: Charged a single one-time payment of $_lifetimePriceString today upon confirmation. Non-recurring payment. Permanent lifetime access to all current and future Fravo Pro features.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // How to manage or extend your plan Guide
                  _buildCancellationGuide(),

                  const SizedBox(height: 16),

                  // Policy Links
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _isPurchasing ? null : _handleRestore,
                        child: const Text(
                          'Restore Purchases',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ),
                      const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                      TextButton(
                        onPressed: _showTermsDialog,
                        child: const Text(
                          'Terms of Service',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ),
                      const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                      TextButton(
                        onPressed: _showPrivacyDialog,
                        child: const Text(
                          'Privacy Policy',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// App requirement disclosure explaining Free vs Pro tier clearly
  Widget _buildSubscriptionRequirementBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subscription Requirement',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Fravo offers a free version with 1 locked app and core timer. A subscription or one-time purchase is optional and required only to unlock unlimited locked apps and Pro perks.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF334155),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact perks highlight card
  Widget _buildPerksCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildPerkRow(Icons.lock_clock_rounded, const Color(0xFFEF4444), 'Unlimited App Locking', 'Lock all distraction apps simultaneously'),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildPerkRow(Icons.bolt_rounded, const Color(0xFF10B981), 'Custom Step-to-Time Rates', 'Earn 5 to 60 mins per 1,000 steps'),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildPerkRow(Icons.flash_on_rounded, const Color(0xFFF59E0B), '3 Instant Emergency Passes', 'Bypass lock immediately without watching ads'),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildPerkRow(Icons.check_circle_outline_rounded, const Color(0xFF8B5CF6), 'Full Habit Tracker & Custom Auras', 'Streak history and companion customization'),
        ],
      ),
    );
  }

  Widget _buildPerkRow(IconData icon, Color iconColor, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Prominent, high-contrast offer terms and billing breakdown complying with Google Play Subscriptions Policy
  Widget _buildOfferTermsCard() {
    final isAnnual = _selectedTierIndex == 0;
    final isMonthly = _selectedTierIndex == 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_outlined, size: 18, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Plan Terms & Billing Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          if (isAnnual) ...[
            _buildTermRow(
              label: 'Plan Name',
              value: '$_annualTitle (Annual Plan)',
              highlightValue: true,
            ),
            const SizedBox(height: 8),
            _buildTermRow(
              label: 'Due Today',
              value: '$_annualPriceString (Charged immediately upon confirmation)',
              highlightValue: true,
            ),
            const SizedBox(height: 8),
            _buildTermRow(
              label: 'Duration',
              value: '365 days of Fravo Pro access from date of purchase',
            ),
            const SizedBox(height: 8),
            _buildTermRow(
              label: 'Auto-Renewal',
              value: 'None. This is a prepaid plan that does NOT automatically renew. Access will expire after 365 days.',
            ),
            const SizedBox(height: 8),
            _buildTermRow(
              label: 'How to Extend',
              value: 'You can extend your plan anytime in Fravo or in Subscriptions on Google Play.',
            ),
            const SizedBox(height: 8),
            _buildTermRow(
              label: 'Free Trial',
              value: 'No free trial included with this purchase. Billed immediately.',
            ),
          ] else if (isMonthly) ...[
            _buildTermRow(
              label: 'Plan Name',
              value: '$_monthlyTitle (Monthly Plan)',
              highlightValue: true,
            ),
            const SizedBox(height: 8),
            _buildTermRow(
              label: 'Due Today',
              value: '$_monthlyPriceString (Charged immediately upon confirmation)',
              highlightValue: true,
            ),
            const SizedBox(height: 8),
            _buildTermRow(
              label: 'Duration',
              value: '30 days of Fravo Pro access from date of purchase',
            ),
            const SizedBox(height: 8),
            _buildTermRow(
              label: 'Auto-Renewal',
              value: 'None. This is a prepaid plan that does NOT automatically renew. Access will expire after 30 days.',
            ),
            const SizedBox(height: 8),
            _buildTermRow(
              label: 'How to Extend',
              value: 'You can extend your plan anytime in Fravo or in Subscriptions on Google Play.',
            ),
            const SizedBox(height: 8),
            _buildTermRow(
              label: 'Free Trial',
              value: 'No free trial included with this purchase. Billed immediately.',
            ),
          ] else ...[
            _buildTermRow(
              label: 'Plan Name',
              value: '$_lifetimeTitle (Lifetime Access)',
              highlightValue: true,
            ),
            const SizedBox(height: 8),
            _buildTermRow(
              label: 'Due Today',
              value: '$_lifetimePriceString (One-time payment upon confirmation)',
              highlightValue: true,
            ),
            const SizedBox(height: 8),
            _buildTermRow(
              label: 'Duration',
              value: 'Permanent lifetime access (Never expires)',
            ),
            const SizedBox(height: 8),
            _buildTermRow(
              label: 'Auto-Renewal',
              value: 'None. Non-recurring payment. No subscription or renewals.',
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),
          _buildTermRow(
            label: 'App Requirement',
            value: 'Purchase is optional. Free version of Fravo (1 locked app) remains accessible without purchase.',
          ),
        ],
      ),
    );
  }

  Widget _buildTermRow({
    required String label,
    required String value,
    bool highlightValue = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlightValue ? FontWeight.w700 : FontWeight.w500,
              color: highlightValue ? const Color(0xFF0F172A) : const Color(0xFF334155),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  /// Step-by-step instructions on how to manage or extend on Google Play
  Widget _buildCancellationGuide() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.help_outline_rounded, size: 16, color: Color(0xFF475569)),
              SizedBox(width: 6),
              Text(
                'How to manage or extend your plan:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '1. Open Google Play Store on your Android device\n'
            '2. Tap your profile icon (top right corner)\n'
            '3. Tap Payments & subscriptions > Subscriptions\n'
            '4. Select Fravo to check expiration date or extend your plan',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF475569),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Terms of Service & Plan Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. App Access & Requirements\n'
                'Fravo offers a free tier with 1 locked app and core features. Fravo Pro is optional and required only to unlock premium features (unlimited app blocking, customizable step-to-minute conversion ratios, 3 ad-free emergency passes daily, and companion customization).\n\n'
                '2. Prepaid Plans & Expiration\n'
                'Fravo Pro plans (365-Day Walker Pledge at $_annualPriceString for 365 days and 30-Day Focus Sprint at $_monthlyPriceString for 30 days) are prepaid plans. They do NOT automatically renew and will expire at the end of the purchased period. Payment is charged to your Google Play account upon confirmation of purchase. You may extend your plan anytime in Fravo or in Subscriptions on Google Play.\n\n'
                '3. Free Trial Policy\n'
                'No free trial is included with Google Play purchases. Users are charged immediately upon confirmation of purchase.\n\n'
                '4. Managing or Extending Your Plan\n'
                'To manage your plan or view expiration details:\n'
                '• Open Google Play Store\n'
                '• Tap your profile icon in the top right corner\n'
                '• Select "Payments & subscriptions" > "Subscriptions"\n'
                '• Select "Fravo" to view your active plan status\n\n'
                '5. Refunds\n'
                'Refund requests are handled directly by Google Play in accordance with Google Play Refund Policies.',
                style: const TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF334155)),
              ),
            ],
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
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
            width: isSelected ? 2.2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (badgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor ?? const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                priceText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subText,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF475569),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
