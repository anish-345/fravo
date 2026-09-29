import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zo_app_blocker/zo_app_blocker.dart';

import '../services/analytics_service.dart';
import '../services/blocker_service.dart';
import '../services/companion_service.dart';
import '../services/health_service.dart';
import '../services/onesignal_service.dart';
import '../services/revenuecat_service.dart';
import '../services/time_bank.dart';
import '../widgets/app_selector_sheet.dart';
import '../widgets/pippy_avatar_widget.dart';
import '../widgets/premium_glass_system.dart';
import 'main_navigation_screen.dart';
import 'paywall_screen.dart';

/// Fravo's enhanced first-run experience — a 4-step animated walkthrough.
///
/// Designed for maximum conversion & low permission friction:
///  0. **Personal Goal** — Select primary motivation (Beat Doomscrolling, Focus, Fitness).
///  1. **Pick your apps** — swipeable "digital culprit" cards + popular-app grid with toggles.
///  2. **Walk to earn & Difficulty** — animated step counter + reward rate selector (15/30/45 min per 1k steps).
///  3. **We'll pause them** — preview of the lock overlay screen.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onOnboardingComplete;

  const OnboardingScreen({super.key, required this.onOnboardingComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  static const _kTopCulprits = [
    'com.instagram.android',
    'com.google.android.youtube',
    'com.facebook.katana',
  ];

  final PageController _pageController = PageController();
  final PageController _cardsController =
      PageController(viewportFraction: 0.92);
  int _currentPage = 0;
  String _selectedGoal = 'Beat Doomscrolling';

  List<AppInfo> _popularApps = [];
  bool _loadingApps = true;
  bool _accessibilityEnabled = false;
  bool _isCompleting = false;

  /// Selected app package names during the walkthrough.
  final Set<String> _selected = {};

  /// Display names for selected apps (package → name).
  final Map<String, String> _selectedNames = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.instance.logEvent('onboarding_started');
    AnalyticsService.instance.logOnboardingStepViewed(0, 'goal_selection');
    OneSignalService.instance.setJourneyStage('onboarding_step_0');
    _loadPopularApps();
    _checkAccessibilityStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibilityStatus();
    }
  }

  Future<void> _checkAccessibilityStatus() async {
    try {
      final perms = await BlockerService.instance.checkPermissionsStatus();
      final isAcc = perms['accessibility'] == true;
      if (mounted && isAcc != _accessibilityEnabled) {
        setState(() => _accessibilityEnabled = isAcc);
      }
    } catch (_) {}
  }

  static const List<String> _stepNames = [
    'goal_selection',
    'pick_apps',
    'walk_to_earn',
    'accessibility_setup',
  ];

  void _onStepChanged(int index) {
    setState(() => _currentPage = index);
    final name = index < _stepNames.length ? _stepNames[index] : 'step_$index';
    AnalyticsService.instance.logOnboardingStepViewed(index, name);
    OneSignalService.instance.setJourneyStage('onboarding_step_$index');
  }

  Future<void> _skipOnboarding() async {
    if (_isCompleting) return;
    try {
      final name = _currentPage < _stepNames.length
          ? _stepNames[_currentPage]
          : 'step_$_currentPage';
      unawaited(AnalyticsService.instance
          .logOnboardingAbandoned(
            lastStepIndex: _currentPage,
            reason: 'skipped_at_$name',
          )
          .catchError((_) {}));
    } catch (_) {}
    await _completeOnboarding();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  Future<void> _loadPopularApps() async {
    try {
      final selectableApps = await BlockerService.instance.getSelectableApps();
      final List<AppInfo> apps = List.from(selectableApps);

      // Prioritize top culprits, then alphabetical
      apps.sort((a, b) {
        final ia = _kTopCulprits.indexOf(a.packageName);
        final ib = _kTopCulprits.indexOf(b.packageName);
        if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
        if (ia >= 0) return -1;
        if (ib >= 0) return 1;
        return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
      });

      if (!mounted) return;
      setState(() {
        _popularApps = apps;
        _loadingApps = false;

        // Pre-select initial top culprit app so user has active selection preset
        if (_selected.isEmpty) {
          final top = _topCulpritList.isNotEmpty ? _topCulpritList.first : apps.firstOrNull;
          if (top != null) {
            _selected.add(top.packageName);
            _selectedNames[top.packageName] = top.appName;
          }
        }
      });
    } catch (e) {
      debugPrint('Onboarding _loadPopularApps error: $e');
      if (!mounted) return;
      setState(() => _loadingApps = false);
    }
  }

  List<AppInfo> get _topCulpritList {
    final result = <AppInfo>[];
    for (final pkg in _kTopCulprits) {
      for (final app in _popularApps) {
        if (app.packageName == pkg) {
          result.add(app);
          break;
        }
      }
    }
    return result;
  }

  List<AppInfo> get _otherPopularApps => _popularApps
      .where((a) => !_kTopCulprits.contains(a.packageName))
      .take(8)
      .toList();

  void _toggleApp(AppInfo app) {
    final isPremium = RevenueCatService.instance.isPremium;
    final isSelectingNew = !_selected.contains(app.packageName);

    if (!isPremium && isSelectingNew && _selected.isNotEmpty) {
      _showOnboardingUpgradeDialog();
      return;
    }

    setState(() {
      if (_selected.contains(app.packageName)) {
        _selected.remove(app.packageName);
        _selectedNames.remove(app.packageName);
      } else {
        _selected.add(app.packageName);
        _selectedNames[app.packageName] = app.appName;
      }
    });
  }

  void _showOnboardingUpgradeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 24),
            SizedBox(width: 8),
            Text(
              '1 App Limit for Free Tier',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'Free users can select 1 app at a time.\n\nUpgrade to Fravo Premium for unlimited app blocking, custom step rates, and priority notifications!',
          style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaywallScreen(source: 'onboarding_limit')),
              );
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  /// Quick Start: one tap = block top culprits and jump straight to Step 2.
  Future<void> _quickStart() async {
    final isPremium = RevenueCatService.instance.isPremium;
    final topList = isPremium ? _topCulpritList : _topCulpritList.take(1).toList();

    setState(() {
      _selected.clear();
      _selectedNames.clear();
      for (final app in topList) {
        _selected.add(app.packageName);
        _selectedNames[app.packageName] = app.appName;
      }
    });
    await _saveSelectedApps();
    if (mounted) _animateToPage(2);
  }

  Future<void> _saveSelectedApps() async {
    try {
      // Save ONLY the exact apps selected by the user on the onboarding screen as the blocked app preset
      await TimeBankService.instance.setBlockedApps(
        _selected.toList(),
        Map<String, String>.from(_selectedNames),
      );
    } catch (e) {
      debugPrint('Onboarding _saveSelectedApps setBlockedApps error: $e');
    }
    try {
      await BlockerService.instance.evaluateBlockState();
    } catch (e) {
      debugPrint('Onboarding _saveSelectedApps evaluateBlockState error: $e');
    }
  }

  void _animateToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    try {
      // Fallback: If user skipped before picking apps, assign a default distraction app
      if (_selected.isEmpty) {
        final top = _topCulpritList.isNotEmpty
            ? _topCulpritList.first
            : (_popularApps.isNotEmpty ? _popularApps.first : null);
        if (top != null) {
          _selected.add(top.packageName);
          _selectedNames[top.packageName] = top.appName;
        } else {
          _selected.add('com.instagram.android');
          _selectedNames['com.instagram.android'] = 'Instagram';
        }
      }

      await _saveSelectedApps();

      try {
        final box = Hive.isBoxOpen('time_bank')
            ? Hive.box('time_bank')
            : await Hive.openBox('time_bank');
        await box.put('completedOnboarding', true);
      } catch (e) {
        debugPrint('Onboarding Hive save error: $e');
      }

      final blockedAppsList = _selected.toList();
      final primaryAppName = _selectedNames.values.firstOrNull ?? 'General';
      final rewardRate = TimeBankService.instance.minutesPer1kSteps;

      // 1. Log event & user profile properties to Firebase Analytics (unawaited background task)
      unawaited(AnalyticsService.instance
          .logOnboardingCompleted(
            goal: _selectedGoal,
            blockedApps: blockedAppsList,
            rewardRate: rewardRate,
          )
          .catchError((e) {
        debugPrint('Analytics logOnboardingCompleted error: $e');
      }));

      // 2. Sync user profile tags to OneSignal for segmented notifications (unawaited background task)
      unawaited(OneSignalService.instance
          .syncOnboardingUserProfile(
            goal: _selectedGoal,
            blockedApps: blockedAppsList,
            primaryAppName: primaryAppName,
            rewardRate: rewardRate,
          )
          .catchError((e) {
        debugPrint('OneSignal syncOnboardingUserProfile error: $e');
      }));

      try {
        widget.onOnboardingComplete();
      } catch (e) {
        debugPrint('Onboarding widget.onOnboardingComplete error: $e');
      }
    } catch (e) {
      debugPrint('Onboarding _completeOnboarding unexpected error: $e');
    } finally {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: progress + skip ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: (_currentPage + 1) / 4),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      builder: (context, value, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE5E7EB),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF4A90E2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isCompleting ? null : _skipOnboarding,
                    child: _isCompleting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4A90E2),
                            ),
                          )
                        : const Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // ── Pippy Motion Guide Banner ──────────────────────────────
            _buildPippyGuideBanner(),

            // ── PageView walkthrough ───────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: _onStepChanged,
                children: [
                  _buildGoalStep(),
                  _buildPickAppsStep(),
                  _WalkToEarnStep(
                    onNext: () => _animateToPage(3),
                    onSkip: _skipOnboarding,
                  ),
                  _buildAccessibilityEngineStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 0: Goal Selection ────────────────────────────────────────────────

  Widget _buildGoalStep() {
    final goals = [
      {
        'title': 'Beat Doomscrolling',
        'desc': 'Stop endless swiping on social media',
        'icon': Icons.stay_current_portrait_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'title': 'Boost Focus & Productivity',
        'desc': 'Stay locked in during work or study hours',
        'icon': Icons.center_focus_strong_rounded,
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': 'Walk & Stay Active',
        'desc': 'Earn screen time through daily steps',
        'icon': Icons.directions_run_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Digital Detox',
        'desc': 'Reclaim hours for real-life activities',
        'icon': Icons.spa_rounded,
        'color': const Color(0xFFF59E0B),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            'What brings you to Fravo?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F2937),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select your primary goal so Fravo can tailor your experience.',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: goals.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final g = goals[i];
                final title = g['title'] as String;
                final desc = g['desc'] as String;
                final icon = g['icon'] as IconData;
                final color = g['color'] as Color;
                final isSelected = _selectedGoal == title;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedGoal = title);
                    TimeBankService.instance.setSelectedGoal(title);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? color : const Color(0xFFE5E7EB),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                desc,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded,
                              color: color, size: 22),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: VibrantGlassButton(
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
              gradientColors: const [Color(0xFF4A90E2), Color(0xFF10B981)],
              onPressed: () => _animateToPage(1),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Step 1: Pick your apps ────────────────────────────────────────────────

  Widget _buildPickAppsStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            'Pick your apps',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F2937),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose the apps Fravo will pause when your screen time runs out.',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loadingApps
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Swipeable top-culprit cards
                      if (_topCulpritList.isNotEmpty) ...[
                        SizedBox(
                          height: 180,
                          child: PageView.builder(
                            itemCount: _topCulpritList.length,
                            controller: _cardsController,
                            itemBuilder: (context, i) {
                              final app = _topCulpritList[i];
                              return _SwipeableAppCard(
                                app: app,
                                first: i == 0,
                                selected:
                                    _selected.contains(app.packageName),
                                onToggle: () => _toggleApp(app),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      // Popular apps menu
                      if (_otherPopularApps.isNotEmpty) ...[
                        Row(
                          children: [
                            const Text(
                              'POPULAR MENU',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_selected.length} selected',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4A90E2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.82,
                            ),
                            itemCount: _otherPopularApps.length,
                            itemBuilder: (context, i) {
                              final app = _otherPopularApps[i];
                              return _AppMenuTile(
                                app: app,
                                selected:
                                    _selected.contains(app.packageName),
                                onTap: () => _toggleApp(app),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: VibrantGlassButton(
              label: '⚡ Quick Start',
              icon: Icons.bolt_rounded,
              gradientColors: const [
                Color(0xFF10B981),
                Color(0xFF4A90E2),
              ],
              onPressed: _loadingApps ? null : _quickStart,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () {
                _saveSelectedApps();
                _animateToPage(2);
              },
              child: const Text(
                'Next Step →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Pippy Dynamic Animated Guide Banner ──────────────────────────────────

  Widget _buildPippyGuideBanner() {
    final companion = CompanionService.instance;
    PippyMood mood;
    String dialogue;
    Color bubbleColor = const Color(0xFFE8FDF3);

    switch (_currentPage) {
      case 0:
        mood = PippyMood.idle;
        dialogue = 'Hi! I\'m ${companion.name} 🌱 Pick your main goal and I\'ll help keep your focus sharp!';
        break;
      case 1:
        mood = PippyMood.alert;
        dialogue = 'Select your biggest distraction apps below 📱 I\'ll pause them when screen time expires!';
        break;
      case 2:
        mood = PippyMood.walking;
        dialogue = 'Every 1,000 steps earns screen time! 🚶‍♂️ Step up to unlock your favorite apps.';
        break;
      case 3:
      default:
        mood = _accessibilityEnabled ? PippyMood.celebrate : PippyMood.alert;
        dialogue = _accessibilityEnabled
            ? 'Awesome! Fravo App Blocker Engine is active 🎉 Tap below to launch your dashboard!'
            : 'In Settings: Look for "Fravo App Blocker Engine" under Downloaded Apps / Installed Services, then toggle ON 🛡️';
        bubbleColor = _accessibilityEnabled ? const Color(0xFFE8FDF3) : const Color(0xFFFEF3C7);
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Container(
        key: ValueKey<int>(_currentPage),
        margin: const EdgeInsets.fromLTRB(24, 6, 24, 6),
        child: PuffyGlassContainer(
          tintColor: bubbleColor,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              PippyAvatarWidget(
                size: 48,
                mood: mood,
                aura: companion.aura,
                accessory: companion.accessory,
                streakDays: 0,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${companion.name} Guide',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _currentPage == 3 && !_accessibilityEnabled
                                ? const Color(0xFFB45309)
                                : const Color(0xFF047857),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _currentPage == 3 && !_accessibilityEnabled ? '⚠️ Setup' : '✨ Tip',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dialogue,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 3: Accessibility & Fravo App Blocker Engine Guide ────────────────

  Widget _buildAccessibilityEngineStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Enable Blocker Engine',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F2937),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Fravo requires Accessibility Service permission to pause selected apps when your time runs out.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildGuideStepCard(
                    number: '1',
                    icon: Icons.touch_app_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF3B82F6),
                    title: 'Open Accessibility Settings',
                    subtitle: 'Tap "Downloaded apps" or "Installed services"',
                  ),
                  const SizedBox(height: 10),
                  _buildGuideStepCard(
                    number: '2',
                    icon: Icons.shield_rounded,
                    iconBg: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF10B981),
                    title: 'Select "Fravo App Blocker Engine"',
                    subtitle: 'Look for Fravo in the accessibility services list',
                    highlightBadge: 'Fravo App Blocker Engine',
                  ),
                  const SizedBox(height: 10),
                  _buildGuideStepCard(
                    number: '3',
                    icon: Icons.toggle_on_rounded,
                    iconBg: const Color(0xFFFFFBEB),
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Toggle ON & Tap Allow',
                    subtitle: 'Activate automated screen-time protection',
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _accessibilityEnabled
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _accessibilityEnabled
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFFED7AA),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _accessibilityEnabled
                              ? Icons.check_circle_rounded
                              : Icons.info_outline_rounded,
                          color: _accessibilityEnabled
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF97316),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _accessibilityEnabled
                                ? 'Fravo Blocker Engine is Active & Ready!'
                                : 'Waiting for accessibility permission...',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: _accessibilityEnabled
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF9A3412),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: VibrantGlassButton(
              label: _isCompleting
                  ? 'Launching Dashboard...'
                  : (_accessibilityEnabled
                      ? 'Launch Fravo Dashboard 🚀'
                      : 'Turn ON Fravo Engine 🛡️'),
              icon: _isCompleting
                  ? null
                  : (_accessibilityEnabled
                      ? Icons.rocket_launch_rounded
                      : Icons.shield_rounded),
              gradientColors: _accessibilityEnabled
                  ? const [Color(0xFF10B981), Color(0xFF059669)]
                  : const [Color(0xFF3B82F6), Color(0xFF10B981)],
              onPressed: _isCompleting
                  ? null
                  : () async {
                      if (_accessibilityEnabled) {
                        await _completeOnboarding();
                      } else {
                        await BlockerService.instance.requestAccessibilityPermission();
                      }
                    },
            ),
          ),
          if (!_accessibilityEnabled) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: _isCompleting ? null : _completeOnboarding,
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: Color(0xFF6B7280),
                ),
                label: const Text(
                  'Launch Dashboard (Enable in Settings Later) 🚀',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGuideStepCard({
    required String number,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? highlightBadge,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlightBadge != null ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlightBadge != null
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : const Color(0xFFE5E7EB),
          width: highlightBadge != null ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(color: iconColor.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                if (highlightBadge != null) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '🔍 $highlightBadge',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: iconColor, size: 22),
        ],
      ),
    );
  }
}

// ── Swipeable app card ────────────────────────────────────────────────────────

class _SwipeableAppCard extends StatelessWidget {
  final AppInfo app;
  final bool first;
  final bool selected;
  final VoidCallback onToggle;

  const _SwipeableAppCard({
    required this.app,
    required this.first,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: UltraGlassContainer(
        borderRadius: 22,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                AppIconWidget(
                  packageName: app.packageName,
                  size: 52,
                  fallbackBgColor: const Color(0xFFEFF6FF),
                  fallbackIconColor: const Color(0xFF4A90E2),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.appName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (first)
                        const Text(
                          'Top digital culprit 🤳',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        const Text(
                          'Swipe to explore',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PremiumGlassToggle(
                  value: selected,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Popular app menu tile ────────────────────────────────────────────────────

class _AppMenuTile extends StatelessWidget {
  final AppInfo app;
  final bool selected;
  final VoidCallback onTap;

  const _AppMenuTile({
    required this.app,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF10B981).withValues(alpha: 0.6)
                : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIconWidget(
              packageName: app.packageName,
              size: 40,
              fallbackBgColor: const Color(0xFFF3F4F6),
              fallbackIconColor: const Color(0xFF4A90E2),
            ),
            const SizedBox(height: 6),
            Text(
              app.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF065F46)
                    : const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 2),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color: selected
                  ? const Color(0xFF10B981)
                  : const Color(0xFFCBD5E1),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Walk to Earn step: animated counter + Difficulty Selector + Permission ────

class _WalkToEarnStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _WalkToEarnStep({required this.onNext, required this.onSkip});

  @override
  State<_WalkToEarnStep> createState() => _WalkToEarnStepState();
}

class _WalkToEarnStepState extends State<_WalkToEarnStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _counter;
  late final Animation<double> _steps;
  late final Animation<double> _minutes;

  bool _permissionGranted = false;
  int _selectedRate = 30; // Default: 30 min per 1,000 steps

  @override
  void initState() {
    super.initState();
    _selectedRate = TimeBankService.instance.minutesPer1kSteps;
    _counter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _steps = CurvedAnimation(parent: _counter, curve: Curves.easeOutQuint);
    _minutes = CurvedAnimation(
      parent: _counter,
      curve: const Interval(0.3, 1, curve: Curves.easeOutCubic),
    );
    _counter.forward();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await HealthService.instance.checkPermissions();
    if (mounted) setState(() => _permissionGranted = granted);
  }

  Future<void> _requestPermission() async {
    final granted = await HealthService.instance.requestPermissions();
    if (mounted) setState(() => _permissionGranted = granted);
  }

  @override
  void dispose() {
    _counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Walk to earn',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F2937),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Fravo turns physical steps into screen time for your chosen apps.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Animated counter
                  AnimatedBuilder(
                    animation: _counter,
                    builder: (context, _) {
                      final stepsDone = (_steps.value * 1000).round();
                      final minutes = (_minutes.value * _selectedRate).round();
                      return SizedBox(
                        width: 190,
                        height: 190,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: _steps.value,
                              strokeWidth: 10,
                              backgroundColor: const Color(0xFFE5E7EB),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                Color(0xFF10B981),
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$stepsDone',
                                    style: const TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1F2937),
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const Text(
                                    'steps',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (minutes >= 1)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD1FAE5),
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        '= $minutes min earned 🎉',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF065F46),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Reward rate selector
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SELECT YOUR REWARD RATE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _RateOptionTile(
                        title: 'Casual',
                        subtitle: '45m / 1k',
                        rate: 45,
                        selected: _selectedRate == 45,
                        onSelect: () {
                          setState(() => _selectedRate = 45);
                          TimeBankService.instance.setMinutesPer1kSteps(45);
                        },
                      ),
                      const SizedBox(width: 8),
                      _RateOptionTile(
                        title: 'Balanced',
                        subtitle: '30m / 1k',
                        rate: 30,
                        selected: _selectedRate == 30,
                        onSelect: () {
                          setState(() => _selectedRate = 30);
                          TimeBankService.instance.setMinutesPer1kSteps(30);
                        },
                      ),
                      const SizedBox(width: 8),
                      _RateOptionTile(
                        title: 'Strict',
                        subtitle: '15m / 1k',
                        rate: 15,
                        selected: _selectedRate == 15,
                        onSelect: () {
                          setState(() => _selectedRate = 15);
                          TimeBankService.instance.setMinutesPer1kSteps(15);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Progressive permission tile
                  _permissionGranted
                      ? const _GrantedTile()
                      : _StepPermissionTile(
                          onGrant: _requestPermission,
                          onOpenSettings: () =>
                              HealthService.instance.openAppSettingsPage(),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: VibrantGlassButton(
              label: 'Next Step',
              icon: Icons.arrow_forward_rounded,
              gradientColors: const [
                Color(0xFF4A90E2),
                Color(0xFF10B981),
              ],
              onPressed: widget.onNext,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: widget.onSkip,
              child: const Text(
                'Skip for now',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _RateOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final int rate;
  final bool selected;
  final VoidCallback onSelect;

  const _RateOptionTile({
    required this.title,
    required this.subtitle,
    required this.rate,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Permission tiles for walkthrough ─────────────────────────────────────────

class _GrantedTile extends StatelessWidget {
  const _GrantedTile();

  @override
  Widget build(BuildContext context) {
    return UltraGlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_walk_rounded,
            color: Color(0xFF10B981),
            size: 20,
          ),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Step tracking enabled — every step counts! 🚶',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF065F46),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepPermissionTile extends StatelessWidget {
  final VoidCallback onGrant;
  final VoidCallback onOpenSettings;

  const _StepPermissionTile({
    required this.onGrant,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return UltraGlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      showIridescence: false,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_walk_rounded,
              color: Color(0xFF10B981),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable step tracking',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Required to count physical steps on your phone.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF6B7280),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onGrant,
                child: const Text(
                  'Grant',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onOpenSettings,
                child: const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF4A90E2),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
