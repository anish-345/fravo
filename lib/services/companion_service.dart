import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'growth_service.dart';
import 'onesignal_service.dart';
import 'revenuecat_service.dart';
import 'time_bank.dart';

/// Streak-based automated mascot evolution tiers.
/// Maintaining a streak automatically equips fiery visual aura effects and titles.
/// If the streak breaks, these automated effects are instantly removed!
enum StreakTier {
  sprout(0, '🌱 Sprout Seeker', 'Level 1', 'Maintain a 3-day walking streak to ignite Pippy\'s Flame!'),
  flame(3, '🔥 Flame Guardian', 'Level 2', '3+ Day Streak: Active Flame Glow unlocked!'),
  electric(7, '⚡ Neon Speedster', 'Level 3', '7+ Day Streak: Electric Energy Halo unlocked!'),
  winged(14, '🪽 Winged Champion', 'Level 4', '14+ Day Streak: Golden Celestial Wings unlocked!'),
  cosmic(30, '👑 Celestial Demigod', 'Level 5', '30+ Day Streak: Supernova Cosmic Crown unlocked!');

  final int requiredStreak;
  final String title;
  final String levelLabel;
  final String description;

  const StreakTier(this.requiredStreak, this.title, this.levelLabel, this.description);

  static StreakTier fromStreak(int streak) {
    if (streak >= 30) return StreakTier.cosmic;
    if (streak >= 14) return StreakTier.winged;
    if (streak >= 7) return StreakTier.electric;
    if (streak >= 3) return StreakTier.flame;
    return StreakTier.sprout;
  }
}

/// Aura color presets matching Fravo's pastel puffy glass design system.
enum CompanionAura {
  mint,
  lavender,
  peach,
  rose,
  sky;

  Color get topColor {
    switch (this) {
      case CompanionAura.mint:
        return const Color(0xFFE8FDF3);
      case CompanionAura.lavender:
        return const Color(0xFFF5F3FF);
      case CompanionAura.peach:
        return const Color(0xFFFFFBEB);
      case CompanionAura.rose:
        return const Color(0xFFFFF1F2);
      case CompanionAura.sky:
        return const Color(0xFFF0F9FF);
    }
  }

  Color get midColor {
    switch (this) {
      case CompanionAura.mint:
        return const Color(0xFFB8F2D8);
      case CompanionAura.lavender:
        return const Color(0xFFEDE9FE);
      case CompanionAura.peach:
        return const Color(0xFFFEF3C7);
      case CompanionAura.rose:
        return const Color(0xFFFFE4E6);
      case CompanionAura.sky:
        return const Color(0xFFE0F2FE);
    }
  }

  Color get coreColor {
    switch (this) {
      case CompanionAura.mint:
        return const Color(0xFF7FE3B5);
      case CompanionAura.lavender:
        return const Color(0xFFD9CFFF);
      case CompanionAura.peach:
        return const Color(0xFFFFE0C2);
      case CompanionAura.rose:
        return const Color(0xFFFFD0D0);
      case CompanionAura.sky:
        return const Color(0xFFBFE5FF);
    }
  }

  Color get deepColor {
    switch (this) {
      case CompanionAura.mint:
        return const Color(0xFF10B981);
      case CompanionAura.lavender:
        return const Color(0xFF8B5CF6);
      case CompanionAura.peach:
        return const Color(0xFFF59E0B);
      case CompanionAura.rose:
        return const Color(0xFFF43F5E);
      case CompanionAura.sky:
        return const Color(0xFF3B82F6);
    }
  }

  String get displayName {
    switch (this) {
      case CompanionAura.mint:
        return 'Mint Matcha';
      case CompanionAura.lavender:
        return 'Berry Lavender';
      case CompanionAura.peach:
        return 'Sunset Peach';
      case CompanionAura.rose:
        return 'Sakura Rose';
      case CompanionAura.sky:
        return 'Ocean Breeze';
    }
  }
}

/// Headwear accessories for the companion.
enum CompanionAccessory {
  sprout,
  crown,
  sakura,
  headphones;

  String get displayName {
    switch (this) {
      case CompanionAccessory.sprout:
        return 'Natural Sprout';
      case CompanionAccessory.crown:
        return 'Streak Crown';
      case CompanionAccessory.sakura:
        return 'Sakura Bloom';
      case CompanionAccessory.headphones:
        return 'Beats Headphones';
    }
  }

  String get emoji {
    switch (this) {
      case CompanionAccessory.sprout:
        return '🌿';
      case CompanionAccessory.crown:
        return '👑';
      case CompanionAccessory.sakura:
        return '🌸';
      case CompanionAccessory.headphones:
        return '🎧';
    }
  }

