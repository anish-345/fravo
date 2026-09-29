import 'package:flutter/material.dart';
import '../screens/paywall_screen.dart';
import '../services/companion_service.dart';
import '../services/growth_service.dart';
import '../services/revenuecat_service.dart';
import 'pippy_avatar_widget.dart';

/// Modal sheet for customizing companion name, user nickname, aura color, hats, and coaching voice.
/// Gated for Fravo Pro subscribers & Referral trial users; reverts to normal when Pro expires.
class CompanionCustomizerSheet extends StatefulWidget {
  const CompanionCustomizerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CompanionCustomizerSheet(),
    );
  }

  @override
  State<CompanionCustomizerSheet> createState() =>
      _CompanionCustomizerSheetState();
}

class _CompanionCustomizerSheetState extends State<CompanionCustomizerSheet> {
  final _companionService = CompanionService.instance;
  final _revenueCat = RevenueCatService.instance;
  late TextEditingController _nameController;
  late TextEditingController _userNickController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _companionService.name);
    _userNickController = TextEditingController(text: _companionService.userName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _userNickController.dispose();
    super.dispose();
  }

  void _openProPaywall(String feature) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaywallScreen(source: 'pet_customizer_$feature'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _revenueCat.isPremiumNotifier,
      builder: (context, isPremium, _) {
        return AnimatedBuilder(
          animation: _companionService,
          builder: (context, _) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🎨 ', style: TextStyle(fontSize: 20)),
                            Text(
                              'Personalize ${_companionService.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Pro Status Banner
                  if (!isPremium)
                    GestureDetector(
                      onTap: () => _openProPaywall('banner'),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Text('✨ ', style: TextStyle(fontSize: 18)),
                            Expanded(
                              child: Text(
                                'PRO Feature: Unlock custom Auras, Wardrobe & Voice styles!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              'UPGRADE ❯',
                              style: TextStyle(
                                color: Color(0xFFFDE047),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      children: [
                        // Live Avatar Preview
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _companionService.aura.coreColor.withValues(alpha: 0.12),
                              border: Border.all(
                                color: _companionService.aura.coreColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: PippyAvatarWidget(
                              size: 130,
                              mood: PippyMood.idle,
                              aura: _companionService.aura,
                              accessory: _companionService.accessory,
                              streakDays: _companionService.currentStreak,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Level & Streak Evolution Chip
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _companionService.hasActiveStreakEffect
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _companionService.hasActiveStreakEffect
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                                    : Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              _companionService.streakLevelTitle,
                              style: TextStyle(
                                color: _companionService.hasActiveStreakEffect
                                    ? const Color(0xFFFCD34D)
                                    : const Color(0xFFB8F2D8),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 1. User Name Field
                        _buildSectionHeader('👤 Your Name (What Pippy Calls You)'),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _userNickController,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.06),
                                  hintText: 'Enter your name/nickname...',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFF7FE3B5)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                _companionService.setUserName(_userNickController.text);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('👋 ${_companionService.name} will call you "${_userNickController.text}"!'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              },
                              child: const Text(
                                'Save',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 2. Companion Name Field
                        _buildSectionHeader('🏷️ Companion Mascot Name'),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.06),
                                  hintText: 'Enter companion name...',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFF7FE3B5)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                _companionService.setName(_nameController.text);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🎉 Saved companion name "${_nameController.text}"!'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              },
                              child: const Text(
                                'Save',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 3. Aura Color Palettes (Pro feature)
                        _buildSectionHeader('🌿 Aura & Skin Color ${isPremium ? '' : '⭐ PRO'}'),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: CompanionAura.values.map((aura) {
                            final isSelected = _companionService.aura == aura;
                            final isDefaultMint = aura == CompanionAura.mint;
                            final isLocked = !isPremium && !isDefaultMint;

                            return GestureDetector(
                              onTap: () {
                                if (isLocked) {
                                  _openProPaywall('aura');
                                } else {
                                  _companionService.setAura(aura);
                                }
                              },
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [aura.midColor, aura.deepColor],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.transparent,
                                    width: isSelected ? 3 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: aura.deepColor.withValues(alpha: 0.6),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: isSelected
                                      ? const Icon(Icons.check, color: Color(0xFF1A1A2E), size: 24)
                                      : isLocked
                                          ? Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.45),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.lock, color: Color(0xFFFDE047), size: 14),
                                            )
                                          : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),

                        // 4. Wardrobe & Accessories (Referral Unlocks: 1, 5, 10 Friends!)
                        _buildSectionHeader('🧢 Wardrobe & Hats (Referral Rewards)'),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.4,
                          children: CompanionAccessory.values.map((acc) {
                            final isUnlocked = _companionService.isAccessoryUnlocked(acc);
                            final isEquipped = _companionService.accessory == acc;

                            return GestureDetector(
                              onTap: () async {
                                if (isUnlocked) {
                                  _companionService.setAccessory(acc);
                                } else {
                                  _showReferralPrompt(context, acc);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isEquipped
                                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.04),
                                  border: Border.all(
                                    color: isEquipped
                                        ? const Color(0xFF10B981)
                                        : Colors.white.withValues(alpha: 0.1),
                                    width: isEquipped ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(acc.emoji, style: const TextStyle(fontSize: 24)),
                                        if (!isUnlocked) ...[
                                          const SizedBox(width: 6),
                                          const Icon(Icons.lock, color: Color(0xFFF59E0B), size: 16),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      acc.displayName,
                                      style: TextStyle(
                                        color: isEquipped ? const Color(0xFFB8F2D8) : Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (!isUnlocked)
                                      Text(
                                        'Invite ${acc.requiredReferrals} friend${acc.requiredReferrals > 1 ? 's' : ''}',
                                        style: const TextStyle(
                                          color: Color(0xFFF59E0B),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),

                        // 5. Coaching Voice Personality (Pro feature)
                        _buildSectionHeader('💬 Assistant Voice Tone ${isPremium ? '' : '⭐ PRO'}'),
                        ...CompanionPersonality.values.map((pers) {
                          final isSelected = _companionService.personality == pers;
                          final isDefaultZen = pers == CompanionPersonality.zen;
                          final isLocked = !isPremium && !isDefaultZen;

                          return GestureDetector(
                            onTap: () {
                              if (isLocked) {
                                _openProPaywall('voice');
                              } else {
                                _companionService.setPersonality(pers);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.04),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF10B981)
                                      : Colors.white.withValues(alpha: 0.1),
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Text(pers.emoji, style: const TextStyle(fontSize: 26)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              pers.title,
                                              style: TextStyle(
                                                color: isSelected ? const Color(0xFFB8F2D8) : Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (isLocked) ...[
                                              const SizedBox(width: 6),
                                              const Icon(Icons.lock, color: Color(0xFFFDE047), size: 14),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          pers.description,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                                ],
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFB8F2D8),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showReferralPrompt(BuildContext context, CompanionAccessory item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Text('${item.emoji} ', style: const TextStyle(fontSize: 24)),
            Expanded(
              child: Text(
                'Unlock ${item.displayName}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Invite ${item.requiredReferrals} friends to Fravo to unlock ${item.displayName} and free Fravo Pro for both of you!',
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              GrowthService.instance.shareReferralInvite();
            },
            child: const Text('Share Invite Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
