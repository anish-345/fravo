import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/paywall_screen.dart';
import '../services/companion_service.dart';
import '../services/growth_service.dart';
import '../services/revenuecat_service.dart';
import '../services/time_bank.dart';
import '../widgets/ambient_aurora_background.dart';
import '../widgets/pippy_avatar_widget.dart';
import '../widgets/premium_glass_system.dart';

/// Full Dedicated Screen for Pippy Mascot Customization, Live Preview & Wardrobe Sanctuary.
class PetScreen extends StatefulWidget {
  const PetScreen({super.key});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen>
    with SingleTickerProviderStateMixin {
  final _companionService = CompanionService.instance;
  final _revenueCat = RevenueCatService.instance;
  final _timeBank = TimeBankService.instance;

  late TextEditingController _nameController;
  late TextEditingController _userNickController;

  // Mascot tap & squish animation
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  // Petting interaction state
  int _petCount = 0;
  String? _petReactionDialogue;
  final List<_PetFloatingParticle> _particles = [];

  // Live Preview State (allows previewing locked Auras, Hats, and Voices)
  // NOTE: These must ALWAYS be synced from the service after every equip/save,
  // and re-synced when the companion service notifies (e.g. premium expires).
  CompanionAura? _previewAura;
  CompanionAccessory? _previewAccessory;
  CompanionPersonality? _previewPersonality;

  // Selected Category tab (0: Auras, 1: Wardrobe, 2: Voices, 3: Profile)
  int _selectedCategoryIndex = 0;

  static const _petPhrases = [
    'Pippy purrs with joy! (Bonding XP +5) 💖',
    'Pippy loves walking with you! 🥰',
    'Yay! Moving together makes us stronger! ⚡',
    'Pippy gives you a happy high-paw! 🐾',
    'Warm hugs and peaceful focus! 🌸',
    'You are Pippy\'s favorite human! ✨',
  ];

  void _syncPreviewFromService() {
    // Only called when premium status changes — reverts locked previews
    // to the service default when Pro expires.
    if (mounted) {
      setState(() {
        _previewAura = _companionService.aura;
        _previewAccessory = _companionService.accessory;
        _previewPersonality = _companionService.personality;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _companionService.name);
    _userNickController = TextEditingController(text: _companionService.userName);

    _previewAura = _companionService.aura;
    _previewAccessory = _companionService.accessory;
    _previewPersonality = _companionService.personality;

    // Only listen to premium status changes — when Pro expires, revert
    // any locked item previews back to the free defaults automatically.
    _revenueCat.isPremiumNotifier.addListener(_syncPreviewFromService);

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.90), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.10), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.10, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _revenueCat.isPremiumNotifier.removeListener(_syncPreviewFromService);
    _nameController.dispose();
    _userNickController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _openProPaywall(String feature) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaywallScreen(source: 'pet_screen_$feature'),
      ),
    );
  }

  void _onPetTapped(Offset localPosition) {
    HapticFeedback.mediumImpact();
    _bounceController.forward(from: 0.0);

    final random = math.Random();
    final phrase = _petPhrases[random.nextInt(_petPhrases.length)];

    final emojis = ['💖', '🥰', '✨', '🌟', '🐾', '🌸'];
    final selectedEmoji = emojis[random.nextInt(emojis.length)];

    setState(() {
      _petCount++;
      _petReactionDialogue = phrase;
      _particles.add(
        _PetFloatingParticle(
          id: DateTime.now().millisecondsSinceEpoch,
          emoji: selectedEmoji,
          offset: localPosition,
          dxSpread: (random.nextDouble() * 80) - 40,
        ),
      );
    });

    _companionService.feedOrPet();

    // Clean up particles
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _particles.removeWhere((p) =>
              DateTime.now().millisecondsSinceEpoch - p.id > 850);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _revenueCat.isPremiumNotifier,
      builder: (context, isPremium, _) {
        return AnimatedBuilder(
          animation: _companionService,
          builder: (context, _) {
            final streakDays = _timeBank.currentStreakDays;
            final streakTier = _companionService.streakTier;

            // Active vs Previewed Attributes
            final effectiveAura = _previewAura ?? _companionService.aura;
            final effectiveAccessory = _previewAccessory ?? _companionService.accessory;
            final effectivePersonality = _previewPersonality ?? _companionService.personality;

            final isAuraLocked = effectiveAura != CompanionAura.mint && !isPremium;
            final isAccessoryLocked = !_companionService.isAccessoryUnlocked(effectiveAccessory);
            final isPersonalityLocked = effectivePersonality != CompanionPersonality.zen && !isPremium;

            final isAnyPreviewLocked = isAuraLocked || isAccessoryLocked || isPersonalityLocked;

            PippyMood mood = PippyMood.idle;
            if (streakDays >= 3) {
              mood = PippyMood.celebrate;
            } else if (_timeBank.remainingScreenTime > 0) {
              mood = PippyMood.walking;
            }

            final message = _petReactionDialogue ??
                _companionService.getContextualDialogue(
                  stepsToday: _timeBank.totalStepsWalked,
                  remainingSeconds: _timeBank.remainingScreenTime * 60,
                  permissionsHealthy: true,
                );

            return Scaffold(
              backgroundColor: const Color(0xFFF3F4F6),
              appBar: AppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Pippy Sanctuary'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        streakTier.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: Icon(
                      isPremium ? Icons.star_rounded : Icons.workspace_premium_rounded,
                      color: isPremium ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                    onPressed: () => _openProPaywall('appbar'),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: AmbientAuroraBackground(
                primaryGlow: effectiveAura.deepColor,
                secondaryGlow: const Color(0xFF10B981),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
                    child: Column(
                      children: [
                        // ── Central Interactive Mascot Stage ───────────────────
                        PuffyGlassContainer(
                          tintColor: effectiveAura.topColor,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                          child: Column(
                            children: [
                              // Preview Active Indicator Banner
                              if (isAnyPreviewLocked)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFF59E0B)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.remove_red_eye_rounded, size: 15, color: Color(0xFFD97706)),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Previewing Locked Item',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _previewAura = _companionService.aura;
                                            _previewAccessory = _companionService.accessory;
                                            _previewPersonality = _companionService.personality;
                                          });
                                        },
                                        child: const Text(
                                          'Reset',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2563EB),
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _openProPaywall('preview_banner'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Unlock ⭐',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Mascot Interactive Tap Zone
                              GestureDetector(
                                onTapDown: (details) => _onPetTapped(details.localPosition),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    ScaleTransition(
                                      scale: _bounceAnimation,
                                      child: PippyAvatarWidget(
                                        size: 136,
                                        mood: mood,
                                        aura: effectiveAura,
                                        accessory: effectiveAccessory,
                                        streakDays: streakDays,
                                      ),
                                    ),

                                    // Floating Particle Hearts on Tap
                                    ..._particles.map((p) {
                                      return Positioned(
                                        top: p.offset.dy - 30,
                                        left: p.offset.dx + p.dxSpread,
                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          duration: const Duration(milliseconds: 750),
                                          builder: (context, val, child) {
                                            return Opacity(
                                              opacity: (1.0 - val).clamp(0.0, 1.0),
                                              child: Transform.translate(
                                                offset: Offset(0, -val * 60),
                                                child: Text(
                                                  p.emoji,
                                                  style: const TextStyle(fontSize: 26),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _companionService.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1F2937),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _petCount > 0
                                        ? 'Petted $_petCount times with love! 💖'
                                        : 'Tap Pippy to pet & share love! 💖',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF065F46),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: Text(
                                  message,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF065F46),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        const SizedBox(height: 16),

                        // ── Segmented Category Tabs (Zero Scroll Fatigue) ──────
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildCategoryTab(0, '🎨 Auras', !isPremium),
                              const SizedBox(width: 8),
                              _buildCategoryTab(1, '🧢 Wardrobe', false),
                              const SizedBox(width: 8),
                              _buildCategoryTab(2, '🎙️ Voices', !isPremium),
                              const SizedBox(width: 8),
                              _buildCategoryTab(3, '🏷️ Profile', false),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Tab Content Container ──────────────────────────────
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _buildSelectedTabContent(
                            isPremium: isPremium,
                            effectiveAura: effectiveAura,
                            effectiveAccessory: effectiveAccessory,
                            effectivePersonality: effectivePersonality,
                            streakTier: streakTier,
                            streakDays: streakDays,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryTab(int index, String label, bool isProGated) {
    final isSelected = _selectedCategoryIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedCategoryIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            if (isProGated && index != 1) ...[
              const SizedBox(width: 5),
              Text(
                'PRO',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? const Color(0xFFFEF08A) : const Color(0xFFD97706),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent({
    required bool isPremium,
    required CompanionAura effectiveAura,
    required CompanionAccessory effectiveAccessory,
    required CompanionPersonality effectivePersonality,
    required StreakTier streakTier,
    required int streakDays,
  }) {
    switch (_selectedCategoryIndex) {
      case 0:
        return _buildAurasTab(isPremium, effectiveAura);
      case 1:
        return _buildWardrobeTab(effectiveAccessory);
      case 2:
        return _buildVoicesTab(isPremium, effectivePersonality);
      case 3:
      default:
        return _buildProfileTab(streakTier, streakDays);
    }
  }

  // ── Tab 0: Auras ──────────────────────────────────────────────────────────
  Widget _buildAurasTab(bool isPremium, CompanionAura effectiveAura) {
    return PuffyGlassContainer(
      key: const ValueKey('tab_auras'),
      tintColor: const Color(0xFFF0FDF4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '✨ Aura Glow Palettes',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              if (!isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🔒 Pro Feature',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: CompanionAura.values.map((aura) {
              final isEquipped = _companionService.aura == aura;
              final isPreviewing = effectiveAura == aura;
              final isMint = aura == CompanionAura.mint;
              final isLocked = !isMint && !isPremium;

              return GestureDetector(
                onTap: () {
                  setState(() => _previewAura = aura);
                  if (!isLocked) {
                    _companionService.setAura(aura);
                  } else {
                    HapticFeedback.selectionClick();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isPreviewing
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isPreviewing
                          ? const Color(0xFF10B981)
                          : const Color(0xFFE2E8F0),
                      width: isPreviewing ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: aura.deepColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        aura.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isPreviewing ? FontWeight.bold : FontWeight.w600,
                          color: isPreviewing
                              ? const Color(0xFF065F46)
                              : const Color(0xFF334155),
                        ),
                      ),
                      if (isLocked) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFF59E0B)),
                      ] else if (isEquipped) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_rounded, size: 14, color: Color(0xFF10B981)),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Wardrobe ───────────────────────────────────────────────────────
  Widget _buildWardrobeTab(CompanionAccessory effectiveAccessory) {
    return PuffyGlassContainer(
      key: const ValueKey('tab_wardrobe'),
      tintColor: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎩 Wardrobe & Hats',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 10),
          ...CompanionAccessory.values.map((acc) {
            final isEquipped = _companionService.accessory == acc;
            final isPreviewing = effectiveAccessory == acc;
            final isUnlocked = _companionService.isAccessoryUnlocked(acc);
            final requiredFriends = acc.requiredReferrals;

            return GestureDetector(
              onTap: () {
                setState(() => _previewAccessory = acc);
                if (isUnlocked) {
                  _companionService.setAccessory(acc);
                } else {
                  HapticFeedback.selectionClick();
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPreviewing
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isPreviewing
                        ? const Color(0xFF10B981)
                        : const Color(0xFFE2E8F0),
                    width: isPreviewing ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(acc.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            acc.displayName,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isPreviewing ? FontWeight.bold : FontWeight.w600,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            isUnlocked
                                ? (isEquipped ? 'Equipped & Active ✓' : 'Unlocked · Tap to Equip')
                                : 'Locked · Invite $requiredFriends friend${requiredFriends > 1 ? 's' : ''} to unlock',
                            style: TextStyle(
                              fontSize: 11,
                              color: isUnlocked ? const Color(0xFF10B981) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isUnlocked)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: const Size(60, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: () => GrowthService.instance.showReferralSheet(context),
                        child: const Text('Unlock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      )
                    else if (isEquipped)
                      const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF10B981)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Tab 2: Voices ─────────────────────────────────────────────────────────
  Widget _buildVoicesTab(bool isPremium, CompanionPersonality effectivePersonality) {
    return PuffyGlassContainer(
      key: const ValueKey('tab_voices'),
      tintColor: const Color(0xFFFAF5FF),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🎙️ Coaching Voice & Tone',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              if (!isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🔒 Pro Feature',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...CompanionPersonality.values.map((pers) {
            final isEquipped = _companionService.personality == pers;
            final isPreviewing = effectivePersonality == pers;
            final isZen = pers == CompanionPersonality.zen;
            final isLocked = !isZen && !isPremium;

            return GestureDetector(
              onTap: () {
                setState(() => _previewPersonality = pers);
                if (!isLocked) {
                  _companionService.setPersonality(pers);
                } else {
                  HapticFeedback.selectionClick();
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPreviewing
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isPreviewing
                        ? const Color(0xFF10B981)
                        : const Color(0xFFE2E8F0),
                    width: isPreviewing ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(pers.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pers.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isPreviewing ? FontWeight.bold : FontWeight.w600,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            pers.description,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    if (isLocked)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: const Size(60, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: () => _openProPaywall('voice_${pers.name}'),
                        child: const Text('Unlock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      )
                    else if (isEquipped)
                      const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF10B981)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Tab 3: Profile & Streak ───────────────────────────────────────────────
  Widget _buildProfileTab(StreakTier streakTier, int streakDays) {
    return Column(
      key: const ValueKey('tab_profile'),
      children: [
        PuffyGlassContainer(
          tintColor: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🏷️ Names & Identity',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _userNickController,
                decoration: InputDecoration(
                  labelText: 'What Pippy calls you',
                  hintText: 'e.g., Alex, Champion, Speedy',
                  prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF10B981)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (val) {
                  if (val.trim().isNotEmpty) {
                    _companionService.setUserName(val.trim());
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Companion Name',
                  hintText: 'e.g., Pippy, Zen, Sparky',
                  prefixIcon: const Icon(Icons.pets_rounded, color: Color(0xFF10B981)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (val) {
                  if (val.trim().isNotEmpty) {
                    _companionService.setName(val.trim());
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Collapsible Streak Tier Engine
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: streakDays >= 3,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                leading: const Text('🔥', style: TextStyle(fontSize: 20)),
                title: const Text(
                  'Streak Evolution Tiers',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
                subtitle: Text(
                  streakDays >= 3 ? '${streakTier.title} Active' : 'Walk daily to evolve Pippy',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFD97706)),
                ),
                children: [
                  _buildTierRow('🌱 Level 1 (0-2 Days)', 'Sprout Seeker', streakTier == StreakTier.sprout),
                  _buildTierRow('🔥 Level 2 (3+ Days)', 'Flame Guardian Glow', streakTier == StreakTier.flame),
                  _buildTierRow('⚡ Level 3 (7+ Days)', 'Electric Neon Halo', streakTier == StreakTier.electric),
                  _buildTierRow('🪽 Level 4 (14+ Days)', 'Celestial Golden Wings', streakTier == StreakTier.winged),
                  _buildTierRow('👑 Level 5 (30+ Days)', 'Supernova Cosmic Crown', streakTier == StreakTier.cosmic),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTierRow(String level, String desc, bool isCurrent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              level,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                color: isCurrent ? const Color(0xFFB45309) : const Color(0xFF4B5563),
              ),
            ),
          ),
          Text(
            desc,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? const Color(0xFFB45309) : const Color(0xFF6B7280),
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFFD97706)),
          ],
        ],
      ),
    );
  }
}

class _PetFloatingParticle {
  final int id;
  final String emoji;
  final Offset offset;
  final double dxSpread;

  _PetFloatingParticle({
    required this.id,
    required this.emoji,
    required this.offset,
    required this.dxSpread,
  });
}