  /// Number of successful friend referrals required to unlock.
  int get requiredReferrals {
    switch (this) {
      case CompanionAccessory.sprout:
        return 0; // Default
      case CompanionAccessory.crown:
        return 1; // 1 Friend
      case CompanionAccessory.sakura:
        return 5; // 5 Friends
      case CompanionAccessory.headphones:
        return 10; // 10 Friends
    }
  }
}

/// Coaching personality voice tones (Fabulous inspired).
enum CompanionPersonality {
  zen,
  hype,
  coach,
  cozy;

  String get title {
    switch (this) {
      case CompanionPersonality.zen:
        return 'The Zen Guide';
      case CompanionPersonality.hype:
        return 'The Hype Bestie';
      case CompanionPersonality.coach:
        return 'The Focus Coach';
      case CompanionPersonality.cozy:
        return 'The Cozy Sloth';
    }
  }

  String get description {
    switch (this) {
      case CompanionPersonality.zen:
        return 'Calm, mindful, zero-guilt encouragement';
      case CompanionPersonality.hype:
        return 'High energy cheerleader, celebrates every step';
      case CompanionPersonality.coach:
        return 'Goal-oriented discipline & streak protector';
      case CompanionPersonality.cozy:
        return 'Cute, soft, loves naps and gentle walks';
    }
  }

  String get emoji {
    switch (this) {
      case CompanionPersonality.zen:
        return '🧘';
      case CompanionPersonality.hype:
        return '⚡';
      case CompanionPersonality.coach:
        return '🎯';
      case CompanionPersonality.cozy:
        return '🧸';
    }
  }
}

/// Life Quest journeys (Fabulous inspired).
enum LifeQuest {
  dopamine,
  morning,
  sleep;

  String get label {
    switch (this) {
      case LifeQuest.dopamine:
        return 'The Dopamine Detox';
      case LifeQuest.morning:
        return 'Morning Vitality';
      case LifeQuest.sleep:
        return 'Deep Sleep Sanctuary';
    }
  }

  String get tag {
    switch (this) {
      case LifeQuest.dopamine:
        return 'Focus Journey';
      case LifeQuest.morning:
        return 'Energy Journey';
      case LifeQuest.sleep:
        return 'Rest Journey';
    }
  }

  String get narrative {
    switch (this) {
      case LifeQuest.dopamine:
        return 'Lock distraction apps behind 200 mindful walking steps.';
      case LifeQuest.morning:
        return 'Wake up, step outside, and earn your screen time before noon.';
      case LifeQuest.sleep:
        return 'Lock entertainment apps 45 mins before bed to protect deep sleep.';
    }
  }

  String get pledge {
    switch (this) {
      case LifeQuest.dopamine:
        return 'I walk 150 steps before opening social apps.';
      case LifeQuest.morning:
        return 'I walk 500 morning steps before checking messages.';
      case LifeQuest.sleep:
        return 'I put my phone away 45 mins before bedtime.';
    }
  }

  String get letterTitle {
    switch (this) {
      case LifeQuest.dopamine:
        return 'Chapter IV: The Power of the First 100 Steps';
      case LifeQuest.morning:
        return 'Chapter I: The Golden Morning Sunlight';
      case LifeQuest.sleep:
        return 'Chapter VII: The Whispering Twilight';
    }
  }

  String get letterBody {
    switch (this) {
      case LifeQuest.dopamine:
        return 'Your mind was not built for endless short-form feeds. When you feel the pull of distraction today, simply stand up and take 100 mindful steps with me.';
      case LifeQuest.morning:
        return 'The first 30 minutes of your morning belong to your soul, not the algorithms. Let your morning footsteps ignite your energy for the entire day.';
      case LifeQuest.sleep:
        return 'Rest is not the absence of work; it is the source of all future triumphs. Let me hold your screen time tonight so you wake up revitalized.';
    }
  }
}

/// Service managing the user's Cosy Assistant (Pippy) state, wardrobe, and dialogues.
class CompanionService extends ChangeNotifier {
  CompanionService._privateConstructor();
  static final CompanionService instance = CompanionService._privateConstructor();

  static const String _boxName = 'time_bank';
  static const String _nameKey = 'companion_name';
  static const String _userNameKey = 'user_display_name';
  static const String _auraKey = 'companion_aura';
  static const String _accessoryKey = 'companion_accessory';
  static const String _personalityKey = 'companion_personality';
  static const String _questKey = 'companion_active_quest';
  static const String _bondingXpKey = 'companion_bonding_xp';
  static const String _pledgeSealedDateKey = 'companion_pledge_date';

  String _name = 'Pippy';
  String _userName = 'Friend';
  CompanionAura _aura = CompanionAura.mint;
  CompanionAccessory _accessory = CompanionAccessory.sprout;
  CompanionPersonality _personality = CompanionPersonality.zen;
  LifeQuest _activeQuest = LifeQuest.dopamine;
  int _bondingXp = 45;

