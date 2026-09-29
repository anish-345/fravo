import 'package:flutter/material.dart';
import '../services/blocker_service.dart';
import '../services/health_service.dart';
import '../services/onesignal_service.dart';
import '../services/time_bank.dart';
import '../widgets/app_selector_sheet.dart';
import '../widgets/liquid_glass_nav_bar.dart';
import 'dashboard_screen.dart';
import 'paywall_screen.dart';
import 'pet_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// Main Container Screen hosting the 4 bottom tabs with Liquid Glass Floating Navigation & Global Deep Link Routing.
class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    // Deep link router: maps all legacy & new URLs (fravo://paywall, fravo://stats, etc.)
    OneSignalService.instance.onDeepLinkTriggered = (target) {
      if (!mounted) return;
      final clean = target
          .toLowerCase()
          .replaceAll('fravo://', '')
          .split('?')
          .first
          .replaceAll('/', '')
          .trim();
      switch (clean) {
        case 'stats':
        case 'analytics':
        case 'chart':
          _onTabSelected(1);
          break;
        case 'pippy':
        case 'pet':
        case 'wardrobe':
        case 'companion':
        case 'customizer':
          _onTabSelected(2);
          break;
        case 'settings':
        case 'preferences':
        case 'referral':
        case 'invite':
          _onTabSelected(3);
          break;
        case 'paywall':
        case 'pro':
        case 'upgrade':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PaywallScreen(source: 'deep_link'),
            ),
          );
          break;
        default:
          _onTabSelected(0);
          break;
      }
    };
  }

  @override
  void dispose() {
    OneSignalService.instance.onDeepLinkTriggered = null;
    _pageController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  void _openAppSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppSelectorSheet(
        selectedPackageNames: TimeBankService.instance.blockedPackageNames.toSet(),
        onAppsSelected: (packageNames, displayNames) async {
          await TimeBankService.instance.setBlockedApps(packageNames, displayNames);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentIndex = index),
            children: [
              const FravoDashboard(),
              const StatsScreen(),
              const PetScreen(),
              SettingsScreen(
                timeBank: TimeBankService.instance,
                blockerService: BlockerService.instance,
                healthService: HealthService.instance,
                onManageApps: _openAppSelector,
              ),
            ],
          ),
          // Soft bottom edge fade
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 90,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFF3F4F6).withValues(alpha: 0.0),
                      const Color(0xFFF3F4F6).withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: LiquidGlassNavBar(
                selectedIndex: _currentIndex,
                onTabSelected: _onTabSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
