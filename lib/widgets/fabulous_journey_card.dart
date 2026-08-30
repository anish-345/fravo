import 'package:flutter/material.dart';
import '../services/companion_service.dart';
import 'premium_glass_system.dart';

/// Fabulous-inspired Daily Story Letter & Life Quest Ritual Card.
class FabulousJourneyCard extends StatelessWidget {
  const FabulousJourneyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final companion = CompanionService.instance;

    return AnimatedBuilder(
      animation: companion,
      builder: (context, _) {
        final quest = companion.activeQuest;
        final isSealed = companion.isPledgeSealedToday;

        return PuffyGlassContainer(
          tintColor: const Color(0xFFD9CFFF),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Tag & Quest Switcher
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Text('📜 ', style: TextStyle(fontSize: 12)),
                        Text(
                          quest.tag.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF7C3AED),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<LifeQuest>(
                    initialValue: quest,
                    tooltip: 'Change Life Quest',
                    onSelected: (q) => companion.setQuest(q),
                    itemBuilder: (ctx) => LifeQuest.values.map((q) {
                      return PopupMenuItem(
                        value: q,
                        child: Row(
                          children: [
                            Text(q == LifeQuest.dopamine
                                ? '🛡️'
                                : q == LifeQuest.morning
                                    ? '☀️'
                                    : '🌙'),
                            const SizedBox(width: 8),
                            Text(q.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Text('Switch Quest', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4A5568))),
                          Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF4A5568)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Quest Title
              Text(
                quest.label,
                style: const TextStyle(
                  color: Color(0xFF1A202C),
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 3),
              Text(
                quest.narrative,
                style: const TextStyle(color: Color(0xFF718096), fontSize: 12, height: 1.35),
              ),

              const SizedBox(height: 14),

              // The Morning Letter Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFCD34D).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('✨ ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            quest.letterTitle,
                            style: const TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '"Dear ${companion.userName},\n\n${quest.letterBody}"',
                      style: const TextStyle(
                        color: Color(0xFF451A03),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '— ${companion.name} 🌿',
                        style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Sacred Habit Pact / Golden Seal
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSealed ? const Color(0xFF10B981) : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSealed ? 'PACT SEALED TODAY ✓' : 'DAILY FOCUS CONTRACT',
                            style: TextStyle(
                              color: isSealed ? const Color(0xFF10B981) : const Color(0xFFD97706),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                          Text(
                            quest.pledge,
                            style: const TextStyle(
                              color: Color(0xFF1A202C),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSealed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: isSealed
                          ? null
                          : () {
                              companion.sealTodayPledge();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🕯️ Sacred Habit Pact Sealed! +15 Bonding XP'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            },
                      child: Text(
                        isSealed ? 'Sealed ✨' : '🕯️ Seal Pact',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