  String get name => _name;
  String get userName => _userName;

  /// Effective Aura: If user is Fravo Pro / Referral Trial, returns chosen custom aura.
  /// If Free (or Premium removed/expired), instantly reverts to default Mint.
  CompanionAura get aura {
    if (!RevenueCatService.instance.isPremium) {
      return CompanionAura.mint;
    }
    return _aura;
  }

  /// Effective Accessory: Unlocked via viral referrals (Crown: 1, Sakura: 5, Beats: 10) or default Sprout.
  CompanionAccessory get accessory {
    if (isAccessoryUnlocked(_accessory)) {
      return _accessory;
    }
    return CompanionAccessory.sprout;
  }

  /// Effective Personality: If user is Fravo Pro, returns custom voice tone.
  /// If Free (or Premium removed/expired), instantly reverts to default Zen Guide.
  CompanionPersonality get personality {
    if (!RevenueCatService.instance.isPremium) {
      return CompanionPersonality.zen;
    }
    return _personality;
  }

  /// Current streak days from TimeBank
  int get currentStreak => TimeBankService.instance.currentStreakDays;

  /// Current automated streak evolution tier (Level 1 to Level 5)
  StreakTier get streakTier => StreakTier.fromStreak(currentStreak);

  /// Whether Pippy currently has an active streak effect glowing
  bool get hasActiveStreakEffect => currentStreak >= 3;

  /// Dynamic streak-aware title
  String get streakLevelTitle {
    final streak = currentStreak;
    if (streak == 0) return '🌱 Level 1 · Sprout (Streak 0)';
    return '${streakTier.title} (${streak}d Streak)';
  }

  LifeQuest get activeQuest => _activeQuest;
  int get bondingXp => _bondingXp;

  int get bondingLevel => (1 + (_bondingXp / 50).floor()).clamp(1, 10);

  String get bondingTitle {
    if (hasActiveStreakEffect) {
      return streakLevelTitle;
    }
    final lvl = bondingLevel;
    if (lvl <= 2) return 'Walking Sprout';
    if (lvl <= 4) return 'Focus Guardian';
    if (lvl <= 7) return 'Streak Champion';
    return 'Legendary Companion';
  }

  bool get isPledgeSealedToday {
    try {
      final box = Hive.box(_boxName);
      final lastDate = box.get(_pledgeSealedDateKey) as String?;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      return lastDate == today;
    } catch (_) {
      return false;
    }
  }

  /// Initialize state from Hive and listen for Premium status changes to auto-revert.
  Future<void> init() async {
    try {
      final box = Hive.box(_boxName);
      _name = (box.get(_nameKey) as String?) ?? 'Pippy';
      _userName = (box.get(_userNameKey) as String?) ?? 'Friend';

      final auraStr = box.get(_auraKey) as String?;
      if (auraStr != null) {
        _aura = CompanionAura.values.firstWhere(
          (e) => e.name == auraStr,
          orElse: () => CompanionAura.mint,
        );
      }

      final accStr = box.get(_accessoryKey) as String?;
      if (accStr != null) {
        _accessory = CompanionAccessory.values.firstWhere(
          (e) => e.name == accStr,
          orElse: () => CompanionAccessory.sprout,
        );
      }

      final persStr = box.get(_personalityKey) as String?;
      if (persStr != null) {
        _personality = CompanionPersonality.values.firstWhere(
          (e) => e.name == persStr,
          orElse: () => CompanionPersonality.zen,
        );
      }

      final questStr = box.get(_questKey) as String?;
      if (questStr != null) {
        _activeQuest = LifeQuest.values.firstWhere(
          (e) => e.name == questStr,
          orElse: () => LifeQuest.dopamine,
        );
      }

      _bondingXp = (box.get(_bondingXpKey) as int?) ?? 45;

      // Listen to Premium changes: as soon as Pro expires, auto-revert mascot to normal
      RevenueCatService.instance.isPremiumNotifier.addListener(() {
        notifyListeners();
      });

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('[CompanionService] Init error: $e');
    }
  }

  /// Set the user's personal name/nickname and sync to OneSignal for personalized push notifications.
  Future<void> setUserName(String newUserName) async {
    final clean = newUserName.trim();
    if (clean.isEmpty) return;
    _userName = clean;
    final box = Hive.box(_boxName);
    await box.put(_userNameKey, _userName);
    await OneSignalService.instance.setUserTag('first_name', _userName);
    notifyListeners();
  }

  /// Check whether an accessory is unlocked (strictly by viral referral count).
  bool isAccessoryUnlocked(CompanionAccessory item) {
    if (item.requiredReferrals == 0) return true;
    final referrals = GrowthService.instance.referralCount;
    return referrals >= item.requiredReferrals;
  }

