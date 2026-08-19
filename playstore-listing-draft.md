# Fravo — Play Store Listing Draft

**Built from:** `playstore-keyword-research.md` (Aug 2026) + in-app language (onboarding goals: Beat Doomscrolling / Focus / Fitness)
**Voice:** reward over restriction, consistent with the app's own tone.

---

## 1. App title (30 chars max)

| Option | Chars | Vote |
|---|---|---|
| **`Fravo–Walk to Earn Screen Time`** | 30 | ⭐ Recommended |
| `Fravo Walk to Earn Screen Time` | 30 | Safe fallback if en-dash renders oddly |
| `Fravo: Walk to Unlock Apps` | 26 | Second option (app-first phrasing) |
| `Fravo Walk to Unlock Apps` | 24 | Shortest viable option |

Leads with the winnable, niche-proven phrase ("walk to earn screen time") and keeps brand first. Do NOT use "app blocker" here — that fight is for later.

## 2. Short description (80 chars max)

| Option | Chars | Vote |
|---|---|---|
| **`Walk 1,000 steps = 30 min screen time. Stop doomscrolling, move more.`** | 69 | ⭐ Recommended |
| `Walk to earn screen time. 1,000 steps = 30 min on your apps.` | 60 | Minimal, mechanic-first |
| `Earn screen time by walking. Block apps, stop doomscrolling, move more.` | 71 | Keyword-heavier variant |

Recommended option covers: walk, screen time, stop doomscrolling. Keep the "=" so the reward ratio is instantly legible in search results.

## 3. Long description (≤ 4,000 chars)

Use the box below to quickly copy-paste the long description directly into the Google Play Console:

```text
Walk to earn screen time! Fravo is the ultimate app blocker and screen time tracker that turns your daily steps into minutes on the apps you love. No willpower required. Move more, walk to unlock apps, and stop doomscrolling with the power of positive reinforcement.

HOW IT WORKS:
1. Choose the apps you want to limit (block Instagram, block TikTok, block YouTube, games, or any social media app).
2. Walk to earn screen time. You set the rate—like 1,000 steps for 30 minutes of app use.
3. Once your earned balance runs out, Fravo blocks those apps until you move again. Your body is the password!

REWARD, NOT RESTRICTION
Most screen time limiters rely on willpower and timers that you can easily dismiss. Fravo flips the script. Instead of boring restriction, you get a rewarding digital detox. Earned screen time feels like a treat, not a punishment. It builds healthy focus, fitness, and screen habits that last.

FEATURES THAT HELP YOU QUIT PHONE ADDICTION:
• Custom App Blocker: Block social media, games, and streaming apps by choice. Messaging and essential tools stay unlocked.
• Walk to Unlock Apps: Step counter syncs in real-time. Walk to earn screen time and build a healthy walking habit.
• Dual-Mode Step Tracker: Uses your device's hardware pedometer for instant step counts or connects to Health Connect for absolute accuracy.
• Hard Blocking: Actually blocks apps with a native overlay screen that only disappears when you walk. No cheat codes.
• Live Screen Time Tracker: Updates your balance and app usage every 30 seconds to keep your habits honest.
• Midnight Reset: A fresh start every day. Your steps and screen time balance reset at midnight to motivate you daily.

100% PRIVATE & SECURE:
Your digital wellbeing is personal. Fravo runs entirely on-device:
• No account setup required
• No cloud tracking or camera usage
• Your steps, screen time data, and blocked apps never leave your phone

Whether you want to limit screen time, stop doomscrolling, or simply walk more, Fravo turns your phone habit into a fitness habit. 

Take the first step—download Fravo, walk to unlock apps, and earn your screen time today!
```

---

**Keyword coverage map** (intent-verified from research):
- Tier 1 (title terms reinforced): walk to earn screen time, earn screen time, walk to unlock apps
- Tier 2: screen time limiter, limit screen time, app blocker, block apps / app blocking, block Instagram / TikTok / YouTube, screen time tracker, walking rewards, dopamine detox, digital detox, phone addiction, stop doomscrolling, dooms
crolling, steps→screen time mechanic, focus, fitness
- Intent hooks: "your body is the password", "reward not restriction" (pitch angle), privacy (kills the AI-camera competitors' advantage)

**Density:** "screen time" ≈ 1.5–2% of long description — within the recommended 2–3% range for top terms without stuffing.

## 4. Screenshot copy (6 frames)

1. **Hero:** "Stop the 11 p.m. scroll — walk to earn your screen time."
2. **Mechanic:** "1,000 steps = 30 minutes. Your body is the password."
3. **Blocking:** "Block TikTok, Instagram & YouTube — earn them back by walking."
4. **Balance:** "Spend what you earned, guilt-free. Real-time balance, live."
5. **Stats:** "Screen time down. Steps up. Win every day."
6. **Privacy:** "No account. No camera. 100% on-device."

## 5. Play Console settings

| Field | Value |
|---|---|
| Category | **Productivity** (screen-time/blocking apps live here; Health & Fitness is step-app saturation) |
| Content rating | Complete honestly; expect "Everyone / low maturity" IF no medical claims |
| Target audience | 18+ adults (self-control / digital wellbeing), not children |
| Data safety | No data collected/shared — all on-device. Declare permissions: Activity Recognition (steps), Health Connect read (steps), Usage Access (screen time), Accessibility (blocking), Overlay (block screen), Notifications (status) |
| App access (restricted) | Declare `PACKAGE_USAGE_STATS` + Accessibility use upfront — this is the #1 rejection/restriction risk for this category. Keep the in-app disclosure wording aligned with this listing. |
| Contact | Email + privacy policy URL (`PRIVACY_POLICY.md` is already hosted-ready with the on-device story) |

## 6. Launch checklist (from research §7)

- [ ] Ship listing with title/short desc above
- [ ] Applyra free + AppFollow: track earn screen time, walk to earn screen time, walk to unlock apps, steps to screen time, stop doomscrolling, block social media, screen time app
- [ ] Play Console A/B: title "Fravo–Walk..." vs "Fravo: Walk to Unlock Apps"; short desc variants
- [ ] In-app review prompt (non-blocking) — ratings feed ranking
- [ ] 4–6 week refresh cadence (update recency is a Play signal)
- [ ] Never add: competitor names, "Digital Wellbeing", medical/cure claims