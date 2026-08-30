import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/growth_service.dart';
import 'premium_glass_system.dart';

/// Single Unified Puffy Glass Referral Card combining:
/// 1. Top Milestone Tracker (1, 5, 10 friends for Pippy Hats & Pro)
/// 2. Invite Code & 1-Tap Share Button
/// 3. Friend's Code Redemption Box (Directly inside the card)
class ReferralRewardCard extends StatefulWidget {
  final Color tintColor;

  const ReferralRewardCard({
    super.key,
    this.tintColor = const Color(0xFFE8FDF3),
  });

  @override
  State<ReferralRewardCard> createState() => _ReferralRewardCardState();
}

class _ReferralRewardCardState extends State<ReferralRewardCard> {
  final _growth = GrowthService.instance;
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
    if (code.isEmpty) {
      setState(() {
        _statusMessage = '⚠️ Please enter a referral code.';
        _isSuccess = false;
      });
      return;
    }

    if (code.toUpperCase() == _growth.referralCode) {
      setState(() {
        _statusMessage = '⚠️ You cannot redeem your own referral code.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isRedeeming = true;
      _statusMessage = null;
    });

    final success = await _growth.redeemReferralCode(code);

    if (!mounted) return;
    setState(() {
      _isRedeeming = false;
      _isSuccess = success;
      _statusMessage = success
          ? '🎉 7 Days Free Pro Activated! All premium features unlocked.'
          : '⚠️ Already claimed on this device or invalid code.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _growth,
      builder: (context, _) {
        final referralCode = _growth.referralCode;
        final referrals = _growth.referralCount;
        final hasRedeemed = _growth.hasRedeemedReferral;

        return PuffyGlassContainer(
          tintColor: widget.tintColor,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Tag & Count Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Text('🎁 ', style: TextStyle(fontSize: 12)),
                        Text(
                          'GIVE 7 DAYS • GET 7 DAYS PRO',
                          style: TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$referrals Invited',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              const Text(
                'Invite Friends — Win Together 🎉',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Your friend defeats doomscrolling. You unlock 7 Days Pro + Pippy\'s wardrobe. Win-win! 🎉',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5, height: 1.4),
              ),

              const SizedBox(height: 12),

              // Milestone Badges (1, 5, 10 Friends)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMilestoneItem('👑 Crown', 1, referrals >= 1),
                  _buildMilestoneItem('🌸 Sakura', 5, referrals >= 5),
                  _buildMilestoneItem('🎧 Beats', 10, referrals >= 10),
                ],
              ),

              const SizedBox(height: 16),

              // ── YOUR INVITE CODE BOX ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF6FF), Color(0xFFF0FDF4)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YOUR INVITE CODE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              referralCode,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          tooltip: 'Copy Code',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: referralCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('📋 Referral code copied to clipboard!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                        onPressed: () => _growth.shareReferralInvite(),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text(
                          'Share Invite & Play Store Link 🚀',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── REDEEM FRIEND'S CODE SECTION ─────────────────────────────────
              if (!hasRedeemed) ...[
                const Text(
                  'Have a friend\'s code?',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                        ),
                        child: TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A202C),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'e.g. FRAVO-4K89',
                            hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _isRedeeming ? null : _handleRedeem,
                      child: _isRedeeming
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Claim 7 Days Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Referral bonus redeemed! 7 Days Pro active.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_statusMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _statusMessage!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: _isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMilestoneItem(String label, int required, bool isUnlocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isUnlocked
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked ? const Color(0xFF10B981) : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          if (isUnlocked)
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 13)
          else
            Text(
              '($required)',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}