  /// Rename companion.
  Future<void> setName(String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) return;
    _name = clean;
    final box = Hive.box(_boxName);
    await box.put(_nameKey, _name);
    await OneSignalService.instance.setUserTag('companion_name', _name);
    notifyListeners();
  }

  /// Change Aura color.
  Future<void> setAura(CompanionAura newAura) async {
    _aura = newAura;
    final box = Hive.box(_boxName);
    await box.put(_auraKey, _aura.name);
    await OneSignalService.instance.setUserTag('companion_aura', _aura.name);
    notifyListeners();
  }

  /// Equip Accessory.
  Future<bool> setAccessory(CompanionAccessory newAccessory) async {
    if (!isAccessoryUnlocked(newAccessory)) return false;
    _accessory = newAccessory;
    final box = Hive.box(_boxName);
    await box.put(_accessoryKey, _accessory.name);
    await OneSignalService.instance.setUserTag('companion_accessory', _accessory.name);
    notifyListeners();
    return true;
  }

  /// Change Personality.
  Future<void> setPersonality(CompanionPersonality newPers) async {
    _personality = newPers;
    final box = Hive.box(_boxName);
    await box.put(_personalityKey, _personality.name);
    await OneSignalService.instance.setUserTag('companion_personality', _personality.name);
    notifyListeners();
  }

  /// Select Active Life Quest.
  Future<void> setQuest(LifeQuest newQuest) async {
    _activeQuest = newQuest;
    final box = Hive.box(_boxName);
    await box.put(_questKey, _activeQuest.name);
    await OneSignalService.instance.setUserTag('active_quest', _activeQuest.name);
    notifyListeners();
  }

  /// Seal today's sacred habit pact.
  Future<void> sealTodayPledge() async {
    final box = Hive.box(_boxName);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await box.put(_pledgeSealedDateKey, today);
    addBondingXp(15);
    await OneSignalService.instance.setUserTag('pledge_sealed_today', 'true');
    notifyListeners();
  }

  /// Add Bonding XP on pet or walks.
  Future<void> addBondingXp(int xp) async {
    _bondingXp += xp;
    final box = Hive.box(_boxName);
    await box.put(_bondingXpKey, _bondingXp);
    notifyListeners();
  }

  /// Pet the mascot or feed to increase bonding.
  Future<void> feedOrPet() async {
    await addBondingXp(5);
  }

  /// Get dynamic contextual dialogue based on live steps, balance, and permission status.
  String getContextualDialogue({
    required int stepsToday,
    required int remainingSeconds,
    required bool permissionsHealthy,
  }) {
    if (!permissionsHealthy) {
      return '⚠️ "$name needs your help! A required permission is turned off."';
    }

    if (remainingSeconds <= 0 && stepsToday == 0) {
      switch (_personality) {
        case CompanionPersonality.zen:
          return '🧘 "Inhale calm. A gentle 2-minute stroll will awaken your screen time."';
        case CompanionPersonality.hype:
          return '⚡ "YOOO! Bank is empty! Let\'s knock out 100 steps for quick TikTok time!"';
        case CompanionPersonality.coach:
          return '🎯 "Screen locked. Action item: Take a brief 3-minute walking lap."';
        case CompanionPersonality.cozy:
          return '🧸 "I\'m taking a cozy nap wrapped in my blanket until we walk a bit..."';
      }
    }

    if (remainingSeconds <= 120 && remainingSeconds > 0) {
      return '⏳ "Only 2 minutes left in your focus bank! Ready for a quick walking recharge?"';
    }

    if (stepsToday >= 5000) {
      switch (_personality) {
        case CompanionPersonality.zen:
          return '🌸 "Peace and power, $_userName. You are moving with wonderful harmony today."';
        case CompanionPersonality.hype:
          return '🔥 "LOOK AT YOU GO $_userName! Over 5,000 steps! You are crushing it today!"';
        case CompanionPersonality.coach:
          return '🏆 "$_userName, target efficiency maintained. Great streak protection."';
        case CompanionPersonality.cozy:
          return '💖 "Hooray! Big warm hugs for $_userName for doing so many steps!"';
      }
    }

    // Default friendly idle
    switch (_personality) {
      case CompanionPersonality.zen:
        return '🌿 "Every step brings mental clarity, $_userName, and recharges your focus."';
      case CompanionPersonality.hype:
        return '👟 "$_userName, 100 steps = +1 minute of fun! Let\'s get moving today!"';
      case CompanionPersonality.coach:
        return '🎯 "Discipline equals freedom, $_userName. Keep stacking your banked minutes."';
      case CompanionPersonality.cozy:
        return '🧸 "Hi $_userName! Want to take a cozy little stretch together with $name?"';
    }
  }
}
