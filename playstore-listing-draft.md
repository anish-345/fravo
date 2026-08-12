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

<!-- LONGDESC-START -->
Walk to earn screen time. Fravo turns your daily steps into minutes on the apps you love — no willpower required. Move more, unlock your apps, and scroll with intention instead of guilt.

**How it works**
1. Pick your apps — Instagram, TikTok, YouTube, games, anything that steals your time.
2. Walk to earn screen time — 1,000 steps earns you minutes, from a gentle 5 to a solid 60 per 1,000 steps.
3. When your balance runs out, Fravo blocks those apps until you move again. Simple deal: your body is the password.

**Not another screen time limiter**
Most screen time limiters rely on willpower and timers you can dismiss. Fravo flips the script — instead of restriction, you get reward. Earned screen time feels like a treat, not a punishment, and it gets you walking every single day. It's a dopamine detox that builds focus and fitness at the same time.

**Block the apps that steal your day**
Use Fravo as an app blocker for social media and endless video: block Instagram, block TikTok, block YouTube, block games — or block any app by its package name. Custom app blocking means only the apps you choose are limited. Messaging and essential apps stay free, so you're never locked out of real life.

**Stop doomscrolling, start living**
- Break phone addiction with positive reinforcement, not shame.
- A digital detox that fits real life — walk to work, unlock your feed.
- Dual-mode step tracking: hardware pedometer for instant steps, Health Connect for accuracy.
- Real-time usage sync keeps your balance honest, every 30 seconds.
- Daily reset at midnight — steps and screen time start fresh each morning.

**Track your progress**
Fravo is a screen time tracker and walking rewards app in one. Watch your steps climb, your screen time drop, and your earned balance grow. Every day is a little win: less scrolling, more moving.

**Private by design**
Fravo runs entirely on your device. No account. No cloud. No camera. Your steps, your screen time, and your blocked apps never leave your phone. Walk to unlock apps without handing over your data.

Whether you want to limit screen time, stop doomscrolling, or simply walk more, Fravo turns your phone habit into a fitness habit. Take the first step — download Fravo and earn your screen time today.
<!-- LONGDESC-END -->

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